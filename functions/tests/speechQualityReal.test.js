'use strict';

/**
 * Unit tests for the REAL aggregate scoring layer of scoreSpeechQuality.
 * Чистые функции, без сети — Firestore read тестируется e2e против эмулятора.
 */

const test = require('node:test');
const assert = require('node:assert/strict');
const {
  parseRecordingPath,
  computeQualityBreakdown,
  scoreFromBreakdown,
} = require('../lib/speechQuality');

test('parseRecordingPath: audio/recordings convention', () => {
  const r = parseRecordingPath('audio/recordings/uid1/child1/sess1/att1.m4a');
  assert.deepEqual(r, { uid: 'uid1', childId: 'child1' });
});

test('parseRecordingPath: users/children convention', () => {
  const r = parseRecordingPath('users/uid9/children/child9/recordings/att1/file.m4a');
  assert.deepEqual(r, { uid: 'uid9', childId: 'child9' });
});

test('parseRecordingPath: unrecognised → null', () => {
  assert.equal(parseRecordingPath('random/blob.m4a'), null);
  assert.equal(parseRecordingPath(''), null);
});

test('computeQualityBreakdown: empty → zeros', () => {
  const bd = computeQualityBreakdown([]);
  assert.equal(bd.overallAccuracy, 0);
  assert.equal(bd.attempts, 0);
  assert.equal(bd.sessionsCount, 0);
});

test('computeQualityBreakdown: aggregates accuracy + trend', () => {
  const sessions = [
    { date: '2026-05-01T10:00:00Z', totalAttempts: 10, correctAttempts: 5 },  // 0.5 old
    { date: '2026-05-20T10:00:00Z', totalAttempts: 10, correctAttempts: 9 },  // 0.9 recent
  ];
  const bd = computeQualityBreakdown(sessions);
  assert.equal(bd.overallAccuracy, 0.7); // 14/20
  // recent window (5) covers both; recentAccuracy == overall here
  assert.equal(bd.recentAccuracy, 0.7);
  assert.equal(bd.attempts, 20);
  assert.equal(bd.sessionsCount, 2);
});

test('computeQualityBreakdown: recent window favours newest sessions', () => {
  const sessions = [];
  // 6 old sessions at 0.4, then 1 brand new at 1.0 — window=5 should not include all old
  for (let i = 0; i < 6; i++) {
    sessions.push({ date: `2026-04-0${i + 1}T10:00:00Z`, totalAttempts: 10, correctAttempts: 4 });
  }
  sessions.push({ date: '2026-05-25T10:00:00Z', totalAttempts: 10, correctAttempts: 10 });
  const bd = computeQualityBreakdown(sessions);
  assert.ok(bd.recentAccuracy > bd.overallAccuracy, 'recent should beat overall (improving)');
  assert.ok(bd.trend > 0);
});

test('scoreFromBreakdown: no attempts → score 0, low confidence', () => {
  const r = scoreFromBreakdown(
    { overallAccuracy: 0, recentAccuracy: 0, trend: 0, sessionsCount: 0, attempts: 0 },
    6,
  );
  assert.equal(r.score, 0);
  assert.ok(r.confidence <= 0.2);
});

test('scoreFromBreakdown: confidence grows with attempts', () => {
  const few = scoreFromBreakdown(
    { overallAccuracy: 0.8, recentAccuracy: 0.8, trend: 0, sessionsCount: 1, attempts: 5 },
    8,
  );
  const many = scoreFromBreakdown(
    { overallAccuracy: 0.8, recentAccuracy: 0.8, trend: 0, sessionsCount: 6, attempts: 60 },
    8,
  );
  assert.ok(many.confidence > few.confidence);
  assert.ok(many.confidence <= 1);
});

test('scoreFromBreakdown: recent improvement raises score above overall', () => {
  const improving = scoreFromBreakdown(
    { overallAccuracy: 0.5, recentAccuracy: 0.9, trend: 0.4, sessionsCount: 4, attempts: 40 },
    10,
  );
  // weighted = 0.6*0.9 + 0.4*0.5 = 0.74
  assert.ok(improving.score > 0.5 && improving.score <= 1);
});

test('scoreFromBreakdown: age 5-7 gets small bonus', () => {
  const bd = { overallAccuracy: 0.7, recentAccuracy: 0.7, trend: 0, sessionsCount: 3, attempts: 30 };
  const young = scoreFromBreakdown(bd, 6);
  const older = scoreFromBreakdown(bd, 10);
  assert.ok(young.score >= older.score);
});
