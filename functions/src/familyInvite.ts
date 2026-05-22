/**
 * sendFamilyInvite — email-приглашение второго родителя / специалиста.
 *
 * В отличие от существующего `createFamilyInviteToken`
 * (Universal Link для ShareSheet), эта функция отправляет приглашение
 * по email. Поскольку deploy off и nodemailer не настроен,
 * фактическая отправка email — заглушка (logger.info), но invite
 * document пишется в Firestore полностью, чтобы клиент мог его
 * показать и при необходимости получить URL.
 *
 * Контракт:
 *   IN:  { inviteeEmail, role: "parent" | "specialist", childIds[] }
 *   OUT: { inviteId, inviteUrl, expiresAt, emailDispatched }
 *
 * Document path: /familyInvites/{inviteId}
 * URL form:      https://happyspeech.page.link/invite?token={inviteId}
 */

import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import { randomBytes } from "node:crypto";

import { REGION } from "./constants";
import type {
  FamilyInviteRoleExtended,
  SendFamilyInviteRequest,
  SendFamilyInviteResponse,
} from "./types";

const INVITE_TTL_HOURS = 72;
const MAX_CHILD_IDS = 10;
const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

// ────────────────────────────────────────────────────────────────────────────
// Pure helpers (exported for tests)
// ────────────────────────────────────────────────────────────────────────────

export function isValidEmail(value: unknown): value is string {
  return typeof value === "string" &&
    value.length > 0 &&
    value.length <= 254 &&
    EMAIL_REGEX.test(value);
}

export function isAllowedRole(value: unknown): value is FamilyInviteRoleExtended {
  return value === "parent" || value === "specialist";
}

export function buildInviteUrl(inviteId: string): string {
  return `https://happyspeech.page.link/invite?token=${inviteId}`;
}

export function generateInviteId(): string {
  return randomBytes(16).toString("hex");
}

// ────────────────────────────────────────────────────────────────────────────
// Email dispatch — stub (deploy off, no nodemailer configured)
// ────────────────────────────────────────────────────────────────────────────

interface InviteEmailContext {
  inviteId: string;
  inviteUrl: string;
  inviteeEmail: string;
  role: FamilyInviteRoleExtended;
  inviterUid: string;
  expiresAt: string;
}

export async function dispatchInviteEmail(
  ctx: InviteEmailContext,
): Promise<boolean> {
  // Production-ready stub. Когда email-provider будет подключён
  // (SendGrid / Mailgun / nodemailer+SMTP), реализация подключается здесь
  // через environment variable HS_MAIL_PROVIDER.
  logger.info("sendFamilyInvite [EMAIL STUB] would send", {
    to: "[REDACTED]",
    role: ctx.role,
    inviteId: ctx.inviteId,
    expiresAt: ctx.expiresAt,
  });
  return false;
}

// ────────────────────────────────────────────────────────────────────────────
// Cloud Function
// ────────────────────────────────────────────────────────────────────────────

export const sendFamilyInvite = onCall<
  SendFamilyInviteRequest,
  Promise<SendFamilyInviteResponse>
>(
  { enforceAppCheck: true, cors: true, region: REGION, timeoutSeconds: 30 },
  async (request) => {
    if (!request.auth || !request.auth.uid) {
      throw new HttpsError("unauthenticated", "Sign in required");
    }
    const inviterUid = request.auth.uid;

    const { inviteeEmail, role, childIds } = request.data || {};

    if (!isValidEmail(inviteeEmail)) {
      throw new HttpsError("invalid-argument", "inviteeEmail invalid");
    }
    if (!isAllowedRole(role)) {
      throw new HttpsError(
        "invalid-argument",
        "role must be 'parent' or 'specialist'",
      );
    }
    if (!Array.isArray(childIds) || childIds.length === 0) {
      throw new HttpsError(
        "invalid-argument",
        "childIds must be non-empty array",
      );
    }
    if (childIds.length > MAX_CHILD_IDS) {
      throw new HttpsError(
        "invalid-argument",
        `childIds limit: ${MAX_CHILD_IDS}`,
      );
    }
    const safeChildIds: string[] = [];
    for (const cid of childIds) {
      if (typeof cid !== "string" || cid.length === 0 || cid.length > 128) {
        throw new HttpsError(
          "invalid-argument",
          "childIds entries must be non-empty strings ≤128 chars",
        );
      }
      safeChildIds.push(cid);
    }

    // Authorise: каждый childId должен принадлежать вызывающему родителю.
    const db = admin.firestore();
    for (const childId of safeChildIds) {
      const childDoc = await db
        .collection("users").doc(inviterUid)
        .collection("children").doc(childId)
        .get();
      if (!childDoc.exists) {
        throw new HttpsError(
          "permission-denied",
          "Caller does not own one of the children",
        );
      }
    }

    const inviteId = generateInviteId();
    const expiresAtMs = Date.now() + INVITE_TTL_HOURS * 3600 * 1000;
    const expiresAtIso = new Date(expiresAtMs).toISOString();
    const inviteUrl = buildInviteUrl(inviteId);

    const inviteData = {
      inviteId,
      inviterUid,
      inviteeEmail,
      role,
      childIds: safeChildIds,
      status: "pending" as const,
      inviteUrl,
      expiresAt: admin.firestore.Timestamp.fromMillis(expiresAtMs),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      consumedBy: null,
      consumedAt: null,
    };

    try {
      await db.collection("familyInvites").doc(inviteId).set(inviteData);
    } catch (error) {
      logger.error("sendFamilyInvite Firestore write failed", {
        error: String(error),
      });
      throw new HttpsError("internal", "Failed to persist invite");
    }

    const emailDispatched = await dispatchInviteEmail({
      inviteId,
      inviteUrl,
      inviteeEmail,
      role,
      inviterUid,
      expiresAt: expiresAtIso,
    });

    logger.info("sendFamilyInvite issued", {
      inviterUid: "[REDACTED]",
      role,
      childCount: safeChildIds.length,
      inviteId,
      emailDispatched,
    });

    return {
      inviteId,
      inviteUrl,
      expiresAt: expiresAtIso,
      emailDispatched,
    };
  },
);
