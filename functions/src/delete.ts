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

import type * as admin from "firebase-admin";
import type { DeleteUserDataResponse, Firestore } from "./types";

type DocRef = FirebaseFirestore.DocumentReference;
type ColRef = FirebaseFirestore.CollectionReference;

async function countCollectionDocs(_db: Firestore, ref: DocRef): Promise<number> {
  let total = 0;
  const subs = await ref.listCollections();
  for (const sub of subs) {
    const subSnap = await sub.get();
    total += subSnap.size;
    for (const doc of subSnap.docs) {
      total += await countCollectionDocs(_db, doc.ref);
    }
  }
  return total;
}

type RecursiveDelete = (ref: DocRef | ColRef) => Promise<void>;

export async function recursiveDeleteDoc(
  adminSdk: typeof admin,
  ref: DocRef,
): Promise<void> {
  const firestore = adminSdk.firestore() as Firestore & {
    recursiveDelete?: RecursiveDelete;
  };
  if (typeof firestore.recursiveDelete === "function") {
    await firestore.recursiveDelete(ref);
    return;
  }
  // Fallback manual recursion
  const subs = await ref.listCollections();
  for (const sub of subs) {
    const snap = await sub.get();
    for (const doc of snap.docs) {
      await recursiveDeleteDoc(adminSdk, doc.ref);
    }
  }
  await ref.delete();
}

async function deleteStoragePrefix(
  adminSdk: typeof admin,
  prefix: string,
): Promise<number> {
  const bucket = adminSdk.storage().bucket();
  try {
    const [files] = await bucket.getFiles({ prefix });
    await Promise.all(files.map((f) => f.delete({ ignoreNotFound: true })));
    return files.length;
  } catch {
    return 0;
  }
}

export async function deleteUserDataCascade(
  adminSdk: typeof admin,
  userId: string,
): Promise<DeleteUserDataResponse> {
  const db = adminSdk.firestore();

  // 1) Count (best-effort) before delete.
  let deletedDocuments = 0;
  try {
    deletedDocuments = await countCollectionDocs(db, db.collection("users").doc(userId));
  } catch {
    deletedDocuments = 0;
  }

  // 2) Recursive Firestore delete.
  await recursiveDeleteDoc(adminSdk, db.collection("users").doc(userId));
  await recursiveDeleteDoc(adminSdk, db.collection("specialists").doc(userId))
    .catch(() => null);

  // 3) Delete Storage objects (three candidate prefixes).
  const storageDeleted =
    (await deleteStoragePrefix(adminSdk, `users/${userId}/`)) +
    (await deleteStoragePrefix(adminSdk, `exports/${userId}/`)) +
    (await deleteStoragePrefix(adminSdk, `uploads/users/${userId}/`));

  // 4) Delete Firebase Auth user.
  let deletedAuthUser = false;
  try {
    await adminSdk.auth().deleteUser(userId);
    deletedAuthUser = true;
  } catch {
    deletedAuthUser = false;
  }

  // 5) Audit entry.
  try {
    await db.collection("audits").add({
      kind: "delete",
      userId,
      deletedDocuments,
      deletedStorageObjects: storageDeleted,
      deletedAuthUser,
      createdAt: adminSdk.firestore.FieldValue.serverTimestamp(),
    });
  } catch {
    /* best-effort */
  }

  return {
    deletedDocuments,
    deletedStorageObjects: storageDeleted,
    deletedAuthUser,
  };
}
