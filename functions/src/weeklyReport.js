'use strict';

/**
 * Scheduled weekly report generator.
 *
 * For each parent user (users/{uid} where role == 'parent'), for each child:
 *   1) Build a "week" report via buildReport().
 *   2) Persist under /users/{uid}/children/{cid}/weekly_reports/{weekStartDate}.
 *   3) If parent has an FCM token on users/{uid}.fcmToken — attempt a push.
 *      (Expected to fail silently on iOS without APNs key. We still record
 *       the attempt in the report doc for telemetry.)
 *
 * Runs inside Cloud Function sendWeeklyReport (Sundays 10:00 MSK).
 */

const { buildReport } = require('./reports');

function mondayOfCurrentWeek(now = new Date()) {
  const d = new Date(now);
  d.setHours(0, 0, 0, 0);
  const day = d.getDay(); // 0 = Sun, 1 = Mon, ...
  const diff = (day === 0 ? -6 : 1 - day); // back to Monday
  d.setDate(d.getDate() + diff);
  return d;
}

function isoDate(date) {
  return date.toISOString().slice(0, 10);
}

async function runWeeklyReport(admin) {
  const db = admin.firestore();
  const messaging = admin.messaging();

  const weekStart = mondayOfCurrentWeek();
  const weekStartKey = isoDate(weekStart); // e.g. "2026-04-20"

  let parentsProcessed = 0;
  let childrenProcessed = 0;
  let pushAttempts = 0;
  let pushSuccess = 0;

  // Collect parents (users with role == 'parent') in batches of 100.
  let lastDoc = null;
  const BATCH = 100;

  /* eslint-disable no-await-in-loop */
  while (true) {
    let q = db.collection('users').where('role', '==', 'parent').limit(BATCH);
    if (lastDoc) q = q.startAfter(lastDoc);
    const snap = await q.get();
    if (snap.empty) break;
    lastDoc = snap.docs[snap.docs.length - 1];

    for (const parentDoc of snap.docs) {
      parentsProcessed += 1;
      const userId = parentDoc.id;
      const parent = parentDoc.data() || {};

      const childrenSnap = await db
        .collection('users').doc(userId)
        .collection('children').get();

      for (const childDoc of childrenSnap.docs) {
        const childId = childDoc.id;
        childrenProcessed += 1;

        let report;
        try {
          report = await buildReport(db, userId, childId, 'week');
        } catch (err) {
          // Log and continue — one bad child should not abort the batch.
          // eslint-disable-next-line no-console
          console.error('[weeklyReport] buildReport failed', userId, childId, err);
          continue;
        }

        const docRef = db
          .collection('users').doc(userId)
          .collection('children').doc(childId)
          .collection('weekly_reports').doc(weekStartKey);

        const payload = {
          weekStartDate: weekStartKey,
          childId,
          userId,
          generatedAt: admin.firestore.FieldValue.serverTimestamp(),
          ...report,
          pushAttempted: false,
          pushDelivered: false,
        };

        // Attempt FCM push if parent has a token.
        const fcmToken = typeof parent.fcmToken === 'string' && parent.fcmToken.length > 0
          ? parent.fcmToken
          : null;

        if (fcmToken) {
          pushAttempts += 1;
          payload.pushAttempted = true;
          try {
            await messaging.send({
              token: fcmToken,
              notification: {
                title: 'Недельный отчёт готов',
                body: `Отчёт за неделю для ${childDoc.data().name || 'ребёнка'} уже в приложении.`,
              },
              data: {
                type: 'weekly_report',
                childId,
                weekStartDate: weekStartKey,
              },
              apns: {
                payload: {
                  aps: { 'content-available': 1 },
                },
              },
            });
            pushSuccess += 1;
            payload.pushDelivered = true;
          } catch (err) {
            // Expected on iOS without APNs key — ignore.
            payload.pushError = String(err && err.code || err);
          }
        }

        await docRef.set(payload, { merge: true });
      }
    }

    if (snap.size < BATCH) break;
  }
  /* eslint-enable no-await-in-loop */

  return { parentsProcessed, childrenProcessed, pushAttempts, pushSuccess, weekStart: weekStartKey };
}

module.exports = {
  runWeeklyReport,
  mondayOfCurrentWeek,
  isoDate,
};
