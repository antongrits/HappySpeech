/**
 * HappySpeech — Firebase Cloud Functions entry point (TypeScript).
 *
 * Exports:
 *   - calculateProgress             (HTTPS callable)
 *   - generateReport                (HTTPS callable)
 *   - getUserStats                  (HTTPS callable)
 *   - exportUserData                (HTTPS callable, GDPR)
 *   - deleteUserData                (HTTPS callable, GDPR hard delete)
 *   - setAdminClaim                 (HTTPS callable, bootstrap)
 *   - sendWeeklySummaryFCM          (HTTPS callable, on-demand summary push)
 *   - createFamilyInviteToken       (HTTPS callable — Firestore-based invite,
 *                                    replaces Dynamic Links)
 *   - onSessionComplete             (Firestore trigger, v2)
 *   - moderateUserContent           (Firestore trigger, v2, placeholder)
 *   - sendWeeklyReport              (scheduled, every Sunday 10:00 MSK)
 *   - sendDailyReminder             (scheduled, every day 17:00 UTC = 20:00 MSK)
 *   - sendWeeklySummary             (scheduled, every Sunday 19:00 UTC = 22:00 MSK)
 *
 * Region: europe-west3
 * Contract source: api-contracts.md
 */

import * as admin from "firebase-admin";
import { setGlobalOptions } from "firebase-functions/v2";
import {
  onCall,
  HttpsError,
  type CallableRequest,
} from "firebase-functions/v2/https";
import {
  onDocumentCreated,
  onDocumentWritten,
} from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import * as logger from "firebase-functions/logger";
import { randomBytes, randomInt } from "node:crypto";

// Initialize admin SDK once per container.
if (!admin.apps.length) {
  admin.initializeApp();
}

import { REGION } from "./constants";
import { calculateProgressForChild } from "./progress";
import { buildReport } from "./reports";
import { aggregateUserStats } from "./stats";
import { assertAuthorized } from "./auth";
import { runWeeklyReport } from "./weeklyReport";
import { exportUserDataBundle } from "./export";
import { deleteUserDataCascade } from "./delete";
import { moderateUserDocument } from "./moderation";
import { setAdminClaimHandler } from "./admin";
import { runDailyReminder } from "./sendDailyReminder";
import { runWeeklySummary } from "./sendWeeklySummary";
import type {
  CalculateProgressRequest,
  CalculateProgressResult,
  CreateFamilyInviteTokenRequest,
  CreateFamilyInviteTokenResponse,
  DeleteUserDataRequest,
  DeleteUserDataResponse,
  ExportUserDataRequest,
  ExportUserDataResponse,
  FamilyInviteRole,
  GenerateReportRequest,
  GenerateReportResponse,
  GetUserStatsRequest,
  ReportPeriod,
  SendWeeklySummaryFCMRequest,
  SendWeeklySummaryFCMResponse,
  SetAdminClaimRequest,
  SetAdminClaimResponse,
  UserStats,
} from "./types";

setGlobalOptions({ region: REGION, maxInstances: 10 });

// ------------------------------------------------------------------
// HTTPS Callable: calculateProgress
// Input:  { userId: string, childId: string }
// Output: { soundTargets: [...], updatedAt }
// ------------------------------------------------------------------

export const calculateProgress = onCall<CalculateProgressRequest, Promise<CalculateProgressResult>>(
  { enforceAppCheck: true, cors: true },
  async (request) => {
    const { userId, childId } = request.data || {};

    if (typeof userId !== "string" || typeof childId !== "string") {
      throw new HttpsError("invalid-argument", "userId and childId are required strings");
    }

    await assertAuthorized(request.auth, userId, childId);

    try {
      const progress = await calculateProgressForChild(admin.firestore(), userId, childId);
      logger.info("calculateProgress complete", {
        userId,
        childId,
        count: progress.soundTargets.length,
      });
      return progress;
    } catch (error) {
      logger.error("calculateProgress failed", {
        userId,
        childId,
        error: String(error),
      });
      throw new HttpsError("internal", "Failed to compute progress");
    }
  },
);

// ------------------------------------------------------------------
// HTTPS Callable: generateReport
// Input:  { userId: string, childId: string, period: "week" | "month" | "all" }
// Output: { reportId, period, summary, chartsData, recommendations }
// ------------------------------------------------------------------

export const generateReport = onCall<GenerateReportRequest, Promise<GenerateReportResponse>>(
  { enforceAppCheck: true, cors: true },
  async (request) => {
    const { userId, childId, period } = request.data || {};

    if (typeof userId !== "string" || typeof childId !== "string") {
      throw new HttpsError("invalid-argument", "userId and childId are required strings");
    }

    const allowedPeriods: ReadonlyArray<ReportPeriod> = ["week", "month", "all"];
    const periodValue: ReportPeriod = allowedPeriods.includes(period as ReportPeriod) ?
      (period as ReportPeriod) :
      "week";

    await assertAuthorized(request.auth, userId, childId);

    try {
      const report = await buildReport(admin.firestore(), userId, childId, periodValue);

      // Persist report under /users/{userId}/children/{childId}/reports/{reportId}
      const reportsRef = admin
        .firestore()
        .collection("users").doc(userId)
        .collection("children").doc(childId)
        .collection("reports");

      const docRef = await reportsRef.add({
        ...report,
        childId,
        period: periodValue,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      logger.info("generateReport complete", {
        userId, childId, reportId: docRef.id, period: periodValue,
      });

      return {
        reportId: docRef.id,
        period: periodValue,
        ...report,
      };
    } catch (error) {
      logger.error("generateReport failed", { userId, childId, error: String(error) });
      throw new HttpsError("internal", "Failed to generate report");
    }
  },
);

// ------------------------------------------------------------------
// HTTPS Callable: getUserStats
// Input:  { userId: string }
// Output: { childrenCount, totalSessions, totalMinutes, lastActiveAt, perChild }
// ------------------------------------------------------------------

export const getUserStats = onCall<GetUserStatsRequest, Promise<UserStats>>(
  { enforceAppCheck: true, cors: true },
  async (request) => {
    const { userId } = request.data || {};

    if (typeof userId !== "string") {
      throw new HttpsError("invalid-argument", "userId is required");
    }

    if (!request.auth || request.auth.uid !== userId) {
      throw new HttpsError("permission-denied", "Not allowed to read other users stats");
    }

    try {
      const stats = await aggregateUserStats(admin.firestore(), userId);
      return stats;
    } catch (error) {
      logger.error("getUserStats failed", { userId, error: String(error) });
      throw new HttpsError("internal", "Failed to compute stats");
    }
  },
);

// ------------------------------------------------------------------
// Firestore Trigger: onSessionComplete
// Path: /users/{userId}/children/{childId}/sessions/{sessionId}
// Fires on document create — recomputes progress for the affected sound.
// ------------------------------------------------------------------

export const onSessionComplete = onDocumentCreated(
  {
    document: "users/{userId}/children/{childId}/sessions/{sessionId}",
    region: REGION,
  },
  async (event) => {
    const { userId, childId, sessionId } = event.params;
    const snapshot = event.data;

    if (!snapshot) {
      logger.warn("onSessionComplete: no snapshot", { userId, childId, sessionId });
      return;
    }

    const data = (snapshot.data() ?? {}) as { targetSound?: string };
    const targetSound = data.targetSound;

    logger.info("onSessionComplete", { userId, childId, sessionId, targetSound });

    try {
      await calculateProgressForChild(admin.firestore(), userId, childId, {
        onlySound: targetSound,
      });
    } catch (error) {
      // Never throw from triggers — retries are handled by platform per config
      logger.error("onSessionComplete calculateProgress error", {
        userId, childId, sessionId, error: String(error),
      });
    }
  },
);

// ------------------------------------------------------------------
// Scheduled: sendWeeklyReport
// Every Sunday 10:00 Europe/Moscow (MSK, UTC+3).
// ------------------------------------------------------------------

export const sendWeeklyReport = onSchedule(
  {
    schedule: "0 10 * * 0", // Sundays at 10:00
    timeZone: "Europe/Moscow",
    region: REGION,
    retryCount: 3,
  },
  async () => {
    try {
      const result = await runWeeklyReport(admin);
      logger.info("sendWeeklyReport finished", result);
    } catch (error) {
      logger.error("sendWeeklyReport failed", { error: String(error) });
      throw error; // allow retry
    }
  },
);

// ------------------------------------------------------------------
// HTTPS Callable: exportUserData (GDPR export)
// ------------------------------------------------------------------

export const exportUserData = onCall<ExportUserDataRequest, Promise<ExportUserDataResponse>>(
  { enforceAppCheck: true, cors: true, timeoutSeconds: 540, memory: "512MiB" },
  async (request) => {
    const { userId } = request.data || {};

    if (typeof userId !== "string" || userId.length === 0) {
      throw new HttpsError("invalid-argument", "userId is required");
    }

    if (!request.auth || request.auth.uid !== userId) {
      // admin may export for any user
      const callerUid = request.auth?.uid;
      if (!callerUid) {
        throw new HttpsError("unauthenticated", "Sign in required");
      }
      const callerDoc = await admin.firestore().collection("users").doc(callerUid).get();
      const callerData = callerDoc.data() as { role?: string } | undefined;
      const isAdminCaller = (request.auth?.token?.admin === true) ||
        (callerDoc.exists && callerData?.role === "admin");
      if (!isAdminCaller) {
        throw new HttpsError("permission-denied", "Not allowed to export other users");
      }
    }

    try {
      const result = await exportUserDataBundle(admin, userId);
      logger.info("exportUserData complete", { userId, bytes: result.bytes });
      return result;
    } catch (error) {
      logger.error("exportUserData failed", { userId, error: String(error) });
      throw new HttpsError("internal", "Failed to export user data");
    }
  },
);

// ------------------------------------------------------------------
// HTTPS Callable: deleteUserData (GDPR hard-delete)
// ------------------------------------------------------------------

export const deleteUserData = onCall<DeleteUserDataRequest, Promise<DeleteUserDataResponse>>(
  { enforceAppCheck: true, cors: true, timeoutSeconds: 540, memory: "512MiB" },
  async (request) => {
    const { userId, confirm } = request.data || {};

    if (typeof userId !== "string" || userId.length === 0) {
      throw new HttpsError("invalid-argument", "userId is required");
    }
    if (confirm !== "DELETE") {
      throw new HttpsError("failed-precondition", 'confirm must equal "DELETE"');
    }

    if (!request.auth || request.auth.uid !== userId) {
      const callerUid = request.auth?.uid;
      if (!callerUid) {
        throw new HttpsError("unauthenticated", "Sign in required");
      }
      const callerDoc = await admin.firestore().collection("users").doc(callerUid).get();
      const callerData = callerDoc.data() as { role?: string } | undefined;
      const isAdminCaller = (request.auth?.token?.admin === true) ||
        (callerDoc.exists && callerData?.role === "admin");
      if (!isAdminCaller) {
        throw new HttpsError("permission-denied", "Not allowed to delete other users");
      }
    }

    try {
      const result = await deleteUserDataCascade(admin, userId);
      logger.info("deleteUserData complete", { userId, ...result });
      return result;
    } catch (error) {
      logger.error("deleteUserData failed", { userId, error: String(error) });
      throw new HttpsError("internal", "Failed to delete user data");
    }
  },
);

// ------------------------------------------------------------------
// Firestore trigger: moderateUserContent
// ------------------------------------------------------------------

export const moderateUserContent = onDocumentWritten(
  {
    document: "users/{userId}/children/{childId}/sessions/{sessionId}/attempts/{attemptId}",
    region: REGION,
  },
  async (event) => {
    const { userId, childId, sessionId, attemptId } = event.params;
    try {
      await moderateUserDocument(admin, {
        userId,
        childId,
        sessionId,
        attemptId,
        before: event.data?.before ? event.data.before.data() ?? null : null,
        after: event.data?.after ? event.data.after.data() ?? null : null,
      });
    } catch (error) {
      // Never throw from triggers
      logger.error("moderateUserContent error", {
        userId, childId, sessionId, attemptId, error: String(error),
      });
    }
  },
);

// ------------------------------------------------------------------
// HTTPS Callable: setAdminClaim
// ------------------------------------------------------------------

export const setAdminClaim = onCall<SetAdminClaimRequest, Promise<SetAdminClaimResponse>>(
  { enforceAppCheck: true, cors: true },
  async (request: CallableRequest<SetAdminClaimRequest>) => {
    return setAdminClaimHandler(admin, request);
  },
);

// ------------------------------------------------------------------
// Scheduled: sendDailyReminder
// ------------------------------------------------------------------

export const sendDailyReminder = onSchedule(
  {
    schedule: "0 17 * * *", // every day at 17:00 UTC
    timeZone: "UTC",
    region: REGION,
    retryCount: 2,
  },
  async () => {
    try {
      await runDailyReminder(admin);
    } catch (error) {
      logger.error("sendDailyReminder failed", { error: String(error) });
      throw error;
    }
  },
);

// ------------------------------------------------------------------
// Scheduled: sendWeeklySummary
// ------------------------------------------------------------------

export const sendWeeklySummary = onSchedule(
  {
    schedule: "0 19 * * 0", // Sundays at 19:00 UTC
    timeZone: "UTC",
    region: REGION,
    retryCount: 2,
  },
  async () => {
    try {
      await runWeeklySummary(admin);
    } catch (error) {
      logger.error("sendWeeklySummary failed", { error: String(error) });
      throw error;
    }
  },
);

// ------------------------------------------------------------------
// HTTPS Callable: sendWeeklySummaryFCM
// ------------------------------------------------------------------

interface ParentUserDoc {
  role?: string;
  fcmToken?: string;
}

export const sendWeeklySummaryFCM = onCall<SendWeeklySummaryFCMRequest, Promise<SendWeeklySummaryFCMResponse>>(
  { enforceAppCheck: true, cors: true },
  async (request) => {
    const { parentId } = request.data || {};

    if (typeof parentId !== "string" || parentId.length === 0) {
      throw new HttpsError("invalid-argument", "parentId is required");
    }

    if (!request.auth || request.auth.uid !== parentId) {
      throw new HttpsError("permission-denied", "Only the parent can request their own summary");
    }

    const db = admin.firestore();
    const messaging = admin.messaging();

    const parentDoc = await db.collection("users").doc(parentId).get();
    if (!parentDoc.exists) {
      throw new HttpsError("not-found", "Parent document not found");
    }
    const parent = (parentDoc.data() as ParentUserDoc | undefined) ?? {};

    if (parent.role !== "parent") {
      throw new HttpsError("failed-precondition", "User is not a parent");
    }

    const fcmToken = typeof parent.fcmToken === "string" && parent.fcmToken.length > 0 ?
      parent.fcmToken :
      null;

    if (!fcmToken) {
      return { sent: false, messageId: null };
    }

    const childrenSnap = await db
      .collection("users").doc(parentId)
      .collection("children").get();

    const childCount = childrenSnap.size;
    let totalSessions = 0;

    for (const childDoc of childrenSnap.docs) {
      const childId = childDoc.id;
      const weekAgo = new Date();
      weekAgo.setDate(weekAgo.getDate() - 7);

      const sessionsSnap = await db
        .collection("users").doc(parentId)
        .collection("children").doc(childId)
        .collection("sessions")
        .where("date", ">=", weekAgo.toISOString())
        .get();

      totalSessions += sessionsSnap.size;
    }

    const body = childCount === 1 ?
      `На этой неделе проведено занятий: ${totalSessions}` :
      `Детей: ${childCount}. Занятий за неделю: ${totalSessions}`;

    try {
      const messageId = await messaging.send({
        token: fcmToken,
        notification: {
          title: "Прогресс за неделю",
          body,
        },
        data: {
          type: "weekly_summary",
          parentId,
        },
        apns: {
          payload: {
            aps: { "content-available": 1 },
          },
        },
      });

      logger.info("sendWeeklySummaryFCM sent", { parentId: "[REDACTED]", messageId });
      return { sent: true, messageId };
    } catch (error) {
      logger.error("sendWeeklySummaryFCM failed", { error: String(error) });
      throw new HttpsError("internal", "Failed to send FCM message");
    }
  },
);

// ------------------------------------------------------------------
// HTTPS Callable: createFamilyInviteToken
// Replaces deprecated Firebase Dynamic Links (sunset 2025-08-25).
// ------------------------------------------------------------------

export const createFamilyInviteToken = onCall<
  CreateFamilyInviteTokenRequest,
  Promise<CreateFamilyInviteTokenResponse>
>(
  { enforceAppCheck: true, cors: true, timeoutSeconds: 30, memory: "256MiB" },
  async (request) => {
    const { parentId, role, durationHours } = request.data || {};

    if (typeof parentId !== "string" || parentId.length === 0) {
      throw new HttpsError("invalid-argument", "parentId is required");
    }

    if (!request.auth || request.auth.uid !== parentId) {
      throw new HttpsError("permission-denied", "Only the parent can create invites for themselves");
    }

    const allowedRoles: ReadonlyArray<FamilyInviteRole> = ["secondary", "observer"];
    const roleValue: FamilyInviteRole = allowedRoles.includes(role as FamilyInviteRole) ?
      (role as FamilyInviteRole) :
      "observer";

    const ttlHours = (typeof durationHours === "number" && durationHours > 0 && durationHours <= 168) ?
      durationHours :
      24;
    const expiresAt = Date.now() + (ttlHours * 3600 * 1000);

    const token = randomBytes(16).toString("hex");
    const shortCodeAlphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; // omit ambiguous chars
    let shortCode = "";
    for (let i = 0; i < 6; i++) {
      shortCode += shortCodeAlphabet[randomInt(shortCodeAlphabet.length)];
    }

    const inviteData = {
      parentId,
      role: roleValue,
      token,
      shortCode,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: admin.firestore.Timestamp.fromMillis(expiresAt),
      consumed: false,
      consumedBy: null,
      consumedAt: null,
    };

    try {
      await admin.firestore()
        .collection("family_invites").doc(token)
        .set(inviteData);

      const deepLinkURL = `https://happyspeech.mmf.bsu.app/invite?token=${token}&code=${shortCode}`;

      logger.info("createFamilyInviteToken issued", {
        parentId: "[REDACTED]",
        role: roleValue,
        ttlHours,
        shortCode,
      });

      return {
        token,
        shortCode,
        expiresAt: Math.floor(expiresAt / 1000),
        deepLinkURL,
      };
    } catch (error) {
      logger.error("createFamilyInviteToken failed", { error: String(error) });
      throw new HttpsError("internal", "Failed to create invite token");
    }
  },
);
