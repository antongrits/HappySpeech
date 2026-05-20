/**
 * GDPR export of all user data.
 *
 * Dumps:
 *   - /users/{uid}
 *   - /users/{uid}/children/**  (children + sessions + attempts + progress + plans
 *     + reports + weekly_reports + rewards + routes)
 *   - /specialists/{uid}        (if caller is also specialist)
 *   - Storage object paths under /users/{uid}/** (metadata only — no binary
 *     data in the bundle)
 *
 * The resulting JSON is uploaded to gs://<bucket>/users/{uid}/exports/<timestamp>.json
 * and a signed URL valid for 24h is returned.
 */

import { v4 as uuidv4 } from "uuid";
import type * as admin from "firebase-admin";
import type { ExportUserDataResponse, Firestore } from "./types";

type DocRef = FirebaseFirestore.DocumentReference;
type ColRef = FirebaseFirestore.CollectionReference;

interface CollectionDumpEntry {
  id: string;
  data: FirebaseFirestore.DocumentData;
  path: string;
  subcollections: Record<string, CollectionDumpEntry[]>;
}

interface UserTreeDump {
  id: string;
  data: FirebaseFirestore.DocumentData;
  path: string;
  subcollections: Record<string, CollectionDumpEntry[]>;
}

interface StorageObjectMeta {
  name: string;
  size: number;
  contentType: string | null;
  updated: string | null;
}

export async function dumpCollection(colRef: ColRef): Promise<CollectionDumpEntry[]> {
  const snap = await colRef.get();
  const out: CollectionDumpEntry[] = [];
  for (const doc of snap.docs) {
    const entry: CollectionDumpEntry = {
      id: doc.id,
      data: doc.data(),
      path: doc.ref.path,
      subcollections: {},
    };
    const subs = await doc.ref.listCollections();
    for (const sub of subs) {
      entry.subcollections[sub.id] = await dumpCollection(sub);
    }
    out.push(entry);
  }
  return out;
}

export async function dumpUserTree(
  db: Firestore,
  userId: string,
): Promise<UserTreeDump | { user: null; subcollections: Record<string, never> }> {
  const userRef = db.collection("users").doc(userId);
  const userSnap = await userRef.get();
  if (!userSnap.exists) {
    return { user: null, subcollections: {} };
  }
  const bundle: UserTreeDump = {
    id: userSnap.id,
    data: userSnap.data() ?? {},
    path: userSnap.ref.path,
    subcollections: {},
  };
  const subs = await userRef.listCollections();
  for (const sub of subs) {
    bundle.subcollections[sub.id] = await dumpCollection(sub);
  }
  return bundle;
}

async function dumpSpecialistTree(
  db: Firestore,
  userId: string,
): Promise<UserTreeDump | null> {
  const ref: DocRef = db.collection("specialists").doc(userId);
  const snap = await ref.get();
  if (!snap.exists) return null;
  const subs = await ref.listCollections();
  const bundle: UserTreeDump = {
    id: snap.id,
    data: snap.data() ?? {},
    path: ref.path,
    subcollections: {},
  };
  for (const sub of subs) {
    bundle.subcollections[sub.id] = await dumpCollection(sub);
  }
  return bundle;
}

async function listStorageObjects(
  adminSdk: typeof admin,
  userId: string,
): Promise<StorageObjectMeta[]> {
  const bucket = adminSdk.storage().bucket();
  const [files] = await bucket.getFiles({ prefix: `users/${userId}/` });
  return files.map((f) => {
    const meta = f.metadata as {
      size?: string | number;
      contentType?: string;
      updated?: string;
    };
    return {
      name: f.name,
      size: meta && Number(meta.size) || 0,
      contentType: (meta && meta.contentType) ?? null,
      updated: (meta && meta.updated) ?? null,
    };
  });
}

export async function exportUserDataBundle(
  adminSdk: typeof admin,
  userId: string,
): Promise<ExportUserDataResponse> {
  const db = adminSdk.firestore();

  const [userTree, specialistTree, storageObjects] = await Promise.all([
    dumpUserTree(db, userId),
    dumpSpecialistTree(db, userId),
    listStorageObjects(adminSdk, userId).catch(() => [] as StorageObjectMeta[]),
  ]);

  const bundle = {
    schema: "happyspeech.export.v1",
    exportedAt: new Date().toISOString(),
    userId,
    user: userTree,
    specialist: specialistTree,
    storage: storageObjects,
  };

  const jsonString = JSON.stringify(bundle, (_key, v: unknown) => {
    if (v && typeof v === "object") {
      const obj = v as { _seconds?: number; _nanoseconds?: number };
      if (typeof obj._seconds === "number" && typeof obj._nanoseconds === "number") {
        return new Date(obj._seconds * 1000 + Math.floor(obj._nanoseconds / 1e6))
          .toISOString();
      }
    }
    return v;
  }, 2);

  const bucket = adminSdk.storage().bucket();
  const exportId = `${Date.now()}-${uuidv4().slice(0, 8)}`;
  const objectName = `users/${userId}/exports/${exportId}.json`;
  const file = bucket.file(objectName);

  await file.save(jsonString, {
    contentType: "application/json",
    metadata: {
      metadata: {
        userId,
        schema: "happyspeech.export.v1",
        generatedAt: new Date().toISOString(),
      },
    },
  });

  const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000); // 24h
  let downloadUrl: string | null = null;
  try {
    const [signed] = await file.getSignedUrl({
      action: "read",
      expires: expiresAt,
    });
    downloadUrl = signed;
  } catch {
    // Signing not available in emulator — fall back to gs:// path.
    downloadUrl = `gs://${bucket.name}/${objectName}`;
  }

  // Audit
  await db.collection("audits").add({
    kind: "export",
    userId,
    objectName,
    bytes: Buffer.byteLength(jsonString, "utf8"),
    createdAt: adminSdk.firestore.FieldValue.serverTimestamp(),
  });

  return {
    downloadUrl,
    objectName,
    bytes: Buffer.byteLength(jsonString, "utf8"),
    expiresAt: expiresAt.toISOString(),
  };
}
