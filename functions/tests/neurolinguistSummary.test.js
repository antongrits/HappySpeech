'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const {
  weekBoundaries,
  aggregateSessions,
  buildRecommendations,
  currentStageForSound,
} = require('../lib/neurolinguistSummary');

function fakeDoc(data) {
  return { data: () => data };
}

test('weekBoundaries: offset=0 returns 7-day window ending Monday', () => {
  const ref = new Date('2026-05-22T12:00:00Z'); // Friday
  const { start, end } = weekBoundaries(ref, 0);
  assert.equal(start.getUTCDay(), 1); // Monday
  assert.equal(end.getUTCDay(), 1);   // next Monday
  const deltaDays = (end.getTime() - start.getTime()) / (24 * 3600 * 1000);
  assert.equal(deltaDays, 7);
});

test('weekBoundaries: offset=1 shifts one week back', () => {
  const ref = new Date('2026-05-22T00:00:00Z');
  const { start: s0 } = weekBoundaries(ref, 0);
  const { start: s1 } = weekBoundaries(ref, 1);
  const diff = (s0.getTime() - s1.getTime()) / (24 * 3600 * 1000);
  assert.equal(diff, 7);
});

test('aggregateSessions: empty docs → zeros', () => {
  const agg = aggregateSessions([]);
  assert.equal(agg.totalSessions, 0);
  assert.equal(agg.totalMinutes, 0);
  assert.equal(agg.totalAttempts, 0);
  assert.equal(Object.keys(agg.soundProgress).length, 0);
});

test('aggregateSessions: groups by targetSound + computes success rates', () => {
  const docs = [
    fakeDoc({
      targetSound: 'Р', durationSeconds: 300,
      totalAttempts: 10, correctAttempts: 8,
    }),
    fakeDoc({
      targetSound: 'Р', durationSeconds: 600,
      totalAttempts: 20, correctAttempts: 15,
    }),
    fakeDoc({
      targetSound: 'С', durationSeconds: 120,
      totalAttempts: 5, correctAttempts: 4, fatigueDetected: true,
    }),
  ];
  const agg = aggregateSessions(docs);
  assert.equal(agg.totalSessions, 3);
  assert.equal(agg.totalMinutes, 17); // (300+600+120)/60 = 17
  assert.equal(agg.totalAttempts, 35);
  assert.equal(agg.correctAttempts, 27);
  assert.equal(agg.fatigueCount, 1);
  assert.equal(agg.soundProgress['Р'].sessions, 2);
  assert.equal(agg.soundProgress['Р'].successRate, Number((23 / 30).toFixed(3)));
  assert.equal(agg.soundProgress['С'].successRate, Number((4 / 5).toFixed(3)));
});

test('buildRecommendations: zero sessions → starter tips', () => {
  const recs = buildRecommendations({}, 0, 0);
  assert.ok(recs.length >= 1);
  assert.ok(recs[0].includes('занятий') || recs[0].includes('5'));
});

test('buildRecommendations: weakest sound mentioned', () => {
  const sp = {
    'Р': { sessions: 3, attempts: 10, correct: 4, successRate: 0.4 },
    'Л': { sessions: 3, attempts: 10, correct: 9, successRate: 0.9 },
  };
  const recs = buildRecommendations(sp, 6, 0);
  assert.ok(recs.some((r) => r.includes('Р')));
});

test('buildRecommendations: fatigue triggers reduce-duration tip', () => {
  const sp = {
    'Р': { sessions: 5, attempts: 20, correct: 18, successRate: 0.9 },
  };
  const recs = buildRecommendations(sp, 5, 3); // 60% fatigue
  assert.ok(recs.some((r) => r.includes('усталость')));
});

test('currentStageForSound: returns first not-done stage with attempts', () => {
  const sp = {
    prep: { done: true, rate: 0.9, attempts: 30 },
    isolated: { done: true, rate: 0.9, attempts: 40 },
    syllable: { done: false, rate: 0.5, attempts: 20 },
  };
  assert.equal(currentStageForSound(sp), 'syllable');
});

test('currentStageForSound: undefined → null', () => {
  assert.equal(currentStageForSound(undefined), null);
});

test('buildRecommendations: stage-aware back step for weak sound', () => {
  const sp = { 'Р': { sessions: 3, attempts: 10, correct: 4, successRate: 0.4 } };
  const stagesBySound = {
    'Р': { syllable: { done: false, rate: 0.4, attempts: 15 } },
  };
  const recs = buildRecommendations(sp, 6, 0, { stagesBySound });
  // back step for 'syllable' is "вернитесь к изолированному произнесению звука"
  assert.ok(recs.some((r) => r.includes('изолированному')));
});

test('buildRecommendations: week-over-week improvement noted', () => {
  const sp = { 'Л': { sessions: 4, attempts: 40, correct: 36, successRate: 0.9 } };
  const recs = buildRecommendations(sp, 5, 0, {
    prevWeekSuccessRate: 0.7,
    weekSuccessRate: 0.9,
  });
  assert.ok(recs.some((r) => r.includes('прогресс') || r.includes('выросла')));
});

test('buildRecommendations: caps at 3 items', () => {
  const sp = {
    'Р': { sessions: 5, attempts: 20, correct: 8, successRate: 0.4 },
    'Л': { sessions: 5, attempts: 20, correct: 18, successRate: 0.9 },
  };
  const recs = buildRecommendations(sp, 7, 3);
  assert.ok(recs.length <= 3);
});
