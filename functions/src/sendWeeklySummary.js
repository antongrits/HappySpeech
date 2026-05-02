'use strict';

/**
 * sendWeeklySummary — scheduled weekly push notification.
 *
 * Runs every Sunday at 19:00 UTC (= 22:00 MSK).
 * For each parent user with weeklyParentSummaryEnabled == true and a valid fcmToken:
 *   - Compute stats for the past 7 days (sessions count, total minutes).
 *   - Send FCM push with a summary and deep link to ParentHome.
 *
 * COPPA: only parents receive FCM. Kid profiles are never targeted.
 */

const logger = require('firebase-functions/logger');

/**
 * Returns ISO date strings for the 7-day window ending today.
 * @returns {{ weekStart: Date, weekEnd: Date }}
 */
function weekWindow() {
  const now = new Date();
  const weekEnd = new Date(now);
  weekEnd.setUTCHours(23, 59, 59, 999);

  const weekStart = new Date(now);
  weekStart.setUTCDate(weekStart.getUTCDate() - 6);
  weekStart.setUTCHours(0, 0, 0, 0);

  return { weekStart, weekEnd };
}

/**
 * Aggregates session stats for a single child over the given week window.
 * @param {FirebaseFirestore.Firestore} db
 * @param {string} userId
 * @param {string} childId
 * @param {Date} weekStart
 * @param {Date} weekEnd
 * @returns {Promise<{ sessionCount: number, totalMinutes: number }>}
 */
async function getWeekStats(db, userId, childId, weekStart, weekEnd) {
  const snap = await db
    .collection('users')
    .doc(userId)
    .collection('children')
    .doc(childId)
    .collection('sessions')
    .where('date', '>=', weekStart)
    .where('date', '<=', weekEnd)
    .get();

  if (snap.empty) return { sessionCount: 0, totalMinutes: 0 };

  let totalSeconds = 0;
  snap.docs.forEach((doc) => {
    const data = doc.data() || {};
    totalSeconds += typeof data.durationSeconds === 'number' ? data.durationSeconds : 0;
  });

  return {
    sessionCount: snap.size,
    totalMinutes: Math.round(totalSeconds / 60),
  };
}

/**
 * Formats a human-readable summary string in Russian.
 * @param {string} childName
 * @param {number} sessionCount
 * @param {number} totalMinutes
 * @returns {string}
 */
function formatSummaryBody(childName, sessionCount, totalMinutes) {
  const safeName = typeof childName === 'string' && childName.trim().length > 0 ?
    childName.trim() :
    'ребёнок';

  if (sessionCount === 0) {
    return `${safeName} на этой неделе ещё не занимался. Самое время начать!`;
  }

  const sessionsText = sessionCount === 1 ?
    '1 занятие' :
    sessionCount < 5 ?
      `${sessionCount} занятия` :
      `${sessionCount} занятий`;

  const minutesText = totalMinutes < 1 ?
    'меньше минуты' :
    totalMinutes === 1 ?
      '1 минуту' :
      `${totalMinutes} минут`;

  return `${safeName} занимался ${sessionsText} (${minutesText}) за эту неделю. Отличный результат!`;
}

/**
 * Sends a weekly summary FCM push notification.
 * Fails silently — one bad token does not abort the batch.
 *
 * @param {admin.messaging.Messaging} messaging
 * @param {string} fcmToken
 * @param {string} childName
 * @param {number} sessionCount
 * @param {number} totalMinutes
 * @returns {Promise<boolean>}
 */
async function sendSummaryPush(messaging, fcmToken, childName, sessionCount, totalMinutes) {
  const body = formatSummaryBody(childName, sessionCount, totalMinutes);

  const message = {
    token: fcmToken,
    notification: {
      title: 'Итоги недели',
      body,
    },
    apns: {
      payload: {
        aps: {
          sound: 'default',
          badge: 1,
        },
      },
      headers: {
        'apns-priority': '5',
      },
    },
    data: {
      type: 'weekly_summary',
      deepLink: 'happyspeech://parent/home',
      sessionCount: String(sessionCount),
      totalMinutes: String(totalMinutes),
      sentAt: new Date().toISOString(),
    },
  };

  try {
    await messaging.send(message);
    return true;
  } catch (error) {
    logger.warn('sendWeeklySummary: FCM send failed', {
      errorCode: error.code,
      errorMessage: String(error.message),
    });
    return false;
  }
}

/**
 * Main runner — called from index.js scheduled function.
 * @param {import('firebase-admin')} admin
 * @returns {Promise<void>}
 */
async function runWeeklySummary(admin) {
  const db = admin.firestore();
  const messaging = admin.messaging();
  const { weekStart, weekEnd } = weekWindow();

  let parentsScanned = 0;
  let summariesSent = 0;
  let noToken = 0;
  let disabled = 0;

  let lastDoc = null;
  const BATCH = 100;

  /* eslint-disable no-await-in-loop, no-constant-condition */
  while (true) {
    let query = db
      .collection('users')
      .where('role', '==', 'parent')
      .limit(BATCH);

    if (lastDoc) {
      query = query.startAfter(lastDoc);
    }

    const snap = await query.get();
    if (snap.empty) break;
    lastDoc = snap.docs[snap.docs.length - 1];

    for (const parentDoc of snap.docs) {
      parentsScanned += 1;
      const userId = parentDoc.id;
      const parentData = parentDoc.data() || {};

      // Respect per-user opt-out for weekly summary.
      if (parentData.weeklyParentSummaryEnabled === false) {
        disabled += 1;
        continue;
      }

      const fcmToken = parentData.fcmToken;
      if (!fcmToken || typeof fcmToken !== 'string') {
        noToken += 1;
        continue;
      }

      // Find active child.
      let childId = parentData.activeChildId || null;
      let childName = 'ребёнок';

      if (!childId) {
        const childrenSnap = await db
          .collection('users')
          .doc(userId)
          .collection('children')
          .limit(1)
          .get();

        if (childrenSnap.empty) continue;
        const firstChild = childrenSnap.docs[0];
        childId = firstChild.id;
        childName = firstChild.data().name || childName;
      } else {
        const childDoc = await db
          .collection('users')
          .doc(userId)
          .collection('children')
          .doc(childId)
          .get();
        if (childDoc.exists) {
          childName = childDoc.data().name || childName;
        }
      }

      const { sessionCount, totalMinutes } = await getWeekStats(
        db, userId, childId, weekStart, weekEnd,
      );

      const sent = await sendSummaryPush(
        messaging, fcmToken, childName, sessionCount, totalMinutes,
      );
      if (sent) summariesSent += 1;
    }
  }
  /* eslint-enable no-await-in-loop, no-constant-condition */

  logger.info('sendWeeklySummary complete', {
    parentsScanned,
    summariesSent,
    noToken,
    disabled,
    weekStart: weekStart.toISOString(),
    weekEnd: weekEnd.toISOString(),
  });
}

module.exports = { runWeeklySummary };
