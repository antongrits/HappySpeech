'use strict';

/**
 * Aggregate statistics across all children of a parent user.
 *
 * @param {FirebaseFirestore.Firestore} db
 * @param {string} userId
 * @return {Promise<{childrenCount: number, totalSessions: number, totalMinutes: number, perChild: Array}>}
 */
async function aggregateUserStats(db, userId) {
  const childrenRef = db.collection('users').doc(userId).collection('children');
  const childrenSnap = await childrenRef.get();

  const perChild = [];
  let totalSessions = 0;
  let totalMinutes = 0;
  let lastActiveAt = null;

  for (const childDoc of childrenSnap.docs) {
    const childId = childDoc.id;
    const childData = childDoc.data() || {};

    const sessionsSnap = await childrenRef.doc(childId).collection('sessions').get();
    const sessions = sessionsSnap.size;
    const minutes = sessionsSnap.docs.reduce(
      (acc, d) => acc + Math.round((d.data().durationSeconds || 0) / 60), 0,
    );

    const latest = sessionsSnap.docs
      .map((d) => d.data().date)
      .filter(Boolean)
      .map((ts) => (ts.toDate ? ts.toDate() : new Date(ts)))
      .sort((a, b) => b - a)[0] || null;

    if (latest && (!lastActiveAt || latest > lastActiveAt)) {
      lastActiveAt = latest;
    }

    totalSessions += sessions;
    totalMinutes += minutes;

    perChild.push({
      childId,
      name: childData.name || '',
      age: childData.age || null,
      totalSessions: sessions,
      totalMinutes: minutes,
      lastActiveAt: latest ? latest.toISOString() : null,
      progressSummary: childData.progressSummary || {},
    });
  }

  return {
    userId,
    childrenCount: childrenSnap.size,
    totalSessions,
    totalMinutes,
    lastActiveAt: lastActiveAt ? lastActiveAt.toISOString() : null,
    perChild,
  };
}

module.exports = { aggregateUserStats };
