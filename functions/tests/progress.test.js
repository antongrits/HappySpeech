'use strict';

/**
 * Tests for progress aggregation logic.
 *
 * Run:
 *   npm test
 *
 * Note: These tests cover pure functions only. E2E tests against the
 * Firestore emulator live in tests/e2e/ (not scaffolded here).
 */

const test = require('node:test');
const assert = require('node:assert/strict');
const { groupSessionsBySound, emptyStageProgress } = require('../src/progress');
const { buildDailySeries, buildSoundBreakdown, buildRecommendations } = require('../src/reports');

function fakeDoc(data) {
  return { data: () => data };
}

test('emptyStageProgress returns all stages with rate 0', () => {
  const stages = emptyStageProgress();
  assert.equal(stages.prep.rate, 0);
  assert.equal(stages.wordInit.done, false);
  assert.ok('diff' in stages);
});

test('groupSessionsBySound aggregates attempts per sound', () => {
  const docs = [
    fakeDoc({
      targetSound: 'Р', stage: 'wordInit', durationSeconds: 300,
      totalAttempts: 10, correctAttempts: 8,
    }),
    fakeDoc({
      targetSound: 'Р', stage: 'wordInit', durationSeconds: 300,
      totalAttempts: 10, correctAttempts: 9,
    }),
    fakeDoc({
      targetSound: 'Л', stage: 'prep', durationSeconds: 120,
      totalAttempts: 5, correctAttempts: 3,
    }),
  ];
  const grouped = groupSessionsBySound(docs);
  assert.equal(grouped.size, 2);
  assert.equal(grouped.get('Р').totalSessions, 2);
  assert.equal(grouped.get('Р').totalAttempts, 20);
  assert.equal(grouped.get('Р').correctAttempts, 17);
});

test('buildDailySeries groups by day and computes accuracy', () => {
  const date = new Date('2026-04-21T10:00:00Z');
  const docs = [
    fakeDoc({ date: { toDate: () => date }, durationSeconds: 300, totalAttempts: 10, correctAttempts: 8 }),
    fakeDoc({ date: { toDate: () => date }, durationSeconds: 600, totalAttempts: 20, correctAttempts: 15 }),
  ];
  const series = buildDailySeries(docs);
  assert.equal(series.length, 1);
  assert.equal(series[0].sessions, 2);
  assert.equal(series[0].minutes, 15);
  assert.equal(series[0].accuracy, Number((23 / 30).toFixed(3)));
});

test('buildSoundBreakdown produces per-sound aggregates', () => {
  const docs = [
    fakeDoc({ targetSound: 'Р', durationSeconds: 300, totalAttempts: 10, correctAttempts: 9 }),
    fakeDoc({ targetSound: 'Р', durationSeconds: 300, totalAttempts: 10, correctAttempts: 7 }),
    fakeDoc({ targetSound: 'С', durationSeconds: 120, totalAttempts: 5, correctAttempts: 4 }),
  ];
  const out = buildSoundBreakdown(docs);
  const rSound = out.find((x) => x.soundTarget === 'Р');
  assert.equal(rSound.sessions, 2);
  assert.equal(rSound.minutes, 10);
  assert.equal(rSound.accuracy, 0.8);
});

test('buildRecommendations returns starter tip when empty', () => {
  const recs = buildRecommendations([]);
  assert.ok(recs.length >= 1);
});

test('buildRecommendations flags weakest sound', () => {
  const recs = buildRecommendations([
    { soundTarget: 'Р', sessions: 5, minutes: 30, accuracy: 0.4 },
    { soundTarget: 'Л', sessions: 5, minutes: 30, accuracy: 0.95 },
  ]);
  assert.ok(recs.some((r) => r.includes('Р')));
});
