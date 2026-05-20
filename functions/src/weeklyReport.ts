/**
 * Scheduled weekly report generator.
 *
 * For each parent user (users/{uid} where role == 'parent'), for each child:
 *   1) Build a "week" report via buildReport().
 *   2) Persist under /users/{uid}/children/{cid}/weekly_reports/{weekStartDate}.
 *   3) If parent has an FCM token on users/{uid}.fcmToken — attempt a push.
 *      (Expected to fail silently on iOS without APNs key. We still record
 *       the attempt in the report doc for telemetry.)
 *
 * Runs inside Cloud Function sendWeeklyReport (Sundays 10:00 MSK).
 */

import * as logger from "firebase-functions/logger";
import type * as admin from "firebase-admin";
import { buildReport } from "./reports";

interface WeeklyReportResult {
  parentsProcessed: number;
  childrenProcessed: number;
  pushAttempts: number;
  pushSuccess: number;
  weekStart: string;
}

export function mondayOfCurrentWeek(now: Date = new Date()): Date {
  const d = new Date(now);
  d.setHours(0, 0, 0, 0);
  const day = d.getDay(); // 0 = Sun, 1 = Mon, ...
  const diff = (day === 0 ? -6 : 1 - day); // back to Monday
  d.setDate(d.getDate() + diff);
  return d;
}

export function isoDate(date: Date): string {
  return date.toISOString().slice(0, 10);
}

interface ParentDoc {
  fcmToken?: string;
}

interface ChildDoc {
  name?: string;
}

export async function runWeeklyReport(
  adminSdk: typeof admin,
): Promise<WeeklyReportResult> {
  const db = adminSdk.firestore();
  const messaging = adminSdk.messaging();

  const weekStart = mondayOfCurrentWeek();
  const weekStartKey = isoDate(weekStart); // e.g. "2026-04-20"

  let parentsProcessed = 0;
  let childrenProcessed = 0;
  let pushAttempts = 0;
  let pushSuccess = 0;

  // Collect parents (users with role == 'parent') in batches of 100.
  let lastDoc: FirebaseFirestore.QueryDocumentSnapshot | null = null;
  const BATCH = 100;

  while (true) {
    let q: FirebaseFirestore.Query = db
      .collection("users")
      .where("role", "==", "parent")
      .limit(BATCH);
    if (lastDoc) q = q.startAfter(lastDoc);
    const snap = await q.get();
    if (snap.empty) break;
    lastDoc = snap.docs[snap.docs.length - 1];

    for (const parentDoc of snap.docs) {
      parentsProcessed += 1;
      const userId = parentDoc.id;
      const parent = (parentDoc.data() as ParentDoc | undefined) ?? {};

      const childrenSnap = await db
        .collection("users").doc(userId)
        .collection("children").get();

      for (const childDoc of childrenSnap.docs) {
        const childId = childDoc.id;
        childrenProcessed += 1;

        let report;
        try {
          report = await buildReport(db, userId, childId, "week");
        } catch (err) {
          logger.error("[weeklyReport] buildReport failed", {
            userId,
            childId,
            error: String(err),
          });
          continue;
        }

        const docRef = db
          .collection("users").doc(userId)
          .collection("children").doc(childId)
          .collection("weekly_reports").doc(weekStartKey);

        const payload: Record<string, unknown> = {
          weekStartDate: weekStartKey,
          childId,
          userId,
          generatedAt: adminSdk.firestore.FieldValue.serverTimestamp(),
          ...report,
          pushAttempted: false,
          pushDelivered: false,
        };

        // Attempt FCM push if parent has a token.
        const fcmToken = typeof parent.fcmToken === "string" && parent.fcmToken.length > 0 ?
          parent.fcmToken :
          null;

        if (fcmToken) {
          pushAttempts += 1;
          payload.pushAttempted = true;
          const childData = (childDoc.data() as ChildDoc | undefined) ?? {};
          try {
            await messaging.send({
              token: fcmToken,
              notification: {
                title: "Недельный отчёт готов",
                body: `Отчёт за неделю для ${childData.name || "ребёнка"} уже в приложении.`,
              },
              data: {
                type: "weekly_report",
                childId,
                weekStartDate: weekStartKey,
              },
              apns: {
                payload: {
                  aps: { "content-available": 1 },
                },
              },
            });
            pushSuccess += 1;
            payload.pushDelivered = true;
          } catch (err: unknown) {
            const code = (err as { code?: string } | null)?.code ?? String(err);
            payload.pushError = code;
          }
        }

        await docRef.set(payload, { merge: true });
      }
    }

    if (snap.size < BATCH) break;
  }

  return {
    parentsProcessed,
    childrenProcessed,
    pushAttempts,
    pushSuccess,
    weekStart: weekStartKey,
  };
}
