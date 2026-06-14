/**
 * sendFamilyInvite — email-приглашение второго родителя / специалиста.
 *
 * В отличие от `createFamilyInviteToken` (выдаёт токен для ShareSheet),
 * эта функция дополнительно пытается отправить приглашение по email.
 *
 * Единый контракт с `createFamilyInviteToken`:
 *   • Пишет в ту же коллекцию `family_invites` с тем же набором полей,
 *     поэтому приглашённый пользователь применяет инвайт тем же путём
 *     (`FamilyInviteService.redeemInvite`) и под теми же Firestore-правилами.
 *   • Ссылка — Universal Link (`https://happyspeech.app/invite?...`),
 *     которую разбирает `UniversalLinkHandler`. Никаких Dynamic Links
 *     (`page.link` закрыт Google 2025-08-25).
 *
 * Email-доставка:
 *   • Реальная отправка через HTTPS email-API, если заданы env-переменные
 *     `HS_MAIL_API_URL`, `HS_MAIL_API_KEY`, `HS_MAIL_FROM`.
 *   • Если провайдер не сконфигурирован — шаг email пропускается
 *     (`emailDispatched: false`); клиент всё равно получает `inviteUrl`
 *     для шаринга внутри приложения.
 *
 * Контракт:
 *   IN:  { inviteeEmail, role: "parent" | "specialist", childIds[] }
 *   OUT: { inviteId, inviteUrl, expiresAt, emailDispatched }
 *
 * Document path: /family_invites/{inviteId}
 */

import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import { randomBytes, randomInt } from "node:crypto";

import { REGION } from "./constants";
import type {
  FamilyInviteRole,
  FamilyInviteRoleExtended,
  SendFamilyInviteRequest,
  SendFamilyInviteResponse,
} from "./types";

const INVITE_TTL_HOURS = 72;
const MAX_CHILD_IDS = 10;
const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

/** Universal-Link домен/путь (см. Resources/apple-app-site-association.json). */
const UNIVERSAL_LINK_BASE = "https://happyspeech.app/invite";

/** Алфавит short-code без неоднозначных символов (как в createFamilyInviteToken). */
const SHORT_CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
const SHORT_CODE_LENGTH = 6;

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

/**
 * Маппинг расширенной роли приглашения в каноническое пространство
 * `ParentRole` (которое понимает `FamilyInviteService` при применении):
 *   parent → secondary (второй родитель / опекун, доступ к прогрессу),
 *   specialist → observer (наблюдатель только-чтение).
 * Исходная роль сохраняется отдельным полем `invitedRole` для UI/email.
 */
export function toRedeemableRole(role: FamilyInviteRoleExtended): FamilyInviteRole {
  return role === "parent" ? "secondary" : "observer";
}

/** Universal Link того же вида, что возвращает createFamilyInviteToken. */
export function buildInviteUrl(token: string, shortCode: string): string {
  return `${UNIVERSAL_LINK_BASE}?token=${token}&code=${shortCode}`;
}

export function generateInviteId(): string {
  return randomBytes(16).toString("hex");
}

export function generateShortCode(): string {
  let code = "";
  for (let i = 0; i < SHORT_CODE_LENGTH; i++) {
    code += SHORT_CODE_ALPHABET[randomInt(SHORT_CODE_ALPHABET.length)];
  }
  return code;
}

// ────────────────────────────────────────────────────────────────────────────
// Email dispatch — real if a provider is configured, otherwise skipped.
// ────────────────────────────────────────────────────────────────────────────

interface InviteEmailContext {
  inviteUrl: string;
  inviteeEmail: string;
  role: FamilyInviteRoleExtended;
  expiresAt: string;
}

/**
 * Отправляет приглашение через HTTPS email-API, если он сконфигурирован
 * через env (`HS_MAIL_API_URL`, `HS_MAIL_API_KEY`, `HS_MAIL_FROM`).
 * Возвращает true только при успешной доставке. Никогда не бросает и
 * не логирует адрес/ссылку (PII-free).
 */
export async function dispatchInviteEmail(
  ctx: InviteEmailContext,
): Promise<boolean> {
  const apiUrl = process.env.HS_MAIL_API_URL;
  const apiKey = process.env.HS_MAIL_API_KEY;
  const from = process.env.HS_MAIL_FROM;

  if (!apiUrl || !apiKey || !from) {
    // Провайдер не настроен — пропускаем email; клиент шарит inviteUrl сам.
    logger.info("sendFamilyInvite: email provider not configured, skipping send");
    return false;
  }

  const roleHuman = ctx.role === "parent" ? "второго родителя" : "специалиста";
  const subject = "Приглашение в HappySpeech";
  const text =
    `Вас пригласили в HappySpeech как ${roleHuman}.\n\n` +
    `Откройте ссылку на устройстве с установленным приложением:\n${ctx.inviteUrl}\n\n` +
    `Приглашение действительно до ${ctx.expiresAt}.`;

  try {
    const res = await fetch(apiUrl, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from,
        to: ctx.inviteeEmail,
        subject,
        text,
      }),
    });
    if (!res.ok) {
      logger.warn("sendFamilyInvite: email API non-OK", { status: res.status });
      return false;
    }
    return true;
  } catch (error) {
    logger.warn("sendFamilyInvite: email dispatch failed", {
      error: String(error),
    });
    return false;
  }
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

    const token = generateInviteId();
    const shortCode = generateShortCode();
    const expiresAtMs = Date.now() + INVITE_TTL_HOURS * 3600 * 1000;
    const expiresAtIso = new Date(expiresAtMs).toISOString();
    const inviteUrl = buildInviteUrl(token, shortCode);

    // Единый со createFamilyInviteToken формат документа в /family_invites,
    // расширенный полями email-приглашения. parentId / consumed / expiresAt
    // (Timestamp) — то, что читают rules и FamilyInviteService при применении.
    const inviteData = {
      parentId: inviterUid,
      role: toRedeemableRole(role),
      invitedRole: role,
      token,
      shortCode,
      inviteeEmail,
      childIds: safeChildIds,
      inviteUrl,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: admin.firestore.Timestamp.fromMillis(expiresAtMs),
      consumed: false,
      consumedBy: null,
      consumedAt: null,
    };

    try {
      await db.collection("family_invites").doc(token).set(inviteData);
    } catch (error) {
      logger.error("sendFamilyInvite Firestore write failed", {
        error: String(error),
      });
      throw new HttpsError("internal", "Failed to persist invite");
    }

    const emailDispatched = await dispatchInviteEmail({
      inviteUrl,
      inviteeEmail,
      role,
      expiresAt: expiresAtIso,
    });

    logger.info("sendFamilyInvite issued", {
      inviterUid: "[REDACTED]",
      role,
      childCount: safeChildIds.length,
      shortCode,
      emailDispatched,
    });

    return {
      inviteId: token,
      inviteUrl,
      expiresAt: expiresAtIso,
      emailDispatched,
    };
  },
);
