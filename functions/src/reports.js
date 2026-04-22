'use strict';

// firebase-admin is lazy-loaded inside periodToCutoff/buildReport so
// that pure helper functions can be unit-tested without the SDK.

const { STAGE_PASS_THRESHOLD } = require('./constants');

/**
 * Compute ISO date N days ago.
 * @param {number} days
 * @return {Date}
 */
function daysAgo(days) {
  const d = new Date();
  d.setDate(d.getDate() - days);
  d.setHours(0, 0, 0, 0);
  return d;
}

/**
 * Map period string to a Firestore Timestamp cutoff.
 *
 * @param {"week"|"month"|"all"} period
 * @return {FirebaseFirestore.Timestamp|null}
 */
function periodToCutoff(period) {
  const admin = require('firebase-admin');
  if (period === 'week') {
    return admin.firestore.Timestamp.fromDate(daysAgo(7));
  }
  if (period === 'month') {
    return admin.firestore.Timestamp.fromDate(daysAgo(30));
  }
  return null;
}

/**
 * Bucket sessions by day for charts.
 *
 * @param {Array<FirebaseFirestore.QueryDocumentSnapshot>} sessions
 * @return {Array<{date: string, sessions: number, minutes: number, accuracy: number}>}
 */
function buildDailySeries(sessions) {
  const byDay = new Map();

  for (const doc of sessions) {
    const data = doc.data();
    const ts = data.date && data.date.toDate ? data.date.toDate() : null;
    if (!ts) continue;

    const dayKey = ts.toISOString().slice(0, 10);
    if (!byDay.has(dayKey)) {
      byDay.set(dayKey, { date: dayKey, sessions: 0, minutes: 0, total: 0, correct: 0 });
    }
    const row = byDay.get(dayKey);
    row.sessions += 1;
    row.minutes += Math.round((data.durationSeconds || 0) / 60);
    row.total += data.totalAttempts || 0;
    row.correct += data.correctAttempts || 0;
  }

  return Array.from(byDay.values())
    .sort((a, b) => (a.date < b.date ? -1 : 1))
    .map((r) => ({
      date: r.date,
      sessions: r.sessions,
      minutes: r.minutes,
      accuracy: r.total > 0 ? Number((r.correct / r.total).toFixed(3)) : 0,
    }));
}

/**
 * Per-sound summary for charts.
 *
 * @param {Array<FirebaseFirestore.QueryDocumentSnapshot>} sessions
 * @return {Array<{soundTarget: string, sessions: number, accuracy: number, minutes: number}>}
 */
function buildSoundBreakdown(sessions) {
  const bySound = new Map();

  for (const doc of sessions) {
    const data = doc.data();
    const sound = data.targetSound;
    if (!sound) continue;

    if (!bySound.has(sound)) {
      bySound.set(sound, { soundTarget: sound, sessions: 0, total: 0, correct: 0, minutes: 0 });
    }
    const row = bySound.get(sound);
    row.sessions += 1;
    row.total += data.totalAttempts || 0;
    row.correct += data.correctAttempts || 0;
    row.minutes += Math.round((data.durationSeconds || 0) / 60);
  }

  return Array.from(bySound.values()).map((r) => ({
    soundTarget: r.soundTarget,
    sessions: r.sessions,
    minutes: r.minutes,
    accuracy: r.total > 0 ? Number((r.correct / r.total).toFixed(3)) : 0,
  }));
}

/**
 * Produce rule-based recommendations (no external LLM).
 *
 * @param {Array} soundBreakdown
 * @return {Array<string>}
 */
function buildRecommendations(soundBreakdown) {
  const recs = [];
  if (soundBreakdown.length === 0) {
    recs.push('Начните с короткой игровой сессии 10 минут, чтобы определить опорный звук.');
    return recs;
  }

  const weakest = [...soundBreakdown].sort((a, b) => a.accuracy - b.accuracy)[0];
  const strongest = [...soundBreakdown].sort((a, b) => b.accuracy - a.accuracy)[0];

  if (weakest.accuracy < STAGE_PASS_THRESHOLD) {
    recs.push(
      `Звук "${weakest.soundTarget}" пока сложен (точность ${(weakest.accuracy * 100).toFixed(0)}%). ` +
      'Сделайте короткую артикуляционную разминку и повторите слоги перед играми.',
    );
  }

  if (strongest.accuracy >= STAGE_PASS_THRESHOLD) {
    recs.push(
      `Звук "${strongest.soundTarget}" звучит уверенно — переходите к следующему этапу ` +
      '(слова → фразы → рассказы).',
    );
  }

  const totalMinutes = soundBreakdown.reduce((a, b) => a + b.minutes, 0);
  if (totalMinutes < 20) {
    recs.push('Советуем 10–15 минут практики в день, желательно в одно и то же время.');
  }

  return recs;
}

/**
 * Build a structured parent/specialist report.
 *
 * @param {FirebaseFirestore.Firestore} db
 * @param {string} userId
 * @param {string} childId
 * @param {"week"|"month"|"all"} period
 * @return {Promise<{summary: Object, chartsData: Object, recommendations: Array<string>}>}
 */
async function buildReport(db, userId, childId, period) {
  const sessionsRef = db
    .collection('users').doc(userId)
    .collection('children').doc(childId)
    .collection('sessions');

  const cutoff = periodToCutoff(period);
  let query = sessionsRef;
  if (cutoff) {
    query = query.where('date', '>=', cutoff);
  }

  const snap = await query.get();
  const sessions = snap.docs;

  const totalSessions = sessions.length;
  const totalMinutes = sessions.reduce(
    (acc, d) => acc + Math.round((d.data().durationSeconds || 0) / 60), 0,
  );
  const totalAttempts = sessions.reduce((acc, d) => acc + (d.data().totalAttempts || 0), 0);
  const correctAttempts = sessions.reduce((acc, d) => acc + (d.data().correctAttempts || 0), 0);
  const overallAccuracy = totalAttempts > 0 ? correctAttempts / totalAttempts : 0;

  const dailySeries = buildDailySeries(sessions);
  const soundBreakdown = buildSoundBreakdown(sessions);

  return {
    summary: {
      period,
      totalSessions,
      totalMinutes,
      totalAttempts,
      correctAttempts,
      overallAccuracy: Number(overallAccuracy.toFixed(3)),
      generatedAt: new Date().toISOString(),
    },
    chartsData: {
      daily: dailySeries,
      perSound: soundBreakdown,
    },
    recommendations: buildRecommendations(soundBreakdown),
  };
}

module.exports = {
  buildReport,
  buildDailySeries,
  buildSoundBreakdown,
  buildRecommendations,
  periodToCutoff,
};
