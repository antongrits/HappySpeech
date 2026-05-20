import * as admin from "firebase-admin";

import { STAGE_PASS_THRESHOLD } from "./constants";
import type {
  BuiltReport,
  DailySeriesEntry,
  Firestore,
  QueryDocumentSnapshot,
  ReportPeriod,
  SoundBreakdownEntry,
} from "./types";

interface SessionDataWithDate {
  date?: admin.firestore.Timestamp | { toDate(): Date };
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

/** Map period string to a Firestore Timestamp cutoff. */
export function periodToCutoff(
  period: ReportPeriod,
): admin.firestore.Timestamp | null {
  if (period === "week") {
    return admin.firestore.Timestamp.fromDate(daysAgo(7));
  }
  if (period === "month") {
    return admin.firestore.Timestamp.fromDate(daysAgo(30));
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
    const rawDate = data.date;
    const ts: Date | null = rawDate && typeof (rawDate as { toDate?: () => Date }).toDate === "function" ?
      (rawDate as { toDate: () => Date }).toDate() :
      null;
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

/** Produce rule-based recommendations (no external LLM). */
export function buildRecommendations(
  soundBreakdown: ReadonlyArray<SoundBreakdownEntry>,
): string[] {
  const recs: string[] = [];
  if (soundBreakdown.length === 0) {
    recs.push("Начните с короткой игровой сессии 10 минут, чтобы определить опорный звук.");
    return recs;
  }

  const sortedAsc = [...soundBreakdown].sort((a, b) => a.accuracy - b.accuracy);
  const weakest = sortedAsc[0];
  const sortedDesc = [...soundBreakdown].sort((a, b) => b.accuracy - a.accuracy);
  const strongest = sortedDesc[0];

  if (weakest && weakest.accuracy < STAGE_PASS_THRESHOLD) {
    recs.push(
      `Звук "${weakest.soundTarget}" пока сложен (точность ${(weakest.accuracy * 100).toFixed(0)}%). ` +
      "Сделайте короткую артикуляционную разминку и повторите слоги перед играми.",
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

  const snap = await query.get();
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
    recommendations: buildRecommendations(soundBreakdown),
  };
}
