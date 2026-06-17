/**
 * sendWeeklySummary — scheduled weekly push notification.
 *
 * Runs every Sunday at 19:00 UTC (= 22:00 MSK).
 * For each parent user with weeklyParentSummaryEnabled == true and a valid fcmToken:
 *   - Compute stats for the past 7 days (sessions count, total minutes).
 *   - Send FCM push with a summary and deep link to ParentHome.
 *
 * COPPA: only parents receive FCM. Kid profiles are never targeted.
 */

import * as logger from "firebase-functions/logger";
import type * as admin from "firebase-admin";
import type { Firestore, Messaging } from "./types";

interface WeekWindow {
  weekStart: Date;
  weekEnd: Date;
}

/** Returns ISO date range for the 7-day window ending today. */
function weekWindow(): WeekWindow {
  const now = new Date();
  const weekEnd = new Date(now);
  weekEnd.setUTCHours(23, 59, 59, 999);

  const weekStart = new Date(now);
  weekStart.setUTCDate(weekStart.getUTCDate() - 6);
  weekStart.setUTCHours(0, 0, 0, 0);

  return { weekStart, weekEnd };
}

interface ParentDoc {
  fcmToken?: string;
  activeChildId?: string;
  weeklyParentSummaryEnabled?: boolean;
}

interface SessionDoc {
  durationSeconds?: number;
}

interface WeekStats {
  sessionCount: number;
  totalMinutes: number;
}

/** Aggregates session stats for a single child over the given week window. */
async function getWeekStats(
  db: Firestore,
  userId: string,
  childId: string,
  weekStart: Date,
  weekEnd: Date,
): Promise<WeekStats> {
  // Clients write `date` as epoch seconds (timeIntervalSince1970, a number) —
  // see SessionPersistenceCoordinator.sessionPayloadJSON. Comparing against Date
  // objects matched nothing → every weekly summary reported "0 занятий".
  const weekStartEpoch = Math.floor(weekStart.getTime() / 1000);
  const weekEndEpoch = Math.floor(weekEnd.getTime() / 1000);

  const snap = await db
    .collection("users")
    .doc(userId)
    .collection("children")
    .doc(childId)
    .collection("sessions")
    .where("date", ">=", weekStartEpoch)
    .where("date", "<=", weekEndEpoch)
    .get();

  if (snap.empty) return { sessionCount: 0, totalMinutes: 0 };

  let totalSeconds = 0;
  snap.docs.forEach((doc) => {
    const data = (doc.data() as SessionDoc | undefined) ?? {};
    totalSeconds += typeof data.durationSeconds === "number" ? data.durationSeconds : 0;
  });

  return {
    sessionCount: snap.size,
    totalMinutes: Math.round(totalSeconds / 60),
  };
}

/**
 * Formats a human-readable summary string in Russian.
 * Child name is intentionally excluded: push payloads transit APNs/FCM
 * unencrypted and appear on the lock screen — child PII must not leave the device.
 * The app can substitute the name locally when handling the notification.
 */
function formatSummaryBody(
  sessionCount: number,
  totalMinutes: number,
): string {
  if (sessionCount === 0) {
    return "На этой неделе занятий ещё не было. Самое время начать!";
  }

  const sessionsText = sessionCount === 1 ?
    "1 занятие" :
    sessionCount < 5 ?
      `${sessionCount} занятия` :
      `${sessionCount} занятий`;

  const minutesText = totalMinutes < 1 ?
    "меньше минуты" :
    totalMinutes === 1 ?
      "1 минуту" :
      `${totalMinutes} минут`;

  return `Завершено ${sessionsText} (${minutesText}) за эту неделю. Отличный результат!`;
}

/**
 * Sends a weekly summary FCM push notification.
 * Fails silently — one bad token does not abort the batch.
 *
 * Privacy: child's name is NOT included in notification.title/body —
 * push payloads transit APNs/FCM unencrypted and appear on the lock screen.
 */
async function sendSummaryPush(
  messaging: Messaging,
  fcmToken: string,
  sessionCount: number,
  totalMinutes: number,
): Promise<boolean> {
  const body = formatSummaryBody(sessionCount, totalMinutes);

  const message = {
    token: fcmToken,
    notification: {
      title: "Итоги недели",
      body,
    },
    apns: {
      payload: {
        aps: {
          sound: "default",
          badge: 1,
        },
      },
      headers: {
        "apns-priority": "5",
      },
    },
    data: {
      type: "weekly_summary",
      deepLink: "happyspeech://parent/home",
      sessionCount: String(sessionCount),
      totalMinutes: String(totalMinutes),
      sentAt: new Date().toISOString(),
    },
  };

  try {
    await messaging.send(message);
    return true;
  } catch (error: unknown) {
    const err = error as { code?: string; message?: unknown };
    logger.warn("sendWeeklySummary: FCM send failed", {
      errorCode: err.code,
      errorMessage: String(err.message),
    });
    return false;
  }
}

/** Main runner — called from index.ts scheduled function. */
export async function runWeeklySummary(adminSdk: typeof admin): Promise<void> {
  const db = adminSdk.firestore();
  const messaging = adminSdk.messaging();
  const { weekStart, weekEnd } = weekWindow();

  let parentsScanned = 0;
  let summariesSent = 0;
  let noToken = 0;
  let disabled = 0;

  let lastDoc: FirebaseFirestore.QueryDocumentSnapshot | null = null;
  const BATCH = 100;

  while (true) {
    let query: FirebaseFirestore.Query = db
      .collection("users")
      .where("role", "==", "parent")
      .limit(BATCH);

    if (lastDoc) {
      query = query.startAfter(lastDoc);
    }

    const snap = await query.get();
    if (snap.empty) break;
    lastDoc = snap.docs[snap.docs.length - 1];

    for (const parentDoc of snap.docs) {
      parentsScanned += 1;
      const userId = parentDoc.id;
      const parentData = (parentDoc.data() as ParentDoc | undefined) ?? {};

      // Respect per-user opt-out for weekly summary.
      if (parentData.weeklyParentSummaryEnabled === false) {
        disabled += 1;
        continue;
      }

      const fcmToken = parentData.fcmToken;
      if (!fcmToken || typeof fcmToken !== "string") {
        noToken += 1;
        continue;
      }

      // Find active child.
      // Child name is intentionally not fetched: push body must not contain PII.
      let childId: string | null = parentData.activeChildId ?? null;

      if (!childId) {
        const childrenSnap = await db
          .collection("users")
          .doc(userId)
          .collection("children")
          .limit(1)
          .get();

        if (childrenSnap.empty) continue;
        childId = childrenSnap.docs[0].id;
      }

      const { sessionCount, totalMinutes } = await getWeekStats(
        db, userId, childId, weekStart, weekEnd,
      );

      const sent = await sendSummaryPush(
        messaging, fcmToken, sessionCount, totalMinutes,
      );
      if (sent) summariesSent += 1;
    }
  }

  logger.info("sendWeeklySummary complete", {
    parentsScanned,
    summariesSent,
    noToken,
    disabled,
    weekStart: weekStart.toISOString(),
    weekEnd: weekEnd.toISOString(),
  });
}
