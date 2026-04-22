'use strict';

/**
 * Admin bootstrap — set custom claim `admin: true/false` on a user.
 *
 * Access control (placeholder):
 *   - Caller must provide a shared secret that matches the runtime config
 *     `ADMIN_BOOTSTRAP_SECRET` (set via `firebase functions:config:set`).
 *   - Once at least one admin exists, future calls must be made by a
 *     signed-in admin (custom claim admin == true).
 *
 * Replace with a proper admin console in production.
 */

const { HttpsError } = require('firebase-functions/v2/https');

async function setAdminClaimHandler(admin, request) {
  const { targetUid, admin: adminFlag, secret } = request.data || {};

  if (typeof targetUid !== 'string' || targetUid.length === 0) {
    throw new HttpsError('invalid-argument', 'targetUid is required');
  }
  if (typeof adminFlag !== 'boolean') {
    throw new HttpsError('invalid-argument', 'admin must be boolean');
  }

  const callerIsAdmin = request.auth
    && request.auth.token
    && request.auth.token.admin === true;

  const envSecret = process.env.ADMIN_BOOTSTRAP_SECRET || '';
  const secretMatches = typeof secret === 'string'
    && secret.length >= 16
    && envSecret.length >= 16
    && secret === envSecret;

  if (!callerIsAdmin && !secretMatches) {
    throw new HttpsError('permission-denied', 'Admin or bootstrap secret required');
  }

  try {
    await admin.auth().setCustomUserClaims(targetUid, { admin: adminFlag });
    // Audit
    await admin.firestore().collection('audits').add({
      kind: 'setAdminClaim',
      targetUid,
      adminFlag,
      byUid: request.auth ? request.auth.uid : null,
      bySecret: !callerIsAdmin,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return { ok: true };
  } catch (err) {
    throw new HttpsError('internal', `Failed to set claim: ${err && err.code || err}`);
  }
}

module.exports = {
  setAdminClaimHandler,
};
