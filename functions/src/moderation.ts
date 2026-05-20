/**
 * Placeholder for user-generated content moderation.
 *
 * Current behaviour:
 *   - Writes a lightweight audit record to /audits/ for every attempt write.
 *   - Flags attempts where asrTranscript contains suspicious tokens (stub list).
 *
 * Future: integrate external moderation API (Perspective, Sightengine audio,
 * or local ML filter). Keep this module pure-logic so it is testable.
 */

import type * as admin from "firebase-admin";
import type { ModerationContext, ModerationResult } from "./types";

const BANNED_TOKENS: readonly string[] = []; // production list comes from config

export function hasBannedContent(text: unknown): boolean {
  if (typeof text !== "string" || text.length === 0) return false;
  const lower = text.toLowerCase();
  return BANNED_TOKENS.some((t) => lower.includes(t));
}

export async function moderateUserDocument(
  adminSdk: typeof admin,
  ctx: ModerationContext,
): Promise<ModerationResult> {
  const { userId, childId, sessionId, attemptId, after } = ctx;
  const db = adminSdk.firestore();

  const transcript = after && typeof after.asrTranscript === "string" ?
    after.asrTranscript :
    "";

  const flagged = hasBannedContent(transcript);

  // Store a tiny audit record; we do not mutate the attempt doc to avoid
  // infinite triggers.
  await db.collection("audits").add({
    kind: "moderation",
    userId,
    childId,
    sessionId,
    attemptId,
    flagged,
    transcriptLen: transcript.length,
    createdAt: adminSdk.firestore.FieldValue.serverTimestamp(),
  });

  return { flagged };
}
