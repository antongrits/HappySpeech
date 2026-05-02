'use strict';

/**
 * sendDailyReminder — scheduled daily push notification.
 *
 * Runs every day at 17:00 UTC (= 20:00 MSK).
 * For each parent user with notificationsEnabled == true and a valid fcmToken:
 *   - Check if the parent's active child had any sessions today (UTC date).
 *   - If no session today → send FCM push "Ещё не играли сегодня".
 *   - If session exists → skip (positive reinforcement, no nagging).
 *
 * COPPA: only parents receive FCM. Kid profiles are never targeted.
 * Privacy: FCM messages contain no PII beyond the child's first name (stored
 * locally on device); server only uses childId for the session lookup.
 */

const logger = require('firebase-functions/logger');

/**
 * Returns today's date as an ISO string "YYYY-MM-DD" in UTC.
 * @returns {string}
 */
function todayUTC() {
  return new Date().toISOString().slice(0, 10);
}

/**
 * Checks whether the given child had at least one session today (UTC).
 * @param {FirebaseFirestore.Firestore} db
 * @param {string} userId
 * @param {string} childId
 * @returns {Promise<boolean>}
 */
async function hadSessionToday(db, userId, childId) {
  const today = todayUTC();
  const startOfDay = new Date(today + 'T00:00:00.000Z');
  const endOfDay = new Date(today + 'T23:59:59.999Z');

  const snap = await db
    .collection('users')
    .doc(userId)
    .collection('children')
    .doc(childId)
    .collection('sessions')
    .where('date', '>=', startOfDay)
    .where('date', '<=', endOfDay)
    .limit(1)
    .get();

  return !snap.empty;
}

/**
 * Sends a single FCM push notification to the parent's device.
 * Fails silently (logs error, does not throw) so one bad token
 * does not abort the entire batch.
 *
 * @param {admin.messaging.Messaging} messaging
 * @param {string} fcmToken
 * @param {string} childName  — display name from child profile doc
 * @returns {Promise<boolean>} true if message was accepted by FCM
 */
async function sendReminderPush(messaging, fcmToken, childName) {
  const safeName = typeof childName === 'string' && childName.trim().length > 0 ?
    childName.trim() :
    'ребёнок';

  const message = {
    token: fcmToken,
    notification: {
      title: 'Время для занятия!',
      body: `${safeName} ещё не занимался сегодня. Давайте сделаем урок вместе?`,
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
      type: 'daily_reminder',
      deepLink: 'happyspeech://parent/home',
      sentAt: new Date().toISOString(),
    },
  };

  try {
    await messaging.send(message);
    return true;
  } catch (error) {
    // Token may be stale — log but don't propagate.
    logger.warn('sendDailyReminder: FCM send failed', {
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
async function runDailyReminder(admin) {
  const db = admin.firestore();
  const messaging = admin.messaging();

  let parentsScanned = 0;
  let remindersSent = 0;
  let sessionFound = 0;
  let noToken = 0;

  let lastDoc = null;
  const BATCH = 100;

  /* eslint-disable no-await-in-loop, no-constant-condition */
  while (true) {
    let query = db
      .collection('users')
      .where('role', '==', 'parent')
      .where('notificationsEnabled', '==', true)
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
      const fcmToken = parentData.fcmToken;

      if (!fcmToken || typeof fcmToken !== 'string') {
        noToken += 1;
        continue;
      }

      // Determine the active child — use activeChildId if set, else first child.
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

      const alreadyPlayed = await hadSessionToday(db, userId, childId);
      if (alreadyPlayed) {
        sessionFound += 1;
        continue;
      }

      const sent = await sendReminderPush(messaging, fcmToken, childName);
      if (sent) remindersSent += 1;
    }
  }
  /* eslint-enable no-await-in-loop, no-constant-condition */

  logger.info('sendDailyReminder complete', {
    parentsScanned,
    remindersSent,
    sessionFound,
    noToken,
  });
}

module.exports = { runDailyReminder };
