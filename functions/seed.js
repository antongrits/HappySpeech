'use strict';

/**
 * Seed script for /exercises and /content collections.
 *
 * Usage:
 *   # Against Firestore emulator (recommended for dev):
 *   FIRESTORE_EMULATOR_HOST=localhost:8080 GOOGLE_CLOUD_PROJECT=happyspeech-prod node seed.js
 *
 *   # Against production (requires GOOGLE_APPLICATION_CREDENTIALS):
 *   GOOGLE_APPLICATION_CREDENTIALS=./service-account.json node seed.js
 *
 * Data source: api-contracts.md section 2 + speech-methodology groups.
 */

const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp({
    projectId: process.env.GOOGLE_CLOUD_PROJECT || 'happyspeech-prod',
  });
}

const db = admin.firestore();

// ------------------------------------------------------------------
// Word cards (content) — small curated set per sound
// ------------------------------------------------------------------

const CONTENT_CARDS = [
  // Р
  { id: 'card-ra-1', soundTarget: 'Р', position: 'init', word: 'рак', imageHint: 'рак', difficulty: 1 },
  { id: 'card-ra-2', soundTarget: 'Р', position: 'init', word: 'роза', imageHint: 'роза', difficulty: 1 },
  { id: 'card-ra-3', soundTarget: 'Р', position: 'init', word: 'рыба', imageHint: 'рыба', difficulty: 1 },
  { id: 'card-ra-4', soundTarget: 'Р', position: 'med', word: 'корова', imageHint: 'корова', difficulty: 2 },
  { id: 'card-ra-5', soundTarget: 'Р', position: 'med', word: 'ворона', imageHint: 'ворона', difficulty: 2 },
  { id: 'card-ra-6', soundTarget: 'Р', position: 'final', word: 'топор', imageHint: 'топор', difficulty: 2 },
  // Л
  { id: 'card-la-1', soundTarget: 'Л', position: 'init', word: 'лапа', imageHint: 'лапа', difficulty: 1 },
  { id: 'card-la-2', soundTarget: 'Л', position: 'init', word: 'лодка', imageHint: 'лодка', difficulty: 1 },
  { id: 'card-la-3', soundTarget: 'Л', position: 'med', word: 'пила', imageHint: 'пила', difficulty: 2 },
  { id: 'card-la-4', soundTarget: 'Л', position: 'final', word: 'стол', imageHint: 'стол', difficulty: 2 },
  // С
  { id: 'card-sa-1', soundTarget: 'С', position: 'init', word: 'сани', imageHint: 'сани', difficulty: 1 },
  { id: 'card-sa-2', soundTarget: 'С', position: 'init', word: 'сумка', imageHint: 'сумка', difficulty: 1 },
  { id: 'card-sa-3', soundTarget: 'С', position: 'med', word: 'коса', imageHint: 'коса', difficulty: 2 },
  { id: 'card-sa-4', soundTarget: 'С', position: 'final', word: 'нос', imageHint: 'нос', difficulty: 2 },
  // Ш
  { id: 'card-sha-1', soundTarget: 'Ш', position: 'init', word: 'шапка', imageHint: 'шапка', difficulty: 1 },
  { id: 'card-sha-2', soundTarget: 'Ш', position: 'init', word: 'шарф', imageHint: 'шарф', difficulty: 1 },
  { id: 'card-sha-3', soundTarget: 'Ш', position: 'med', word: 'мишка', imageHint: 'мишка', difficulty: 2 },
  { id: 'card-sha-4', soundTarget: 'Ш', position: 'final', word: 'душ', imageHint: 'душ', difficulty: 2 },
  // З
  { id: 'card-za-1', soundTarget: 'З', position: 'init', word: 'зонт', imageHint: 'зонт', difficulty: 1 },
  { id: 'card-za-2', soundTarget: 'З', position: 'med', word: 'ваза', imageHint: 'ваза', difficulty: 2 },
];

// ------------------------------------------------------------------
// Exercise definitions — at least 10 per template type
// ------------------------------------------------------------------

/**
 * Build a generic exercise doc.
 */
function mkExercise(template, sound, variant, stage, difficulty, wordIds) {
  return {
    id: `ex-${template}-${sound}-${variant}`,
    templateType: template,
    targetSound: sound,
    stage,
    difficulty,
    wordIds,
    durationTargetSec: 180,
    locale: 'ru',
    version: 1,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  };
}

const EXERCISES = [];

// 10 listen-and-choose across sounds + stages
['Р', 'Л', 'С', 'Ш', 'З'].forEach((sound, i) => {
  EXERCISES.push(mkExercise('listen-and-choose', sound, 'init-1', 'wordInit', 1,
    CONTENT_CARDS.filter((c) => c.soundTarget === sound && c.position === 'init').map((c) => c.id)));
  EXERCISES.push(mkExercise('listen-and-choose', sound, 'med-1', 'wordMed', 2,
    CONTENT_CARDS.filter((c) => c.soundTarget === sound && c.position === 'med').map((c) => c.id)));
});

// 10 repeat-after-model
['Р', 'Л', 'С', 'Ш', 'З'].forEach((sound) => {
  EXERCISES.push(mkExercise('repeat-after-model', sound, 'init-1', 'wordInit', 1,
    CONTENT_CARDS.filter((c) => c.soundTarget === sound).slice(0, 3).map((c) => c.id)));
  EXERCISES.push(mkExercise('repeat-after-model', sound, 'phrase-1', 'phrase', 2,
    CONTENT_CARDS.filter((c) => c.soundTarget === sound).slice(0, 4).map((c) => c.id)));
});

// 10 sorting
['Р', 'Л', 'С', 'Ш', 'З'].forEach((sound) => {
  EXERCISES.push(mkExercise('sorting', sound, 'position-1', 'wordMed', 2,
    CONTENT_CARDS.filter((c) => c.soundTarget === sound).map((c) => c.id)));
  EXERCISES.push(mkExercise('sorting', sound, 'position-2', 'wordFinal', 2,
    CONTENT_CARDS.filter((c) => c.soundTarget === sound).map((c) => c.id)));
});

// ------------------------------------------------------------------
// Seed runner
// ------------------------------------------------------------------

async function seedCollection(collection, docs) {
  const batch = db.batch();
  for (const doc of docs) {
    const ref = db.collection(collection).doc(doc.id);
    batch.set(ref, doc, { merge: true });
  }
  await batch.commit();
  return docs.length;
}

async function run() {
  const contentCount = await seedCollection('content', CONTENT_CARDS);
  const exerciseCount = await seedCollection('exercises', EXERCISES);
  console.log(`Seeded ${contentCount} content cards, ${exerciseCount} exercises`);
}

run()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Seed failed:', err);
    process.exit(1);
  });
