'use strict';

// firebase-admin and firebase-functions are lazy-loaded inside
// calculateProgressForChild so that unit tests of pure aggregation
// helpers (groupSessionsBySound, emptyStageProgress) can run without
// installing the Firebase SDKs.

const {
  STAGES,
  STAGE_PASS_THRESHOLD,
  MIN_ATTEMPTS_FOR_STAGE,
} = require('./constants');

/**
 * Build an empty progress stage map.
 *
 * @return {Object<string, {done: boolean, rate: number, attempts: number}>}
 */
function emptyStageProgress() {
  const out = {};
  for (const stage of STAGES) {
    out[stage] = { done: false, rate: 0.0, attempts: 0 };
  }
  return out;
}

/**
 * Group sessions by targetSound and stage, then compute aggregate accuracy.
 *
 * @param {Array<FirebaseFirestore.QueryDocumentSnapshot>} sessionDocs
 * @return {Map<string, {stages: Object, totalSessions: number, totalMinutes: number}>}
 */
function groupSessionsBySound(sessionDocs) {
  const bySound = new Map();

  for (const doc of sessionDocs) {
    const data = doc.data();
    const sound = data.targetSound;
    if (!sound) continue;

    if (!bySound.has(sound)) {
      bySound.set(sound, {
        stages: emptyStageProgress(),
        totalSessions: 0,
        totalMinutes: 0,
        totalAttempts: 0,
        correctAttempts: 0,
      });
    }

    const bucket = bySound.get(sound);
    bucket.totalSessions += 1;
    bucket.totalMinutes += Math.round((data.durationSeconds || 0) / 60);
    bucket.totalAttempts += data.totalAttempts || 0;
    bucket.correctAttempts += data.correctAttempts || 0;

    const stageKey = STAGES.includes(data.stage) ? data.stage : null;
    if (stageKey) {
      const stageBucket = bucket.stages[stageKey];
      stageBucket.attempts += data.totalAttempts || 0;
      const prevCorrect = (stageBucket.rate * (stageBucket.attempts - (data.totalAttempts || 0))) || 0;
      const newCorrect = prevCorrect + (data.correctAttempts || 0);
      stageBucket.rate = stageBucket.attempts > 0 ? newCorrect / stageBucket.attempts : 0;
      stageBucket.done = stageBucket.attempts >= MIN_ATTEMPTS_FOR_STAGE
        && stageBucket.rate >= STAGE_PASS_THRESHOLD;
    }
  }

  return bySound;
}

/**
 * Compute per-phoneme progress for a child and upsert into /progress/{soundTarget}.
 *
 * @param {FirebaseFirestore.Firestore} db
 * @param {string} userId
 * @param {string} childId
 * @param {Object} [options]
 * @param {string} [options.onlySound] If provided, only update this sound's document.
 * @return {Promise<{soundTargets: Array, updatedAt: string}>}
 */
async function calculateProgressForChild(db, userId, childId, options = {}) {
  const admin = require('firebase-admin');
  const logger = require('firebase-functions/logger');

  const sessionsRef = db
    .collection('users').doc(userId)
    .collection('children').doc(childId)
    .collection('sessions');

  let query = sessionsRef;
  if (options.onlySound) {
    query = query.where('targetSound', '==', options.onlySound);
  }

  const sessionsSnap = await query.get();
  const grouped = groupSessionsBySound(sessionsSnap.docs);

  const progressRef = db
    .collection('users').doc(userId)
    .collection('children').doc(childId)
    .collection('progress');

  const batch = db.batch();
  const summaries = [];

  for (const [sound, bucket] of grouped.entries()) {
    const docRef = progressRef.doc(sound);
    const payload = {
      soundTarget: sound,
      stageProgress: bucket.stages,
      lastUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
      totalSessions: bucket.totalSessions,
      totalMinutes: bucket.totalMinutes,
      overallRate: bucket.totalAttempts > 0
        ? bucket.correctAttempts / bucket.totalAttempts
        : 0,
      childId,
    };
    batch.set(docRef, payload, { merge: true });
    summaries.push(payload);
  }

  if (summaries.length > 0) {
    await batch.commit();
  } else {
    logger.info('calculateProgressForChild: no sessions yet', { userId, childId });
  }

  // Update child.progressSummary for quick read
  if (summaries.length > 0) {
    const progressSummary = {};
    for (const s of summaries) {
      progressSummary[s.soundTarget] = Number((s.overallRate || 0).toFixed(3));
    }
    await db
      .collection('users').doc(userId)
      .collection('children').doc(childId)
      .set({ progressSummary, lastProgressAt: admin.firestore.FieldValue.serverTimestamp() },
        { merge: true });
  }

  return {
    soundTargets: summaries,
    updatedAt: new Date().toISOString(),
  };
}

module.exports = {
  calculateProgressForChild,
  groupSessionsBySound,
  emptyStageProgress,
};
