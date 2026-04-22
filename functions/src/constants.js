'use strict';

/**
 * Shared constants for progress, reports, and seed data.
 *
 * Stage order mirrors master-plan-v2.md section 7 + speech-methodology:
 *   prep → isolated → syllable → wordInit → wordMed → wordFinal →
 *   phrase → sentence → story → diff
 */

const STAGES = [
  'prep', 'isolated', 'syllable',
  'wordInit', 'wordMed', 'wordFinal',
  'phrase', 'sentence', 'story', 'diff',
];

const SOUND_GROUPS = {
  whistling: ['С', 'Сь', 'З', 'Зь', 'Ц'],
  hissing: ['Ш', 'Ж', 'Ч', 'Щ'],
  sonorous: ['Р', 'Рь', 'Л', 'Ль'],
  back: ['К', 'Г', 'Х'],
};

const TEMPLATE_TYPES = [
  'listen-and-choose', 'repeat-after-model', 'drag-and-match',
  'story-completion', 'puzzle-reveal', 'sorting', 'memory', 'bingo',
  'sound-hunter', 'articulation-imitation', 'AR-activity',
  'visual-acoustic', 'breathing', 'rhythm', 'narrative-quest', 'minimal-pairs',
];

const STAGE_PASS_THRESHOLD = 0.85;    // rate required to mark stage done
const MIN_ATTEMPTS_FOR_STAGE = 20;    // minimum attempts before we trust the rate

module.exports = {
  STAGES,
  SOUND_GROUPS,
  TEMPLATE_TYPES,
  STAGE_PASS_THRESHOLD,
  MIN_ATTEMPTS_FOR_STAGE,
};
