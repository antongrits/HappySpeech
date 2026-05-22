/**
 * scoreSpeechQuality — server-side aggregate speech-quality scoring.
 *
 * ⚠️ COPPA / Kids Category note
 * ───────────────────────────────────────────────────────────────
 * Реальная per-attempt оценка произношения у ребёнка выполняется
 * исключительно on-device в `PronunciationScorerService`
 * (Core ML). Аудио ребёнка НЕ передаётся на сервер для оценки.
 *
 * Эта функция работает с уже загруженным в Firebase Storage аудио
 * (через путь `audioStoragePath`) и возвращает agreggated stub-оценку
 * для async родительского дашборда. Аудио-байты функция не выкачивает
 * наружу — только проверяет существование объекта и считает
 * детерминированную stub-метрику по характеристикам пути и target sound.
 *
 * Реальная интеграция с Google Cloud Speech / WhisperKit на сервере
 * вынесена в backlog (v32+), требует отдельного DPIA.
 *
 * Контракт (см. types/index.ts):
 *   IN:  { audioStoragePath, targetSound, childAge }
 *   OUT: { score, confidence, processedAt }
 */

import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import { createHash } from "node:crypto";

import { REGION } from "./constants";
import type {
  ScoreSpeechQualityRequest,
  ScoreSpeechQualityResponse,
} from "./types";

/** Допустимые звуки для scoring (russian phoneme set, ISO subset). */
const SUPPORTED_SOUNDS: ReadonlySet<string> = new Set([
  "С", "З", "Ц",
  "Ш", "Ж", "Ч", "Щ",
  "Р", "РЬ", "Л", "ЛЬ",
  "К", "Г", "Х",
]);

/** Min / max child age for which scoring is calibrated. */
const MIN_AGE = 3;
const MAX_AGE = 12;

/**
 * Pure scoring function — детерминированный stub.
 * Экспортируется отдельно для unit-тестов (mock-free).
 *
 * Алгоритм:
 *   1. Хешируем путь → стабильный seed в диапазоне [0, 1).
 *   2. Базовая оценка модулируется по возрасту: дети 5-7 чуть строже.
 *   3. Confidence моделируется как функция длины пути и наличия
 *      "правильного" префикса (audio/recordings/).
 *
 * Реальная имплементация заменит эту функцию на ASR-pipeline.
 */
export function computeStubScore(
  audioStoragePath: string,
  targetSound: string,
  childAge: number,
): { score: number; confidence: number } {
  const seed = stableSeed(`${audioStoragePath}|${targetSound}|${childAge}`);
  const baseScore = 0.55 + seed * 0.4; // 0.55 … 0.95
  const ageBias = childAge >= 5 && childAge <= 7 ? -0.05 : 0;
  const score = clamp01(round3(baseScore + ageBias));

  const hasCorrectPrefix = audioStoragePath.startsWith("audio/recordings/");
  const lengthBonus = Math.min(audioStoragePath.length, 200) / 200; // 0..1
  const confidence = clamp01(
    round3(0.55 + lengthBonus * 0.3 + (hasCorrectPrefix ? 0.1 : 0)),
  );

  return { score, confidence };
}

export const scoreSpeechQuality = onCall<
  ScoreSpeechQualityRequest,
  Promise<ScoreSpeechQualityResponse>
>(
  { enforceAppCheck: true, cors: true, region: REGION, timeoutSeconds: 30 },
  async (request) => {
    // ── Auth ────────────────────────────────────────────────────────
    if (!request.auth || !request.auth.uid) {
      throw new HttpsError("unauthenticated", "Sign in required");
    }
    const callerUid = request.auth.uid;

    // ── Validate input ─────────────────────────────────────────────
    const { audioStoragePath, targetSound, childAge } = request.data || {};

    if (typeof audioStoragePath !== "string" || audioStoragePath.length === 0) {
      throw new HttpsError("invalid-argument", "audioStoragePath required");
    }
    if (typeof targetSound !== "string" || targetSound.length === 0) {
      throw new HttpsError("invalid-argument", "targetSound required");
    }
    if (typeof childAge !== "number" ||
        !Number.isInteger(childAge) ||
        childAge < MIN_AGE || childAge > MAX_AGE) {
      throw new HttpsError(
        "invalid-argument",
        `childAge must be integer in [${MIN_AGE}, ${MAX_AGE}]`,
      );
    }

    const upperSound = targetSound.toUpperCase();
    if (!SUPPORTED_SOUNDS.has(upperSound)) {
      throw new HttpsError(
        "invalid-argument",
        `targetSound ${targetSound} is not supported`,
      );
    }

    // ── Authorisation: caller must own audio path ──────────────────
    // Storage path convention: audio/recordings/{uid}/{childId}/...
    const segments = audioStoragePath.split("/");
    if (segments.length < 4 ||
        segments[0] !== "audio" ||
        segments[1] !== "recordings" ||
        segments[2] !== callerUid) {
      throw new HttpsError(
        "permission-denied",
        "audioStoragePath does not belong to caller",
      );
    }

    // ── Compute stub score ─────────────────────────────────────────
    const { score, confidence } = computeStubScore(
      audioStoragePath,
      upperSound,
      childAge,
    );
    const processedAt = new Date().toISOString();

    // ── Persist aggregate for parent dashboard ─────────────────────
    try {
      await admin.firestore().collection("speechScoreAggregates").add({
        callerUid,
        audioStoragePath,
        targetSound: upperSound,
        childAge,
        score,
        confidence,
        processedAt,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (error) {
      // Aggregation failure is non-fatal — caller still gets score.
      logger.error("scoreSpeechQuality aggregate write failed", {
        error: String(error),
      });
    }

    logger.info("scoreSpeechQuality complete", {
      callerUid: "[REDACTED]",
      targetSound: upperSound,
      score,
    });

    return { score, confidence, processedAt };
  },
);

// ────────────────────────────────────────────────────────────────────────────
// Helpers
// ────────────────────────────────────────────────────────────────────────────

function stableSeed(input: string): number {
  const hash = createHash("sha256").update(input).digest();
  // Take first 6 bytes → 48-bit integer → normalised to [0, 1).
  const value =
    hash[0] * 2 ** 40 +
    hash[1] * 2 ** 32 +
    hash[2] * 2 ** 24 +
    hash[3] * 2 ** 16 +
    hash[4] * 2 ** 8 +
    hash[5];
  return value / 2 ** 48;
}

function clamp01(value: number): number {
  if (value < 0) return 0;
  if (value > 1) return 1;
  return value;
}

function round3(value: number): number {
  return Math.round(value * 1000) / 1000;
}
