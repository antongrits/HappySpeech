/**
 * scoreSpeechQuality — server-side aggregate speech-quality scoring.
 *
 * ⚠️ COPPA / Kids Category note
 * ───────────────────────────────────────────────────────────────
 * Реальная per-attempt оценка произношения у ребёнка выполняется
 * исключительно on-device в `PronunciationScorerService` (Core ML).
 * Аудио ребёнка НЕ передаётся на сервер для оценки и эта функция НЕ
 * выкачивает байты записи наружу.
 *
 * Что функция делает реально:
 *   1. По `audioStoragePath` определяет, какому ребёнку (uid/childId)
 *      принадлежит запись (путь — единственный «адрес», который шлёт клиент).
 *   2. Читает УЖЕ сохранённые в Firestore агрегированные метрики сессий
 *      этого ребёнка по целевому звуку (accuracy, attempts, динамика).
 *   3. Считает осмысленный quality-скор + confidence из этих метрик.
 *
 * Если по звуку ещё нет сохранённых сессий (первая запись, ещё не
 * долетела до Firestore) — отдаём детерминированный baseline по
 * характеристикам пути/возраста (`computeStubScore`), чтобы дашборд
 * не падал в дырку. Это «холодный старт», а не основной путь.
 *
 * Контракт (см. types/index.ts) — НЕ меняется (iOS-клиент):
 *   IN:  { audioStoragePath, targetSound, childAge }
 *   OUT: { score, confidence, processedAt }
 */

import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import { createHash } from "node:crypto";

import { REGION } from "./constants";
import type {
  Firestore,
  ScoreSpeechQualityRequest,
  ScoreSpeechQualityResponse,
} from "./types";

/** Допустимые звуки для scoring (russian phoneme set, ISO subset). */
const SUPPORTED_SOUNDS: ReadonlySet<string> = new Set([
  "С", "СЬ", "З", "ЗЬ", "Ц",
  "Ш", "Ж", "Ч", "Щ",
  "Р", "РЬ", "Л", "ЛЬ",
  "К", "Г", "Х",
]);

/** Min / max child age for which scoring is calibrated. */
const MIN_AGE = 3;
const MAX_AGE = 12;

/** Сколько последних сессий учитывать при оценке тренда. */
const RECENT_WINDOW = 5;

/** Минимум попыток, после которого мы доверяем агрегату. */
const TRUSTED_ATTEMPTS = 30;

// ────────────────────────────────────────────────────────────────────────────
// Pure helpers (exported for unit tests, mock-free)
// ────────────────────────────────────────────────────────────────────────────

interface SessionMetric {
  /** ISO-8601 дата сессии (для сортировки/тренда). */
  date: string;
  totalAttempts: number;
  correctAttempts: number;
}

export interface QualityBreakdown {
  /** Совокупная точность по всем сессиям звука (0…1). */
  overallAccuracy: number;
  /** Точность по последним RECENT_WINDOW сессиям (0…1). */
  recentAccuracy: number;
  /** recentAccuracy − overallAccuracy (>0 — прогресс, <0 — регресс). */
  trend: number;
  /** Сколько сессий учтено. */
  sessionsCount: number;
  /** Совокупное число попыток (база для confidence). */
  attempts: number;
}

/**
 * Извлечь { uid, childId } из storage-пути записи.
 * Поддерживаются обе исторические конвенции:
 *   - audio/recordings/{uid}/{childId}/{sessionId}/{attemptId}.m4a
 *   - users/{uid}/children/{childId}/recordings/{attemptId}/{file}
 * Возвращает null, если путь не распознан.
 */
export function parseRecordingPath(
  path: string,
): { uid: string; childId: string } | null {
  const seg = path.split("/").filter((s) => s.length > 0);

  if (seg.length >= 4 && seg[0] === "audio" && seg[1] === "recordings") {
    return { uid: seg[2], childId: seg[3] };
  }
  if (seg.length >= 4 && seg[0] === "users" && seg[2] === "children") {
    return { uid: seg[1], childId: seg[3] };
  }
  return null;
}

/**
 * Считает quality-метрики из массива сохранённых сессий.
 * Чистая функция — никаких сетевых вызовов.
 */
export function computeQualityBreakdown(
  sessions: ReadonlyArray<SessionMetric>,
): QualityBreakdown {
  let totalAttempts = 0;
  let totalCorrect = 0;
  for (const s of sessions) {
    totalAttempts += s.totalAttempts;
    totalCorrect += s.correctAttempts;
  }
  const overallAccuracy = totalAttempts > 0 ? totalCorrect / totalAttempts : 0;

  // Последние RECENT_WINDOW сессий по дате (по убыванию date).
  const recent = [...sessions]
    .sort((a, b) => (a.date < b.date ? 1 : -1))
    .slice(0, RECENT_WINDOW);
  let recentAttempts = 0;
  let recentCorrect = 0;
  for (const s of recent) {
    recentAttempts += s.totalAttempts;
    recentCorrect += s.correctAttempts;
  }
  const recentAccuracy = recentAttempts > 0 ?
    recentCorrect / recentAttempts :
    overallAccuracy;

  return {
    overallAccuracy: round3(overallAccuracy),
    recentAccuracy: round3(recentAccuracy),
    trend: round3(recentAccuracy - overallAccuracy),
    sessionsCount: sessions.length,
    attempts: totalAttempts,
  };
}

/**
 * Преобразует breakdown в итоговые score / confidence.
 *
 * score:
 *   взвешенная точность — недавняя динамика весит больше (0.6),
 *   историческая база — меньше (0.4). Это поощряет автоматизацию звука.
 *
 * confidence:
 *   растёт с числом попыток (насыщение на TRUSTED_ATTEMPTS) — чем больше
 *   данных, тем увереннее агрегат. Без данных — низкая уверенность.
 */
export function scoreFromBreakdown(
  bd: QualityBreakdown,
  childAge: number,
): { score: number; confidence: number } {
  if (bd.attempts === 0) {
    return { score: 0, confidence: 0.1 };
  }

  const weighted = 0.6 * bd.recentAccuracy + 0.4 * bd.overallAccuracy;

  // Лёгкая возрастная калибровка: для 5-7 лет тот же результат чуть ценнее
  // (артикуляция ещё формируется) — мягкий бонус, не меняющий порядок.
  const ageBonus = childAge >= 5 && childAge <= 7 ? 0.02 : 0;
  const score = clamp01(round3(weighted + ageBonus));

  const volumeFactor = Math.min(bd.attempts, TRUSTED_ATTEMPTS) / TRUSTED_ATTEMPTS;
  const confidence = clamp01(round3(0.4 + volumeFactor * 0.55));

  return { score, confidence };
}

/**
 * Детерминированный baseline для «холодного старта» — когда по звуку ещё
 * нет сохранённых сессий. Сохранён под прежним именем для unit-тестов и
 * как fallback внутри callable.
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

/**
 * Читает сохранённые сессии ребёнка по целевому звуку из Firestore.
 * Только агрегированные метрики (attempts/correct/date) — аудио не трогаем.
 */
export async function loadSessionMetrics(
  db: Firestore,
  uid: string,
  childId: string,
  targetSound: string,
): Promise<SessionMetric[]> {
  const snap = await db
    .collection("users").doc(uid)
    .collection("children").doc(childId)
    .collection("sessions")
    .where("targetSound", "==", targetSound)
    .get();

  const out: SessionMetric[] = [];
  for (const doc of snap.docs) {
    const data = doc.data() as {
      date?: unknown;
      totalAttempts?: unknown;
      correctAttempts?: unknown;
    };
    out.push({
      date: normalizeDate(data.date),
      totalAttempts: typeof data.totalAttempts === "number" ? data.totalAttempts : 0,
      correctAttempts: typeof data.correctAttempts === "number" ? data.correctAttempts : 0,
    });
  }
  return out;
}

// ────────────────────────────────────────────────────────────────────────────
// Cloud Function
// ────────────────────────────────────────────────────────────────────────────

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

    // ── Authorisation: caller must own the recording path ──────────
    const parsed = parseRecordingPath(audioStoragePath);
    if (!parsed) {
      throw new HttpsError(
        "invalid-argument",
        "audioStoragePath has unrecognised format",
      );
    }
    if (parsed.uid !== callerUid) {
      throw new HttpsError(
        "permission-denied",
        "audioStoragePath does not belong to caller",
      );
    }

    // ── Real aggregate scoring from saved session metrics ──────────
    let score: number;
    let confidence: number;
    try {
      const sessions = await loadSessionMetrics(
        admin.firestore(),
        parsed.uid,
        parsed.childId,
        upperSound,
      );

      if (sessions.length === 0) {
        // Cold start — нет накопленных метрик. Детерминированный baseline.
        const stub = computeStubScore(audioStoragePath, upperSound, childAge);
        score = stub.score;
        confidence = stub.confidence;
      } else {
        const breakdown = computeQualityBreakdown(sessions);
        const real = scoreFromBreakdown(breakdown, childAge);
        score = real.score;
        confidence = real.confidence;
      }
    } catch (error) {
      logger.error("scoreSpeechQuality metrics read failed", {
        error: String(error),
      });
      // Деградация: не валим клиента, отдаём детерминированный baseline.
      const stub = computeStubScore(audioStoragePath, upperSound, childAge);
      score = stub.score;
      confidence = stub.confidence;
    }

    const processedAt = new Date().toISOString();

    // ── Persist aggregate for parent dashboard ─────────────────────
    try {
      await admin.firestore().collection("speechScoreAggregates").add({
        callerUid,
        childId: parsed.childId,
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

/** Нормализует Firestore Timestamp | ISO-строку | Date в ISO-строку. */
function normalizeDate(raw: unknown): string {
  if (typeof raw === "string") return raw;
  if (raw && typeof (raw as { toDate?: () => Date }).toDate === "function") {
    return (raw as { toDate: () => Date }).toDate().toISOString();
  }
  if (raw instanceof Date) return raw.toISOString();
  return "";
}

function clamp01(value: number): number {
  if (value < 0) return 0;
  if (value > 1) return 1;
  return value;
}

function round3(value: number): number {
  return Math.round(value * 1000) / 1000;
}
