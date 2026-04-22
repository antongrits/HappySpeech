'use strict';

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

const BANNED_TOKENS = []; // keep empty by default; production list comes from config

function hasBannedContent(text) {
  if (typeof text !== 'string' || text.length === 0) return false;
  const lower = text.toLowerCase();
  return BANNED_TOKENS.some((t) => lower.includes(t));
}

async function moderateUserDocument(admin, ctx) {
  const { userId, childId, sessionId, attemptId, after } = ctx;
  const db = admin.firestore();

  const transcript = after && typeof after.asrTranscript === 'string'
    ? after.asrTranscript
    : '';

  const flagged = hasBannedContent(transcript);

  // Store a tiny audit record; we do not mutate the attempt doc to avoid
  // infinite triggers.
  await db.collection('audits').add({
    kind: 'moderation',
    userId,
    childId,
    sessionId,
    attemptId,
    flagged,
    transcriptLen: transcript.length,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { flagged };
}

module.exports = {
  moderateUserDocument,
  hasBannedContent,
};
