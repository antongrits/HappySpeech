/**
 * sendDailyReminder — scheduled daily push notification.
 *
 * Runs every day at 17:00 UTC (= 20:00 MSK).
 * For each parent user with notificationsEnabled == true and a valid fcmToken:
 *   - Check if the parent's active child had any sessions today (UTC date).
 *   - If no session today → send FCM push "Ещё не играли сегодня".
 *   - If session exists → skip (positive reinforcement, no nagging).
 *
 * COPPA: only parents receive FCM. Kid profiles are never targeted.
 * Privacy: FCM messages contain no PII beyond the child's first name (stored
 * locally on device); server only uses childId for the session lookup.
 */

import * as logger from "firebase-functions/logger";
import type * as admin from "firebase-admin";
import type { Firestore, Messaging } from "./types";

/** Returns today's date as an ISO string "YYYY-MM-DD" in UTC. */
function todayUTC(): string {
  return new Date().toISOString().slice(0, 10);
}

interface ParentDoc {
  fcmToken?: string;
  activeChildId?: string;
}

/** Checks whether the given child had at least one session today (UTC). */
async function hadSessionToday(
  db: Firestore,
  userId: string,
  childId: string,
): Promise<boolean> {
  const today = todayUTC();
  // Clients write `date` as epoch seconds (timeIntervalSince1970, a number) —
  // see SessionPersistenceCoordinator.sessionPayloadJSON. Comparing against a
  // Date object matched nothing → the reminder fired even after a session.
  const startOfDay = Math.floor(new Date(today + "T00:00:00.000Z").getTime() / 1000);
  const endOfDay = Math.floor(new Date(today + "T23:59:59.999Z").getTime() / 1000);

  const snap = await db
    .collection("users")
    .doc(userId)
    .collection("children")
    .doc(childId)
    .collection("sessions")
    .where("date", ">=", startOfDay)
    .where("date", "<=", endOfDay)
    .limit(1)
    .get();

  return !snap.empty;
}

/**
 * Sends a single FCM push notification to the parent's device.
 * Fails silently (logs error, does not throw) so one bad token
 * does not abort the entire batch.
 *
 * Privacy: child's name is NOT included in notification.title/body —
 * push payloads transit APNs/FCM unencrypted and appear on the lock screen.
 * The app substitutes the name locally on the device using the data payload.
 */
async function sendReminderPush(
  messaging: Messaging,
  fcmToken: string,
): Promise<boolean> {
  const message = {
    token: fcmToken,
    notification: {
      title: "Время для занятия!",
      body: "Сегодня ещё не было занятия. Давайте сделаем урок вместе?",
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
      type: "daily_reminder",
      deepLink: "happyspeech://parent/home",
      sentAt: new Date().toISOString(),
    },
  };

  try {
    await messaging.send(message);
    return true;
  } catch (error: unknown) {
    const err = error as { code?: string; message?: unknown };
    logger.warn("sendDailyReminder: FCM send failed", {
      errorCode: err.code,
      errorMessage: String(err.message),
    });
    return false;
  }
}

/** Main runner — called from index.ts scheduled function. */
export async function runDailyReminder(adminSdk: typeof admin): Promise<void> {
  const db = adminSdk.firestore();
  const messaging = adminSdk.messaging();

  let parentsScanned = 0;
  let remindersSent = 0;
  let sessionFound = 0;
  let noToken = 0;

  let lastDoc: FirebaseFirestore.QueryDocumentSnapshot | null = null;
  const BATCH = 100;

  while (true) {
    let query: FirebaseFirestore.Query = db
      .collection("users")
      .where("role", "==", "parent")
      .where("notificationsEnabled", "==", true)
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
      const fcmToken = parentData.fcmToken;

      if (!fcmToken || typeof fcmToken !== "string") {
        noToken += 1;
        continue;
      }

      // Determine the active child — use activeChildId if set, else first child.
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

      const alreadyPlayed = await hadSessionToday(db, userId, childId);
      if (alreadyPlayed) {
        sessionFound += 1;
        continue;
      }

      const sent = await sendReminderPush(messaging, fcmToken);
      if (sent) remindersSent += 1;
    }
  }

  logger.info("sendDailyReminder complete", {
    parentsScanned,
    remindersSent,
    sessionFound,
    noToken,
  });
}
