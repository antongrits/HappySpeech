'use strict';

/**
 * GDPR hard-delete of all user data (cascade).
 *
 * Steps:
 *   1) Recursively delete /users/{uid} (Firestore) via firestore.recursiveDelete.
 *   2) Recursively delete /specialists/{uid} if it exists.
 *   3) Delete all Storage objects under users/{uid}/** and exports/{uid}/**.
 *   4) Delete the Firebase Auth user record.
 *   5) Write an audit entry to /audits/.
 *
 * Returns counts for verification.
 */

async function countCollectionDocs(db, ref) {
  let total = 0;
  /* eslint-disable no-await-in-loop */
  const subs = await ref.listCollections();
  const snap = await ref.collection ? null : await ref.get();
  if (snap && snap.docs) {
    total += snap.docs.length;
    for (const doc of snap.docs) {
      total += await countCollectionDocs(db, doc.ref);
    }
  }
  for (const sub of subs) {
    const subSnap = await sub.get();
    total += subSnap.size;
    for (const doc of subSnap.docs) {
      total += await countCollectionDocs(db, doc.ref);
    }
  }
  /* eslint-enable no-await-in-loop */
  return total;
}

async function recursiveDeleteDoc(admin, ref) {
  const firestore = admin.firestore();
  // admin SDK exposes recursiveDelete (Node 10+ / admin ^10+).
  if (typeof firestore.recursiveDelete === 'function') {
    await firestore.recursiveDelete(ref);
    return;
  }
  // Fallback manual recursion
  /* eslint-disable no-await-in-loop */
  const subs = await ref.listCollections();
  for (const sub of subs) {
    const snap = await sub.get();
    for (const doc of snap.docs) {
      await recursiveDeleteDoc(admin, doc.ref);
    }
  }
  await ref.delete();
  /* eslint-enable no-await-in-loop */
}

async function deleteStoragePrefix(admin, prefix) {
  const bucket = admin.storage().bucket();
  try {
    const [files] = await bucket.getFiles({ prefix });
    await Promise.all(files.map((f) => f.delete({ ignoreNotFound: true })));
    return files.length;
  } catch (_) {
    return 0;
  }
}

async function deleteUserDataCascade(admin, userId) {
  const db = admin.firestore();

  // 1) Count (best-effort) before delete.
  let deletedDocuments = 0;
  try {
    deletedDocuments = await countCollectionDocs(db, db.collection('users').doc(userId));
  } catch (_) {
    deletedDocuments = 0;
  }

  // 2) Recursive Firestore delete.
  await recursiveDeleteDoc(admin, db.collection('users').doc(userId));
  await recursiveDeleteDoc(admin, db.collection('specialists').doc(userId)).catch(() => null);

  // 3) Delete Storage objects (two candidate prefixes).
  const storageDeleted = (await deleteStoragePrefix(admin, `users/${userId}/`))
    + (await deleteStoragePrefix(admin, `exports/${userId}/`))
    + (await deleteStoragePrefix(admin, `uploads/users/${userId}/`));

  // 4) Delete Firebase Auth user.
  let deletedAuthUser = false;
  try {
    await admin.auth().deleteUser(userId);
    deletedAuthUser = true;
  } catch (_) {
    deletedAuthUser = false;
  }

  // 5) Audit entry.
  try {
    await db.collection('audits').add({
      kind: 'delete',
      userId,
      deletedDocuments,
      deletedStorageObjects: storageDeleted,
      deletedAuthUser,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (_) { /* best-effort */ }

  return {
    deletedDocuments,
    deletedStorageObjects: storageDeleted,
    deletedAuthUser,
  };
}

module.exports = {
  deleteUserDataCascade,
  recursiveDeleteDoc,
};
