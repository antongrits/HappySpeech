/**
 * HappySpeech — Firebase Cloud Functions entry point.
 *
 * Exports:
 *   - calculateProgress             (HTTPS callable)
 *   - generateReport                (HTTPS callable)
 *   - getUserStats                  (HTTPS callable)
 *   - exportUserData                (HTTPS callable, GDPR)
 *   - deleteUserData                (HTTPS callable, GDPR hard delete)
 *   - setAdminClaim                 (HTTPS callable, bootstrap)
 *   - sendWeeklySummaryFCM          (HTTPS callable, on-demand summary push)
 *   - createFamilyInviteToken       (HTTPS callable — Firestore-based invite, replaces Dynamic Links)
 *   - onSessionComplete             (Firestore trigger, v2)
 *   - moderateUserContent           (Firestore trigger, v2, placeholder)
 *   - sendWeeklyReport              (scheduled, every Sunday 10:00 MSK)
 *   - sendDailyReminder             (scheduled, every day 17:00 UTC = 20:00 MSK)
 *   - sendWeeklySummary             (scheduled, every Sunday 19:00 UTC = 22:00 MSK)
 *
 * Removed stubs (v28 cleanup):
 *   - scoreSpeechQuality, generateNeurolinguistSummary, validateChildVoice,
 *     analyzeSpeechProgress, generateSpecialistReport — все пять были
 *     детерминированными stubs, нигде не вызывались из iOS. Реальная оценка
 *     произношения выполняется on-device (PronunciationScorer Core ML).
 *
 * Region: europe-west3
 * Contract source: .claude/team/api-contracts.md + M1.3 plan
 */

'use strict';

const admin = require('firebase-admin');

// Initialize admin SDK once per container.
if (!admin.apps.length) {
  admin.initializeApp();
}

// Region close to target audience (Russia/CIS). europe-west3 (Frankfurt).
const REGION = 'europe-west3';

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onDocumentCreated, onDocumentWritten } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { setGlobalOptions } = require('firebase-functions/v2');
const logger = require('firebase-functions/logger');

setGlobalOptions({ region: REGION, maxInstances: 10 });

const { calculateProgressForChild } = require('./src/progress');
const { buildReport } = require('./src/reports');
const { aggregateUserStats } = require('./src/stats');
const { assertAuthorized } = require('./src/auth');
const { runWeeklyReport } = require('./src/weeklyReport');
const { exportUserDataBundle } = require('./src/export');
const { deleteUserDataCascade } = require('./src/delete');
const { moderateUserDocument } = require('./src/moderation');
const { setAdminClaimHandler } = require('./src/admin');
const { runDailyReminder } = require('./src/sendDailyReminder');
const { runWeeklySummary } = require('./src/sendWeeklySummary');

// ------------------------------------------------------------------
// HTTPS Callable: calculateProgress
// Input:  { userId: string, childId: string }
// Output: { soundTargets: [{ soundTarget, stageProgress, totalSessions, totalMinutes }], updatedAt }
// ------------------------------------------------------------------

exports.calculateProgress = onCall(
  { enforceAppCheck: true, cors: true },
  async (request) => {
    const { userId, childId } = request.data || {};

    if (typeof userId !== 'string' || typeof childId !== 'string') {
      throw new HttpsError('invalid-argument', 'userId and childId are required strings');
    }

    await assertAuthorized(request.auth, userId, childId);

    try {
      const progress = await calculateProgressForChild(admin.firestore(), userId, childId);
      logger.info('calculateProgress complete', { userId, childId, count: progress.soundTargets.length });
      return progress;
    } catch (error) {
      logger.error('calculateProgress failed', { userId, childId, error: String(error) });
      throw new HttpsError('internal', 'Failed to compute progress');
    }
  },
);

// ------------------------------------------------------------------
// HTTPS Callable: generateReport
// Input:  { userId: string, childId: string, period: "week" | "month" | "all" }
// Output: { summary, chartsData, recommendations, createdAt }
// ------------------------------------------------------------------

exports.generateReport = onCall(
  { enforceAppCheck: true, cors: true },
  async (request) => {
    const { userId, childId, period } = request.data || {};

    if (typeof userId !== 'string' || typeof childId !== 'string') {
      throw new HttpsError('invalid-argument', 'userId and childId are required strings');
    }

    const allowedPeriods = ['week', 'month', 'all'];
    const periodValue = allowedPeriods.includes(period) ? period : 'week';

    await assertAuthorized(request.auth, userId, childId);

    try {
      const report = await buildReport(admin.firestore(), userId, childId, periodValue);

      // Persist report under /users/{userId}/children/{childId}/reports/{reportId}
      const reportsRef = admin
        .firestore()
        .collection('users').doc(userId)
        .collection('children').doc(childId)
        .collection('reports');

      const docRef = await reportsRef.add({
        ...report,
        childId,
        period: periodValue,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      logger.info('generateReport complete', { userId, childId, reportId: docRef.id, period: periodValue });

      return {
        reportId: docRef.id,
        period: periodValue,
        ...report,
      };
    } catch (error) {
      logger.error('generateReport failed', { userId, childId, error: String(error) });
      throw new HttpsError('internal', 'Failed to generate report');
    }
  },
);

// ------------------------------------------------------------------
// HTTPS Callable: getUserStats
// Input:  { userId: string }
// Output: { childrenCount, totalSessions, totalMinutes, lastActiveAt, perChild: [...] }
// ------------------------------------------------------------------

exports.getUserStats = onCall(
  { enforceAppCheck: true, cors: true },
  async (request) => {
    const { userId } = request.data || {};

    if (typeof userId !== 'string') {
      throw new HttpsError('invalid-argument', 'userId is required');
    }

    if (!request.auth || request.auth.uid !== userId) {
      throw new HttpsError('permission-denied', 'Not allowed to read other users stats');
    }

    try {
      const stats = await aggregateUserStats(admin.firestore(), userId);
      return stats;
    } catch (error) {
      logger.error('getUserStats failed', { userId, error: String(error) });
      throw new HttpsError('internal', 'Failed to compute stats');
    }
  },
);

// ------------------------------------------------------------------
// Firestore Trigger: onSessionComplete
// Path: /users/{userId}/children/{childId}/sessions/{sessionId}
// Fires on document create — recomputes progress for the affected sound.
// ------------------------------------------------------------------

exports.onSessionComplete = onDocumentCreated(
  {
    document: 'users/{userId}/children/{childId}/sessions/{sessionId}',
    region: REGION,
  },
  async (event) => {
    const { userId, childId, sessionId } = event.params;
    const snapshot = event.data;

    if (!snapshot) {
      logger.warn('onSessionComplete: no snapshot', { userId, childId, sessionId });
      return;
    }

    const data = snapshot.data() || {};
    const targetSound = data.targetSound;

    logger.info('onSessionComplete', { userId, childId, sessionId, targetSound });

    try {
      await calculateProgressForChild(admin.firestore(), userId, childId, { onlySound: targetSound });
    } catch (error) {
      // Never throw from triggers — retries are handled by platform per config
      logger.error('onSessionComplete calculateProgress error', {
        userId, childId, sessionId, error: String(error),
      });
    }
  },
);

// ------------------------------------------------------------------
// Scheduled: sendWeeklyReport
// Every Sunday 10:00 Europe/Moscow (MSK, UTC+3).
// For each parent, generate a "week" report per child and persist it under
// /users/{uid}/children/{cid}/weekly_reports/{weekStartDate}. If the parent
// has an FCM token, attempt to send a push (will silently fail on iOS without
// APNs auth key — acceptable degraded mode per M1 decisions).
// ------------------------------------------------------------------

exports.sendWeeklyReport = onSchedule(
  {
    schedule: '0 10 * * 0', // Sundays at 10:00
    timeZone: 'Europe/Moscow',
    region: REGION,
    retryCount: 3,
  },
  async (event) => {
    try {
      const result = await runWeeklyReport(admin);
      logger.info('sendWeeklyReport finished', result);
    } catch (error) {
      logger.error('sendWeeklyReport failed', { error: String(error) });
      throw error; // allow retry
    }
  },
);

// ------------------------------------------------------------------
// HTTPS Callable: exportUserData
// Input:  { userId: string }
// Output: { downloadUrl: string, expiresAt: string, bytes: number }
//
// GDPR export — bundles all Firestore user data (+ Storage URL listings)
// into a JSON file uploaded to gs://<bucket>/users/{uid}/exports/<ts>.json,
// then returns a signed URL valid for 24h.
// ------------------------------------------------------------------

exports.exportUserData = onCall(
  { enforceAppCheck: true, cors: true, timeoutSeconds: 540, memory: '512MiB' },
  async (request) => {
    const { userId } = request.data || {};

    if (typeof userId !== 'string' || userId.length === 0) {
      throw new HttpsError('invalid-argument', 'userId is required');
    }

    if (!request.auth || request.auth.uid !== userId) {
      // admin may export for any user
      const callerUid = request.auth && request.auth.uid;
      if (!callerUid) {
        throw new HttpsError('unauthenticated', 'Sign in required');
      }
      const callerDoc = await admin.firestore().collection('users').doc(callerUid).get();
      const isAdminCaller = (request.auth.token && request.auth.token.admin === true) ||
        (callerDoc.exists && callerDoc.data().role === 'admin');
      if (!isAdminCaller) {
        throw new HttpsError('permission-denied', 'Not allowed to export other users');
      }
    }

    try {
      const result = await exportUserDataBundle(admin, userId);
      logger.info('exportUserData complete', { userId, bytes: result.bytes });
      return result;
    } catch (error) {
      logger.error('exportUserData failed', { userId, error: String(error) });
      throw new HttpsError('internal', 'Failed to export user data');
    }
  },
);

// ------------------------------------------------------------------
// HTTPS Callable: deleteUserData
// Input:  { userId: string, confirm: string }  // confirm must equal "DELETE"
// Output: { deletedDocuments: number, deletedStorageObjects: number, deletedAuthUser: boolean }
//
// GDPR hard-delete: cascade delete of Firestore subtrees, Storage objects, and Auth user.
// Uses firebase-admin recursiveDelete() under the hood.
// ------------------------------------------------------------------

exports.deleteUserData = onCall(
  { enforceAppCheck: true, cors: true, timeoutSeconds: 540, memory: '512MiB' },
  async (request) => {
    const { userId, confirm } = request.data || {};

    if (typeof userId !== 'string' || userId.length === 0) {
      throw new HttpsError('invalid-argument', 'userId is required');
    }
    if (confirm !== 'DELETE') {
      throw new HttpsError('failed-precondition', 'confirm must equal "DELETE"');
    }

    if (!request.auth || request.auth.uid !== userId) {
      const callerUid = request.auth && request.auth.uid;
      if (!callerUid) {
        throw new HttpsError('unauthenticated', 'Sign in required');
      }
      const callerDoc = await admin.firestore().collection('users').doc(callerUid).get();
      const isAdminCaller = (request.auth.token && request.auth.token.admin === true) ||
        (callerDoc.exists && callerDoc.data().role === 'admin');
      if (!isAdminCaller) {
        throw new HttpsError('permission-denied', 'Not allowed to delete other users');
      }
    }

    try {
      const result = await deleteUserDataCascade(admin, userId);
      logger.info('deleteUserData complete', { userId, ...result });
      return result;
    } catch (error) {
      logger.error('deleteUserData failed', { userId, error: String(error) });
      throw new HttpsError('internal', 'Failed to delete user data');
    }
  },
);

// ------------------------------------------------------------------
// Firestore trigger: moderateUserContent
// Placeholder for future user-generated content moderation.
// Listens on writes to any potentially user-generated document under
// /users/{uid}/children/{cid}/sessions/{sid}/attempts/{aid} — records an
// audit log entry and could call an external moderation API in the future.
// ------------------------------------------------------------------

exports.moderateUserContent = onDocumentWritten(
  {
    document: 'users/{userId}/children/{childId}/sessions/{sessionId}/attempts/{attemptId}',
    region: REGION,
  },
  async (event) => {
    const { userId, childId, sessionId, attemptId } = event.params;
    try {
      await moderateUserDocument(admin, {
        userId, childId, sessionId, attemptId,
        before: event.data && event.data.before ? event.data.before.data() : null,
        after: event.data && event.data.after ? event.data.after.data() : null,
      });
    } catch (error) {
      // Never throw from triggers
      logger.error('moderateUserContent error', {
        userId, childId, sessionId, attemptId, error: String(error),
      });
    }
  },
);

// ------------------------------------------------------------------
// HTTPS Callable: setAdminClaim  (PLACEHOLDER)
// Input:  { targetUid: string, admin: bool, secret: string }
// Output: { ok: true }
//
// Sets the `admin` custom claim on a user. Currently gated by an env secret
// (ADMIN_BOOTSTRAP_SECRET). Replace with a proper admin role in production.
// ------------------------------------------------------------------

exports.setAdminClaim = onCall(
  { enforceAppCheck: true, cors: true },
  async (request) => {
    return setAdminClaimHandler(admin, request);
  },
);

// ------------------------------------------------------------------
// Scheduled: sendDailyReminder
// Every day at 17:00 UTC (= 20:00 MSK).
// Sends a push to parents whose active child has not had a session today.
// COPPA: only parents with explicit notificationsEnabled == true are targeted.
// ------------------------------------------------------------------

exports.sendDailyReminder = onSchedule(
  {
    schedule: '0 17 * * *', // every day at 17:00 UTC
    timeZone: 'UTC',
    region: REGION,
    retryCount: 2,
  },
  async () => {
    try {
      await runDailyReminder(admin);
    } catch (error) {
      logger.error('sendDailyReminder failed', { error: String(error) });
      throw error;
    }
  },
);

// ------------------------------------------------------------------
// Scheduled: sendWeeklySummary
// Every Sunday at 19:00 UTC (= 22:00 MSK).
// Sends a weekly stats summary push to all parents with opt-in enabled.
// COPPA: only parents are targeted; no kid PII in notification payload.
// ------------------------------------------------------------------

exports.sendWeeklySummary = onSchedule(
  {
    schedule: '0 19 * * 0', // Sundays at 19:00 UTC
    timeZone: 'UTC',
    region: REGION,
    retryCount: 2,
  },
  async () => {
    try {
      await runWeeklySummary(admin);
    } catch (error) {
      logger.error('sendWeeklySummary failed', { error: String(error) });
      throw error;
    }
  },
);

// ------------------------------------------------------------------
// HTTPS Callable: sendWeeklySummaryFCM
// Input:  { parentId: string }
// Output: { sent: boolean, messageId: string | null }
//
// Pulls weekly child progress for the given parent and sends an FCM push
// to the parent's registered device token.
//
// COPPA / Kids Category:
//   - Called only for authenticated, non-anonymous parent users.
//   - Token is read from /users/{parentId}.fcmToken — stored by iOS FCMService
//     only after explicit parent opt-in.
//   - No child PII included in the notification payload body.
// ------------------------------------------------------------------

exports.sendWeeklySummaryFCM = onCall(
  { enforceAppCheck: true, cors: true },
  async (request) => {
    const { parentId } = request.data || {};

    if (typeof parentId !== 'string' || parentId.length === 0) {
      throw new HttpsError('invalid-argument', 'parentId is required');
    }

    if (!request.auth || request.auth.uid !== parentId) {
      throw new HttpsError('permission-denied', 'Only the parent can request their own summary');
    }

    const db = admin.firestore();
    const messaging = admin.messaging();

    // Read parent doc — check role and FCM token.
    const parentDoc = await db.collection('users').doc(parentId).get();
    if (!parentDoc.exists) {
      throw new HttpsError('not-found', 'Parent document not found');
    }
    const parent = parentDoc.data() || {};

    if (parent.role !== 'parent') {
      throw new HttpsError('failed-precondition', 'User is not a parent');
    }

    const fcmToken = typeof parent.fcmToken === 'string' && parent.fcmToken.length > 0 ?
      parent.fcmToken :
      null;

    if (!fcmToken) {
      return { sent: false, messageId: null };
    }

    // Collect weekly progress summary across children.
    const childrenSnap = await db
      .collection('users').doc(parentId)
      .collection('children').get();

    const childCount = childrenSnap.size;
    let totalSessions = 0;

    for (const childDoc of childrenSnap.docs) {
      const childId = childDoc.id;
      const weekAgo = new Date();
      weekAgo.setDate(weekAgo.getDate() - 7);

      const sessionsSnap = await db
        .collection('users').doc(parentId)
        .collection('children').doc(childId)
        .collection('sessions')
        .where('date', '>=', weekAgo.toISOString())
        .get();

      totalSessions += sessionsSnap.size;
    }

    // Build notification — no child names or PII in the body, only aggregate counts.
    const body = childCount === 1 ?
      `На этой неделе проведено занятий: ${totalSessions}` :
      `Детей: ${childCount}. Занятий за неделю: ${totalSessions}`;

    try {
      const messageId = await messaging.send({
        token: fcmToken,
        notification: {
          title: 'Прогресс за неделю',
          body,
        },
        data: {
          type: 'weekly_summary',
          parentId,
        },
        apns: {
          payload: {
            aps: { 'content-available': 1 },
          },
        },
      });

      logger.info('sendWeeklySummaryFCM sent', { parentId: '[REDACTED]', messageId });
      return { sent: true, messageId };
    } catch (error) {
      logger.error('sendWeeklySummaryFCM failed', { error: String(error) });
      throw new HttpsError('internal', 'Failed to send FCM message');
    }
  },
);

// ------------------------------------------------------------------
// HTTPS Callable: createFamilyInviteToken
// Input:  { parentId: string, role: "secondary" | "observer", durationHours?: number }
// Output: { token: string, shortCode: string, expiresAt: number, deepLinkURL: string }
//
// Replaces deprecated Firebase Dynamic Links (sunset 2025-08-25).
// Creates a single-use Firestore-stored invite token. Kid scans QR / parent
// enters short code → deep link via Apple Universal Links resolves to Firestore lookup.
//
// See: ADR-V18-U-DYNAMICLINKS-REPLACE
// ------------------------------------------------------------------

exports.createFamilyInviteToken = onCall(
  { enforceAppCheck: true, cors: true, timeoutSeconds: 30, memory: '256MiB' },
  async (request) => {
    const { parentId, role, durationHours } = request.data || {};

    if (typeof parentId !== 'string' || parentId.length === 0) {
      throw new HttpsError('invalid-argument', 'parentId is required');
    }

    if (!request.auth || request.auth.uid !== parentId) {
      throw new HttpsError('permission-denied', 'Only the parent can create invites for themselves');
    }

    const allowedRoles = ['secondary', 'observer'];
    const roleValue = allowedRoles.includes(role) ? role : 'observer';

    const ttlHours = (typeof durationHours === 'number' && durationHours > 0 && durationHours <= 168) ?
      durationHours :
      24;
    const expiresAt = Date.now() + (ttlHours * 3600 * 1000);

    // Generate cryptographically random token (32 chars hex) and 6-char short code (uppercase alphanumeric).
    // eslint-disable-next-line global-require
    const crypto = require('crypto');
    const token = crypto.randomBytes(16).toString('hex');
    const shortCodeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // omit ambiguous chars (0/O, 1/I)
    let shortCode = '';
    for (let i = 0; i < 6; i++) {
      shortCode += shortCodeAlphabet[crypto.randomInt(shortCodeAlphabet.length)];
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
      // Path: /family_invites/{token} — top-level collection (queryable by short code via index).
      await admin.firestore()
        .collection('family_invites').doc(token)
        .set(inviteData);

      // Universal Link URL — resolved by iOS app via Associated Domains entitlement.
      const deepLinkURL = `https://happyspeech.mmf.bsu.app/invite?token=${token}&code=${shortCode}`;

      logger.info('createFamilyInviteToken issued', {
        parentId: '[REDACTED]',
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
      logger.error('createFamilyInviteToken failed', { error: String(error) });
      throw new HttpsError('internal', 'Failed to create invite token');
    }
  },
);
