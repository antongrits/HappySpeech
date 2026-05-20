/**
 * Shared constants for progress, reports, and seed data.
 *
 * Stage order mirrors master-plan-v2.md section 7 + speech-methodology:
 *   prep → isolated → syllable → wordInit → wordMed → wordFinal →
 *   phrase → sentence → story → diff
 */

export const STAGES: readonly string[] = [
  "prep", "isolated", "syllable",
  "wordInit", "wordMed", "wordFinal",
  "phrase", "sentence", "story", "diff",
] as const;

export const SOUND_GROUPS: Readonly<Record<string, readonly string[]>> = {
  whistling: ["С", "Сь", "З", "Зь", "Ц"],
  hissing: ["Ш", "Ж", "Ч", "Щ"],
  sonorous: ["Р", "Рь", "Л", "Ль"],
  back: ["К", "Г", "Х"],
} as const;

export const TEMPLATE_TYPES: readonly string[] = [
  "listen-and-choose", "repeat-after-model", "drag-and-match",
  "story-completion", "puzzle-reveal", "sorting", "memory", "bingo",
  "sound-hunter", "articulation-imitation", "AR-activity",
  "visual-acoustic", "breathing", "rhythm", "narrative-quest", "minimal-pairs",
] as const;

/** Rate required to mark a stage as done. */
export const STAGE_PASS_THRESHOLD = 0.85;

/** Minimum attempts before we trust the rate. */
export const MIN_ATTEMPTS_FOR_STAGE = 20;

/** Cloud Functions region — close to target audience (Russia/CIS). */
export const REGION = "europe-west3";
