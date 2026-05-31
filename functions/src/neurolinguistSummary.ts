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

/**
 * Карта «следующего шага» по этапам коррекции (методология русской
 * логопедии: подготовка → изолированный → слоги → слова → фразы → …).
 * Используется, чтобы рекомендация ссылалась на реальный этап ребёнка,
 * а не на абстрактные «слоги».
 */
const STAGE_NEXT_STEP: Readonly<Record<string, string>> = {
  prep: "переходите к вызыванию изолированного звука",
  isolated: "закрепляйте звук в слогах (прямых и обратных)",
  syllable: "вводите слова с целевым звуком в начале",
  wordInit: "отрабатывайте звук в середине и в конце слов",
  wordMed: "отрабатывайте звук в конце слов и в стечениях согласных",
  wordFinal: "переходите к коротким фразам",
  phrase: "стройте предложения с целевым звуком",
  sentence: "практикуйте звук в коротких рассказах",
  story: "переходите к дифференциации со смешиваемым звуком",
  diff: "закрепляйте автоматизацию в свободной речи",
};

const STAGE_BACK_STEP: Readonly<Record<string, string>> = {
  isolated: "вернитесь к артикуляционной разминке",
  syllable: "вернитесь к изолированному произнесению звука",
  wordInit: "вернитесь к слогам",
  wordMed: "повторите слова со звуком в начале",
  wordFinal: "повторите слова со звуком в середине",
  phrase: "вернитесь к отдельным словам",
  sentence: "вернитесь к коротким фразам",
  story: "вернитесь к предложениям",
  diff: "повторите рассказы на каждый из звуков отдельно",
};

/**
 * Текущий этап ребёнка по звуку — самый продвинутый этап с ненулевыми
 * попытками среди ещё-не-завершённых. Возвращает null, если данных нет.
 */
export function currentStageForSound(
  stageProgress: Record<string, { done: boolean; rate: number; attempts: number }> | undefined,
): string | null {
  if (!stageProgress) return null;
  const order = [
    "prep", "isolated", "syllable", "wordInit", "wordMed",
    "wordFinal", "phrase", "sentence", "story", "diff",
  ];
  let current: string | null = null;
  for (const stage of order) {
    const s = stageProgress[stage];
    if (s && s.attempts > 0) {
      current = stage; // most advanced touched stage
      if (!s.done) break; // остановиться на первом незакрытом
    }
  }
  return current;
}

export function buildRecommendations(
  soundProgress: Record<string, SoundProgressSnapshot>,
  totalSessions: number,
  fatigueCount: number,
  options: {
    /** stageProgress по звукам из /progress/{sound} (для этап-aware советов). */
    stagesBySound?: Record<string, Record<string, { done: boolean; rate: number; attempts: number }>>;
    /** avgSuccessRate прошлой недели — для динамики неделя-к-неделе. */
    prevWeekSuccessRate?: number | null;
    /** avgSuccessRate текущей недели — для динамики. */
    weekSuccessRate?: number | null;
  } = {},
): string[] {
  const recs: string[] = [];

  if (totalSessions === 0) {
    return [
      "На этой неделе не было занятий — попробуйте короткую 5-минутную сессию сегодня.",
      "Регулярность важнее длительности: лучше 5 минут каждый день, чем час раз в неделю.",
      "Откройте уголок «Ляли» — там есть готовые мини-игры на 3 минуты.",
    ];
  }

  const stagesBySound = options.stagesBySound ?? {};

  // Weakest sound (lowest success rate среди звуков с ≥2 сессиями) — с привязкой
  // к реальному этапу коррекции ребёнка.
  const eligible = Object.entries(soundProgress)
    .filter(([, snap]) => snap.sessions >= 2);
  if (eligible.length > 0) {
    eligible.sort((a, b) => a[1].successRate - b[1].successRate);
    const [weakSound, weakSnap] = eligible[0];
    if (weakSnap.successRate < 0.6) {
      const stage = currentStageForSound(stagesBySound[weakSound]);
      const backStep = stage ? STAGE_BACK_STEP[stage] : null;
      const tail = backStep ?
        ` На следующей неделе ${backStep} — закрепите базу, прежде чем усложнять.` :
        " Вернитесь на шаг назад по этапам и закрепите базу.";
      recs.push(
        `Звук «${weakSound}» даётся сложнее всего (${Math.round(weakSnap.successRate * 100)}%).` +
        tail,
      );
    }
  }

  // Strong sound (для позитивного фидбека) — со ссылкой на следующий этап.
  const strong = Object.entries(soundProgress)
    .filter(([, s]) => s.sessions >= 2 && s.successRate >= 0.8);
  if (strong.length > 0) {
    const [strongSound] = strong.sort(
      (a, b) => b[1].successRate - a[1].successRate,
    )[0];
    const stage = currentStageForSound(stagesBySound[strongSound]);
    const nextStep = stage ? STAGE_NEXT_STEP[stage] : null;
    const tail = nextStep ?
      ` — можно ${nextStep}.` :
      " — можно переходить к фразам и предложениям.";
    recs.push(`Отлично закреплён звук «${strongSound}»${tail}`);
  }

  // Динамика неделя-к-неделе.
  const prev = options.prevWeekSuccessRate;
  const cur = options.weekSuccessRate;
  if (typeof prev === "number" && prev > 0 && typeof cur === "number") {
    const delta = cur - prev;
    if (delta >= 0.05) {
      recs.push(
        `Заметный прогресс: средняя точность выросла с ${Math.round(prev * 100)}% ` +
        `до ${Math.round(cur * 100)}%. Так держать!`,
      );
    } else if (delta <= -0.1) {
      recs.push(
        `Точность снизилась с ${Math.round(prev * 100)}% до ${Math.round(cur * 100)}% — ` +
        "это нормальный спад; не усложняйте материал, дайте звуку «осесть».",
      );
    }
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

    // Прошлая неделя — для динамики неделя-к-неделе.
    const prevBounds = weekBoundaries(new Date(), offset + 1);
    const prevStartIso = prevBounds.start.toISOString();
    const prevEndIso = prevBounds.end.toISOString();

    try {
      const db = admin.firestore();
      const sessionsRef = db
        .collection("users").doc(callerUid)
        .collection("children").doc(childId)
        .collection("sessions");

      const [snap, prevSnap, progressSnap] = await Promise.all([
        sessionsRef
          .where("date", ">=", startIso)
          .where("date", "<", endIso)
          .get(),
        sessionsRef
          .where("date", ">=", prevStartIso)
          .where("date", "<", prevEndIso)
          .get(),
        db
          .collection("users").doc(callerUid)
          .collection("children").doc(childId)
          .collection("progress")
          .get(),
      ]);

      const agg = aggregateSessions(snap.docs);
      const avgSuccessRate = agg.totalAttempts > 0 ?
        round3(agg.correctAttempts / agg.totalAttempts) :
        0;

      const prevAgg = aggregateSessions(prevSnap.docs);
      const prevSuccessRate = prevAgg.totalAttempts > 0 ?
        round3(prevAgg.correctAttempts / prevAgg.totalAttempts) :
        null;

      // Этапы коррекции из /progress/{sound} — для этап-aware рекомендаций.
      const stagesBySound: Record<
        string,
        Record<string, { done: boolean; rate: number; attempts: number }>
      > = {};
      for (const doc of progressSnap.docs) {
        const data = doc.data() as {
          soundTarget?: string;
          stageProgress?: Record<string, { done: boolean; rate: number; attempts: number }>;
        };
        const key = typeof data.soundTarget === "string" ? data.soundTarget : doc.id;
        if (data.stageProgress) stagesBySound[key] = data.stageProgress;
      }

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
          {
            stagesBySound,
            prevWeekSuccessRate: prevSuccessRate,
            weekSuccessRate: avgSuccessRate,
          },
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
