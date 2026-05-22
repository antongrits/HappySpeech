'use strict';

/**
 * Unit tests for scoreSpeechQuality pure scoring helper.
 *
 * Только pure-function слой — Cloud Function wrapper тестируется в e2e
 * против Firestore emulator (не входит в этот скоуп).
 */

const test = require('node:test');
const assert = require('node:assert/strict');
const { computeStubScore } = require('../lib/speechQuality');

test('computeStubScore returns deterministic score for same input', () => {
  const a = computeStubScore('audio/recordings/uid1/c1/s1/a1.m4a', 'Р', 6);
  const b = computeStubScore('audio/recordings/uid1/c1/s1/a1.m4a', 'Р', 6);
  assert.equal(a.score, b.score);
  assert.equal(a.confidence, b.confidence);
});

test('computeStubScore output is in [0, 1] range', () => {
  for (const sound of ['Р', 'С', 'Ш', 'К']) {
    for (const age of [5, 6, 7, 10]) {
      const { score, confidence } = computeStubScore(
        `audio/recordings/uidX/cY/sZ/a${age}.m4a`,
        sound,
        age,
      );
      assert.ok(score >= 0 && score <= 1, `score out of range: ${score}`);
      assert.ok(confidence >= 0 && confidence <= 1, `conf out of range: ${confidence}`);
    }
  }
});

test('computeStubScore is sensitive to inputs', () => {
  const a = computeStubScore('audio/recordings/uid1/c1/s1/a1.m4a', 'Р', 6);
  const b = computeStubScore('audio/recordings/uid1/c1/s1/a2.m4a', 'Р', 6);
  // Different path → different seed → different score (overwhelmingly likely).
  assert.notEqual(a.score, b.score);
});

test('computeStubScore: confidence boosted by recordings/ prefix', () => {
  const good = computeStubScore(
    'audio/recordings/uid1/c1/s1/a1.m4a',
    'Р',
    6,
  );
  const bad = computeStubScore(
    'random/path/something.m4a',
    'Р',
    6,
  );
  assert.ok(good.confidence > bad.confidence);
});
