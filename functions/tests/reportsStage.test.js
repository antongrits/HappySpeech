'use strict';

/** Unit tests for buildStageBreakdown (sounds × stages table for specialist). */

const test = require('node:test');
const assert = require('node:assert/strict');
const { buildStageBreakdown, buildRecommendations } = require('../lib/reports');

function progressDoc(id, data) {
  return { id, data: () => data };
}

test('buildStageBreakdown: empty → []', () => {
  assert.deepEqual(buildStageBreakdown([]), []);
});

test('buildStageBreakdown: maps stages + finds current stage', () => {
  const docs = [
    progressDoc('Р', {
      soundTarget: 'Р',
      overallRate: 0.72,
      totalSessions: 8,
      totalMinutes: 60,
      stageProgress: {
        prep: { done: true, rate: 0.95, attempts: 30 },
        isolated: { done: true, rate: 0.9, attempts: 40 },
        syllable: { done: false, rate: 0.6, attempts: 25 },
      },
    }),
  ];
  const rows = buildStageBreakdown(docs);
  assert.equal(rows.length, 1);
  const row = rows[0];
  assert.equal(row.soundTarget, 'Р');
  assert.equal(row.overallRate, 0.72);
  assert.equal(row.totalSessions, 8);
  // current stage = first untouched-but-not-done with attempts
  assert.equal(row.currentStage, 'syllable');
  // all 10 canonical stages present
  assert.equal(row.stages.length, 10);
  const syll = row.stages.find((s) => s.stage === 'syllable');
  assert.equal(syll.done, false);
  assert.equal(syll.attempts, 25);
});

test('buildStageBreakdown: falls back to doc.id when soundTarget missing', () => {
  const rows = buildStageBreakdown([progressDoc('С', { stageProgress: {} })]);
  assert.equal(rows[0].soundTarget, 'С');
});

test('buildStageBreakdown: sorts by sound', () => {
  const rows = buildStageBreakdown([
    progressDoc('Ш', { soundTarget: 'Ш', stageProgress: {} }),
    progressDoc('Р', { soundTarget: 'Р', stageProgress: {} }),
  ]);
  assert.equal(rows[0].soundTarget, 'Р');
  assert.equal(rows[1].soundTarget, 'Ш');
});

test('buildRecommendations: weakest sound recommendation mentions current stage', () => {
  const soundBreakdown = [
    { soundTarget: 'Р', sessions: 5, minutes: 40, accuracy: 0.4 },
  ];
  const stageBreakdown = [
    {
      soundTarget: 'Р',
      overallRate: 0.4,
      totalSessions: 5,
      totalMinutes: 40,
      currentStage: 'syllable',
      stages: [],
    },
  ];
  const recs = buildRecommendations(soundBreakdown, stageBreakdown);
  assert.ok(recs.some((r) => r.includes('syllable')), 'expected stage hint');
});

test('buildRecommendations: backward compatible without stageBreakdown', () => {
  const soundBreakdown = [
    { soundTarget: 'Р', sessions: 5, minutes: 40, accuracy: 0.4 },
  ];
  const recs = buildRecommendations(soundBreakdown);
  assert.ok(recs.length >= 1);
  assert.ok(recs.some((r) => r.includes('Р')));
});
