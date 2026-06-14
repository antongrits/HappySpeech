import type { Firestore, PerChildStats, UserStats } from "./types";

interface ChildDocData {
  name?: string;
  age?: number | null;
  progressSummary?: Record<string, number>;
}

interface SessionDocData {
  // Clients write `date` as epoch seconds (timeIntervalSince1970, a number).
  // Legacy docs may carry a Firestore Timestamp or ISO string.
  date?: number | { toDate?: () => Date } | string;
  durationSeconds?: number;
}

/** Normalise a stored `date` value (epoch seconds | Timestamp | ISO) to a Date. */
function sessionDateToJsDate(raw: SessionDocData["date"]): Date | null {
  if (typeof raw === "number" && Number.isFinite(raw)) {
    return new Date(raw * 1000);
  }
  if (typeof raw === "object" && raw && typeof raw.toDate === "function") {
    return raw.toDate();
  }
  if (typeof raw === "string" && raw.length > 0) {
    const d = new Date(raw);
    return Number.isNaN(d.getTime()) ? null : d;
  }
  return null;
}

/** Aggregate statistics across all children of a parent user. */
export async function aggregateUserStats(
  db: Firestore,
  userId: string,
): Promise<UserStats> {
  const childrenRef = db.collection("users").doc(userId).collection("children");
  const childrenSnap = await childrenRef.get();

  const perChild: PerChildStats[] = [];
  let totalSessions = 0;
  let totalMinutes = 0;
  let lastActiveAt: Date | null = null;

  for (const childDoc of childrenSnap.docs) {
    const childId = childDoc.id;
    const childData = (childDoc.data() as ChildDocData | undefined) ?? {};

    const sessionsSnap = await childrenRef.doc(childId).collection("sessions").get();
    const sessions = sessionsSnap.size;
    const minutes = sessionsSnap.docs.reduce(
      (acc, d) => acc + Math.round(((d.data() as SessionDocData).durationSeconds || 0) / 60),
      0,
    );

    const latest = sessionsSnap.docs
      .map((d) => sessionDateToJsDate((d.data() as SessionDocData).date))
      .filter((v): v is Date => v !== null)
      .sort((a, b) => b.getTime() - a.getTime())[0] ?? null;

    if (latest && (!lastActiveAt || latest > lastActiveAt)) {
      lastActiveAt = latest;
    }

    totalSessions += sessions;
    totalMinutes += minutes;

    perChild.push({
      childId,
      name: childData.name ?? "",
      age: childData.age ?? null,
      totalSessions: sessions,
      totalMinutes: minutes,
      lastActiveAt: latest ? latest.toISOString() : null,
      progressSummary: childData.progressSummary ?? {},
    });
  }

  return {
    userId,
    childrenCount: childrenSnap.size,
    totalSessions,
    totalMinutes,
    lastActiveAt: lastActiveAt ? lastActiveAt.toISOString() : null,
    perChild,
  };
}
