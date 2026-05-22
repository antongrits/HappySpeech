/**
 * generateNeurolinguistSummary — еженедельная rule-based сводка для родителя.
 *
 * COPPA-safe:
 *   - Никаких LLM на сервере (kid privacy).
 *   - Только агрегация сессий уже сохранённых в Firestore.
 *   - Рекомендации генерируются rule-based: weakest sound, fatigue, streak.
 *   - Текст рекомендаций — на русском, статический шаблон + подстановки.
 *
 * Контракт:
 *   IN:  { childId: string, weekOffset: number }
 *        weekOffset = 0 → текущая неделя (Mon..Sun), 1 → прошлая, …
 *   OUT: { weekSummary: WeekSummary }
 */

import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";

import { REGION } from "./constants";
import { assertAuthorized } from "./auth";
import type {
  NeurolinguistSummaryRequest,
  NeurolinguistSummaryResponse,
  SoundProgressSnapshot,
  WeekSummary,
} from "./types";

interface SessionDoc {
  targetSound?: unknown;
  stage?: unknown;
  durationSeconds?: unknown;
  totalAttempts?: unknown;
  correctAttempts?: unknown;
  date?: unknown;
  fatigueDetected?: unknown;
}

const MAX_WEEK_OFFSET = 26; // ~6 месяцев истории

// ────────────────────────────────────────────────────────────────────────────
// Pure aggregation helpers (exported for unit tests)
// ────────────────────────────────────────────────────────────────────────────

export function weekBoundaries(referenceDate: Date, offset: number): {
  start: Date;
  end: Date;
} {
  // Monday is start-of-week (ISO 8601). Slice off any TZ — server is UTC.
  const ref = new Date(referenceDate);
  ref.setUTCHours(0, 0, 0, 0);
  const dayOfWeek = ref.getUTCDay(); // 0 = Sunday
  const daysSinceMonday = (dayOfWeek + 6) % 7;
  const monday = new Date(ref);
  monday.setUTCDate(ref.getUTCDate() - daysSinceMonday - offset * 7);
  const sunday = new Date(monday);
  sunday.setUTCDate(monday.getUTCDate() + 7);
  return { start: monday, end: sunday };
}

export function aggregateSessions(
  docs: ReadonlyArray<{ data: () => SessionDoc }>,
): {
  totalSessions: number;
  totalMinutes: number;
  totalAttempts: number;
  correctAttempts: number;
  fatigueCount: number;
  soundProgress: Record<string, SoundProgressSnapshot>;
} {
  const sounds: Record<string, {
    sessions: number;
    attempts: number;
    correct: number;
  }> = {};

  let totalSessions = 0;
  let totalSeconds = 0;
  let totalAttempts = 0;
  let correctAttempts = 0;
  let fatigueCount = 0;

  for (const doc of docs) {
    const data = doc.data();
    totalSessions += 1;

    const seconds = typeof data.durationSeconds === "number" ?
      data.durationSeconds :
      0;
    totalSeconds += seconds;

    const attempts = typeof data.totalAttempts === "number" ?
      data.totalAttempts :
      0;
    const correct = typeof data.correctAttempts === "number" ?
      data.correctAttempts :
      0;
    totalAttempts += attempts;
    correctAttempts += correct;

    if (data.fatigueDetected === true) fatigueCount += 1;

    const sound = typeof data.targetSound === "string" && data.targetSound.length > 0 ?
      data.targetSound :
      "—";
    if (!sounds[sound]) sounds[sound] = { sessions: 0, attempts: 0, correct: 0 };
    sounds[sound].sessions += 1;
    sounds[sound].attempts += attempts;
    sounds[sound].correct += correct;
  }

  const soundProgress: Record<string, SoundProgressSnapshot> = {};
  for (const [sound, bucket] of Object.entries(sounds)) {
    soundProgress[sound] = {
      sessions: bucket.sessions,
      attempts: bucket.attempts,
      correct: bucket.correct,
      successRate: bucket.attempts > 0 ?
        round3(bucket.correct / bucket.attempts) :
        0,
    };
  }

  return {
    totalSessions,
    totalMinutes: Math.round(totalSeconds / 60),
    totalAttempts,
    correctAttempts,
    fatigueCount,
    soundProgress,
  };
}

export function buildRecommendations(
  soundProgress: Record<string, SoundProgressSnapshot>,
  totalSessions: number,
  fatigueCount: number,
): string[] {
  const recs: string[] = [];

  if (totalSessions === 0) {
    return [
      "На этой неделе не было занятий — попробуйте короткую 5-минутную сессию сегодня.",
      "Регулярность важнее длительности: лучше 5 минут каждый день, чем час раз в неделю.",
      "Откройте уголок «Ляли» — там есть готовые мини-игры на 3 минуты.",
    ];
  }

  // Weakest sound (lowest success rate среди звуков с ≥2 сессиями).
  const eligible = Object.entries(soundProgress)
    .filter(([, snap]) => snap.sessions >= 2);
  if (eligible.length > 0) {
    eligible.sort((a, b) => a[1].successRate - b[1].successRate);
    const [weakSound, weakSnap] = eligible[0];
    if (weakSnap.successRate < 0.6) {
      recs.push(
        `Звук «${weakSound}» даётся сложнее всего (${Math.round(weakSnap.successRate * 100)}%). ` +
        "Вернитесь к этапу слогов на следующей неделе.",
      );
    }
  }

  // Strong sound (для позитивного фидбека).
  const strong = Object.entries(soundProgress)
    .filter(([, s]) => s.sessions >= 2 && s.successRate >= 0.8);
  if (strong.length > 0) {
    const [strongSound] = strong.sort(
      (a, b) => b[1].successRate - a[1].successRate,
    )[0];
    recs.push(
      `Отлично закреплён звук «${strongSound}» — можно переходить к фразам и предложениям.`,
    );
  }

  // Fatigue rate.
  if (fatigueCount > 0 && totalSessions > 0) {
    const rate = fatigueCount / totalSessions;
    if (rate >= 0.3) {
      recs.push(
        "Часто фиксировалась усталость — попробуйте сократить занятия до 7-10 минут " +
        "и добавить дыхательные паузы между упражнениями.",
      );
    }
  }

  // Cadence.
  if (totalSessions < 3) {
    recs.push(
      "Меньше 3 занятий за неделю — постарайтесь увеличить регулярность до 4-5 раз.",
    );
  } else if (totalSessions >= 6) {
    recs.push(
      "Отличная регулярность занятий! Не забывайте про выходной день для отдыха.",
    );
  }

  if (recs.length === 0) {
    recs.push("Хорошая неделя — продолжайте в том же ритме.");
  }

  return recs.slice(0, 3);
}

// ────────────────────────────────────────────────────────────────────────────
// Cloud Function
// ────────────────────────────────────────────────────────────────────────────

export const generateNeurolinguistSummary = onCall<
  NeurolinguistSummaryRequest,
  Promise<NeurolinguistSummaryResponse>
>(
  { enforceAppCheck: true, cors: true, region: REGION, timeoutSeconds: 60 },
  async (request) => {
    if (!request.auth || !request.auth.uid) {
      throw new HttpsError("unauthenticated", "Sign in required");
    }
    const callerUid = request.auth.uid;

    const { childId, weekOffset } = request.data || {};

    if (typeof childId !== "string" || childId.length === 0) {
      throw new HttpsError("invalid-argument", "childId required");
    }
    const offset = (typeof weekOffset === "number" &&
                    Number.isInteger(weekOffset) &&
                    weekOffset >= 0 && weekOffset <= MAX_WEEK_OFFSET) ?
      weekOffset :
      0;

    // Authorise: caller must be the parent of {callerUid, childId} OR specialist.
    await assertAuthorized(request.auth, callerUid, childId);

    const { start, end } = weekBoundaries(new Date(), offset);
    const startIso = start.toISOString();
    const endIso = end.toISOString();

    try {
      const snap = await admin.firestore()
        .collection("users").doc(callerUid)
        .collection("children").doc(childId)
        .collection("sessions")
        .where("date", ">=", startIso)
        .where("date", "<", endIso)
        .get();

      const agg = aggregateSessions(snap.docs);
      const avgSuccessRate = agg.totalAttempts > 0 ?
        round3(agg.correctAttempts / agg.totalAttempts) :
        0;

      const weekSummary: WeekSummary = {
        weekStart: startIso,
        weekEnd: endIso,
        totalSessions: agg.totalSessions,
        totalMinutes: agg.totalMinutes,
        avgSuccessRate,
        soundProgress: agg.soundProgress,
        recommendations: buildRecommendations(
          agg.soundProgress,
          agg.totalSessions,
          agg.fatigueCount,
        ),
      };

      logger.info("generateNeurolinguistSummary complete", {
        callerUid: "[REDACTED]",
        childId: "[REDACTED]",
        offset,
        sessions: agg.totalSessions,
      });

      return { weekSummary };
    } catch (error) {
      logger.error("generateNeurolinguistSummary failed", {
        error: String(error),
      });
      if (error instanceof HttpsError) throw error;
      throw new HttpsError("internal", "Failed to generate summary");
    }
  },
);

function round3(value: number): number {
  return Math.round(value * 1000) / 1000;
}
