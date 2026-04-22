/**
 * HappySpeech — Firebase Cloud Functions entry point.
 *
 * Exports:
 *   - calculateProgress   (HTTPS callable)
 *   - generateReport      (HTTPS callable)
 *   - getUserStats        (HTTPS callable)
 *   - onSessionComplete   (Firestore trigger, v2)
 *
 * Contract source: .claude/team/api-contracts.md
 */

'use strict';

const admin = require('firebase-admin');

// Initialize admin SDK once per container.
if (!admin.apps.length) {
  admin.initializeApp();
}

// Region close to target audience (Russia/CIS). europe-west1 or europe-west3.
const REGION = 'europe-west3';

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { setGlobalOptions } = require('firebase-functions/v2');
const logger = require('firebase-functions/logger');

setGlobalOptions({ region: REGION, maxInstances: 10 });

const { calculateProgressForChild } = require('./src/progress');
const { buildReport } = require('./src/reports');
const { aggregateUserStats } = require('./src/stats');
const { assertAuthorized } = require('./src/auth');

// ------------------------------------------------------------------
// HTTPS Callable: calculateProgress
// Input:  { userId: string, childId: string }
// Output: { soundTargets: [{ soundTarget, stageProgress, totalSessions, totalMinutes }], updatedAt }
// ------------------------------------------------------------------

exports.calculateProgress = onCall(
  { enforceAppCheck: true, cors: false },
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
  { enforceAppCheck: true, cors: false },
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
  { enforceAppCheck: true, cors: false },
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
