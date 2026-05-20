import type { Firestore, PerChildStats, UserStats } from "./types";

interface ChildDocData {
  name?: string;
  age?: number | null;
  progressSummary?: Record<string, number>;
}

interface SessionDocData {
  date?: { toDate?: () => Date } | string;
  durationSeconds?: number;
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
      .map((d) => (d.data() as SessionDocData).date)
      .filter((v): v is NonNullable<SessionDocData["date"]> => Boolean(v))
      .map((ts) => (typeof ts === "object" && typeof ts.toDate === "function" ?
        ts.toDate() :
        new Date(ts as unknown as string)))
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
