import * as admin from "firebase-admin";

import { STAGE_PASS_THRESHOLD, STAGES } from "./constants";
import type {
  BuiltReport,
  DailySeriesEntry,
  Firestore,
  QueryDocumentSnapshot,
  ReportPeriod,
  SoundBreakdownEntry,
  SoundStageRow,
  StageCell,
} from "./types";

interface SessionDataWithDate {
  // Clients write `date` as epoch seconds (timeIntervalSince1970, a number) —
  // see SessionPersistenceCoordinator.sessionPayloadJSON / SyncSnapshots.
  // Legacy docs may still carry a Firestore Timestamp; toEpochSeconds() copes
  // with both so historical data keeps charting.
  date?: number | admin.firestore.Timestamp | { toDate(): Date };
  targetSound?: string;
  durationSeconds?: number;
  totalAttempts?: number;
  correctAttempts?: number;
}

type DocLike = QueryDocumentSnapshot | { data: () => SessionDataWithDate };

/** Compute date N days ago (00:00:00 local). */
function daysAgo(days: number): Date {
  const d = new Date();
  d.setDate(d.getDate() - days);
  d.setHours(0, 0, 0, 0);
  return d;
}

/**
 * Map period string to a numeric epoch-seconds cutoff.
 * Clients write `date` as epoch seconds (a number), so the range filter must
 * compare against a number — a Firestore Timestamp would never match.
 */
export function periodToCutoff(period: ReportPeriod): number | null {
  if (period === "week") {
    return Math.floor(daysAgo(7).getTime() / 1000);
  }
  if (period === "month") {
    return Math.floor(daysAgo(30).getTime() / 1000);
  }
  return null;
}

/**
 * Normalises a stored `date` field to a JS Date.
 * Primary path: numeric epoch seconds (current client). Falls back to a
 * Firestore Timestamp / `{ toDate() }` for legacy documents.
 */
function dateValueToJsDate(raw: SessionDataWithDate["date"]): Date | null {
  if (typeof raw === "number" && Number.isFinite(raw)) {
    return new Date(raw * 1000);
  }
  if (raw && typeof (raw as { toDate?: () => Date }).toDate === "function") {
    return (raw as { toDate: () => Date }).toDate();
  }
  return null;
}

/** Bucket sessions by day for charts. */
export function buildDailySeries(sessions: ReadonlyArray<DocLike>): DailySeriesEntry[] {
  interface DailyRow {
    date: string;
    sessions: number;
    minutes: number;
    total: number;
    correct: number;
  }
  const byDay = new Map<string, DailyRow>();

  for (const doc of sessions) {
    const data = doc.data() as SessionDataWithDate;
    const ts = dateValueToJsDate(data.date);
    if (!ts) continue;

    const dayKey = ts.toISOString().slice(0, 10);
    let row = byDay.get(dayKey);
    if (!row) {
      row = { date: dayKey, sessions: 0, minutes: 0, total: 0, correct: 0 };
      byDay.set(dayKey, row);
    }
    row.sessions += 1;
    row.minutes += Math.round((data.durationSeconds || 0) / 60);
    row.total += data.totalAttempts || 0;
    row.correct += data.correctAttempts || 0;
  }

  return Array.from(byDay.values())
    .sort((a, b) => (a.date < b.date ? -1 : 1))
    .map((r) => ({
      date: r.date,
      sessions: r.sessions,
      minutes: r.minutes,
      accuracy: r.total > 0 ? Number((r.correct / r.total).toFixed(3)) : 0,
    }));
}

/** Per-sound summary for charts. */
export function buildSoundBreakdown(
  sessions: ReadonlyArray<DocLike>,
): SoundBreakdownEntry[] {
  interface SoundRow {
    soundTarget: string;
    sessions: number;
    minutes: number;
    total: number;
    correct: number;
  }
  const bySound = new Map<string, SoundRow>();

  for (const doc of sessions) {
    const data = doc.data() as SessionDataWithDate;
    const sound = data.targetSound;
    if (!sound) continue;

    let row = bySound.get(sound);
    if (!row) {
      row = { soundTarget: sound, sessions: 0, minutes: 0, total: 0, correct: 0 };
      bySound.set(sound, row);
    }
    row.sessions += 1;
    row.total += data.totalAttempts || 0;
    row.correct += data.correctAttempts || 0;
    row.minutes += Math.round((data.durationSeconds || 0) / 60);
  }

  return Array.from(bySound.values()).map((r) => ({
    soundTarget: r.soundTarget,
    sessions: r.sessions,
    minutes: r.minutes,
    accuracy: r.total > 0 ? Number((r.correct / r.total).toFixed(3)) : 0,
  }));
}

interface ProgressDocData {
  soundTarget?: string;
  overallRate?: number;
  totalSessions?: number;
  totalMinutes?: number;
  stageProgress?: Record<string, { done?: boolean; rate?: number; attempts?: number }>;
}

type ProgressDocLike = QueryDocumentSnapshot | { id?: string; data: () => ProgressDocData };

/**
 * Строит таблицу «звук × этапы коррекции» из persisted /progress docs.
 * Чистая функция (документы передаются снаружи) — тестируется без сети.
 */
export function buildStageBreakdown(
  progressDocs: ReadonlyArray<ProgressDocLike>,
): SoundStageRow[] {
  const rows: SoundStageRow[] = [];

  for (const doc of progressDocs) {
    const data = doc.data() as ProgressDocData;
    const sound = typeof data.soundTarget === "string" && data.soundTarget.length > 0 ?
      data.soundTarget :
      ((doc as { id?: string }).id ?? "—");

    const sp = data.stageProgress ?? {};
    const stages: StageCell[] = STAGES.map((stage) => {
      const cell = sp[stage] ?? {};
      return {
        stage,
        done: cell.done === true,
        rate: typeof cell.rate === "number" ? Number(cell.rate.toFixed(3)) : 0,
        attempts: typeof cell.attempts === "number" ? cell.attempts : 0,
      };
    });

    // Текущий этап — первый незавершённый с попытками, иначе последний с попытками.
    let currentStage: string | null = null;
    for (const cell of stages) {
      if (cell.attempts > 0) {
        currentStage = cell.stage;
        if (!cell.done) break;
      }
    }

    rows.push({
      soundTarget: sound,
      overallRate: typeof data.overallRate === "number" ?
        Number(data.overallRate.toFixed(3)) :
        0,
      totalSessions: typeof data.totalSessions === "number" ? data.totalSessions : 0,
      totalMinutes: typeof data.totalMinutes === "number" ? data.totalMinutes : 0,
      currentStage,
      stages,
    });
  }

  rows.sort((a, b) => (a.soundTarget < b.soundTarget ? -1 : 1));
  return rows;
}

/** Produce rule-based recommendations (no external LLM). */
export function buildRecommendations(
  soundBreakdown: ReadonlyArray<SoundBreakdownEntry>,
  stageBreakdown: ReadonlyArray<SoundStageRow> = [],
): string[] {
  const recs: string[] = [];
  if (soundBreakdown.length === 0) {
    recs.push("Начните с короткой игровой сессии 10 минут, чтобы определить опорный звук.");
    return recs;
  }

  const stageBySound = new Map<string, SoundStageRow>();
  for (const row of stageBreakdown) stageBySound.set(row.soundTarget, row);

  const sortedAsc = [...soundBreakdown].sort((a, b) => a.accuracy - b.accuracy);
  const weakest = sortedAsc[0];
  const sortedDesc = [...soundBreakdown].sort((a, b) => b.accuracy - a.accuracy);
  const strongest = sortedDesc[0];

  if (weakest && weakest.accuracy < STAGE_PASS_THRESHOLD) {
    const stage = stageBySound.get(weakest.soundTarget)?.currentStage;
    const stageHint = stage ?
      ` Сейчас ребёнок на этапе «${stage}» — задержитесь здесь, не усложняйте материал.` :
      " Сделайте короткую артикуляционную разминку и повторите слоги перед играми.";
    recs.push(
      `Звук "${weakest.soundTarget}" пока сложен (точность ${(weakest.accuracy * 100).toFixed(0)}%).` +
      stageHint,
    );
  }

  if (strongest && strongest.accuracy >= STAGE_PASS_THRESHOLD) {
    recs.push(
      `Звук "${strongest.soundTarget}" звучит уверенно — переходите к следующему этапу ` +
      "(слова → фразы → рассказы).",
    );
  }

  const totalMinutes = soundBreakdown.reduce((a, b) => a + b.minutes, 0);
  if (totalMinutes < 20) {
    recs.push("Советуем 10–15 минут практики в день, желательно в одно и то же время.");
  }

  return recs;
}

/** Build a structured parent/specialist report. */
export async function buildReport(
  db: Firestore,
  userId: string,
  childId: string,
  period: ReportPeriod,
): Promise<BuiltReport> {
  const sessionsRef = db
    .collection("users").doc(userId)
    .collection("children").doc(childId)
    .collection("sessions");

  const cutoff = periodToCutoff(period);
  const query: FirebaseFirestore.Query = cutoff ?
    sessionsRef.where("date", ">=", cutoff) :
    sessionsRef;

  const progressRef = db
    .collection("users").doc(userId)
    .collection("children").doc(childId)
    .collection("progress");

  const [snap, progressSnap] = await Promise.all([query.get(), progressRef.get()]);
  const sessions = snap.docs;

  const totalSessions = sessions.length;
  const totalMinutes = sessions.reduce(
    (acc, d) => acc + Math.round(((d.data() as SessionDataWithDate).durationSeconds || 0) / 60),
    0,
  );
  const totalAttempts = sessions.reduce(
    (acc, d) => acc + ((d.data() as SessionDataWithDate).totalAttempts || 0),
    0,
  );
  const correctAttempts = sessions.reduce(
    (acc, d) => acc + ((d.data() as SessionDataWithDate).correctAttempts || 0),
    0,
  );
  const overallAccuracy = totalAttempts > 0 ? correctAttempts / totalAttempts : 0;

  const dailySeries = buildDailySeries(sessions);
  const soundBreakdown = buildSoundBreakdown(sessions);
  const stageBreakdown = buildStageBreakdown(progressSnap.docs);

  return {
    summary: {
      period,
      totalSessions,
      totalMinutes,
      totalAttempts,
      correctAttempts,
      overallAccuracy: Number(overallAccuracy.toFixed(3)),
      generatedAt: new Date().toISOString(),
    },
    chartsData: {
      daily: dailySeries,
      perSound: soundBreakdown,
    },
    stageBreakdown,
    recommendations: buildRecommendations(soundBreakdown, stageBreakdown),
  };
}
