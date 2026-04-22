'use strict';

/**
 * GDPR export of all user data.
 *
 * Dumps:
 *   - /users/{uid}
 *   - /users/{uid}/children/**  (children + sessions + attempts + progress + plans + reports + weekly_reports + rewards + routes)
 *   - /specialists/{uid}        (if caller is also specialist)
 *   - Storage object paths under /users/{uid}/** (metadata only — no binary data in the bundle)
 *
 * The resulting JSON is uploaded to gs://<bucket>/users/{uid}/exports/<timestamp>.json
 * and a signed URL valid for 24h is returned.
 */

const { v4: uuidv4 } = (() => {
  try {
    return require('uuid');
  } catch (_) {
    // Fallback if uuid is not installed — use Math.random-based id.
    return { v4: () => `${Date.now()}-${Math.random().toString(36).slice(2, 10)}` };
  }
})();

async function dumpCollection(colRef) {
  const snap = await colRef.get();
  const out = [];
  /* eslint-disable no-await-in-loop */
  for (const doc of snap.docs) {
    const entry = { id: doc.id, data: doc.data(), path: doc.ref.path, subcollections: {} };
    const subs = await doc.ref.listCollections();
    for (const sub of subs) {
      entry.subcollections[sub.id] = await dumpCollection(sub);
    }
    out.push(entry);
  }
  /* eslint-enable no-await-in-loop */
  return out;
}

async function dumpUserTree(db, userId) {
  const userRef = db.collection('users').doc(userId);
  const userSnap = await userRef.get();
  if (!userSnap.exists) {
    return { user: null, subcollections: {} };
  }
  const bundle = {
    id: userSnap.id,
    data: userSnap.data(),
    path: userSnap.ref.path,
    subcollections: {},
  };
  const subs = await userRef.listCollections();
  /* eslint-disable no-await-in-loop */
  for (const sub of subs) {
    bundle.subcollections[sub.id] = await dumpCollection(sub);
  }
  /* eslint-enable no-await-in-loop */
  return bundle;
}

async function dumpSpecialistTree(db, userId) {
  const ref = db.collection('specialists').doc(userId);
  const snap = await ref.get();
  if (!snap.exists) return null;
  const subs = await ref.listCollections();
  const bundle = {
    id: snap.id,
    data: snap.data(),
    path: ref.path,
    subcollections: {},
  };
  /* eslint-disable no-await-in-loop */
  for (const sub of subs) {
    bundle.subcollections[sub.id] = await dumpCollection(sub);
  }
  /* eslint-enable no-await-in-loop */
  return bundle;
}

async function listStorageObjects(admin, userId) {
  const bucket = admin.storage().bucket();
  const [files] = await bucket.getFiles({ prefix: `users/${userId}/` });
  return files.map((f) => ({
    name: f.name,
    size: f.metadata && Number(f.metadata.size) || 0,
    contentType: f.metadata && f.metadata.contentType || null,
    updated: f.metadata && f.metadata.updated || null,
  }));
}

async function exportUserDataBundle(admin, userId) {
  const db = admin.firestore();

  const [userTree, specialistTree, storageObjects] = await Promise.all([
    dumpUserTree(db, userId),
    dumpSpecialistTree(db, userId),
    listStorageObjects(admin, userId).catch(() => []),
  ]);

  const bundle = {
    schema: 'happyspeech.export.v1',
    exportedAt: new Date().toISOString(),
    userId,
    user: userTree,
    specialist: specialistTree,
    storage: storageObjects,
  };

  const jsonString = JSON.stringify(bundle, (_, v) => {
    if (v && typeof v === 'object' && typeof v._seconds === 'number' && typeof v._nanoseconds === 'number') {
      // Firestore Timestamp → ISO
      return new Date(v._seconds * 1000 + Math.floor(v._nanoseconds / 1e6)).toISOString();
    }
    return v;
  }, 2);

  const bucket = admin.storage().bucket();
  const exportId = `${Date.now()}-${uuidv4().slice(0, 8)}`;
  const objectName = `users/${userId}/exports/${exportId}.json`;
  const file = bucket.file(objectName);

  await file.save(jsonString, {
    contentType: 'application/json',
    metadata: {
      metadata: {
        userId,
        schema: 'happyspeech.export.v1',
        generatedAt: new Date().toISOString(),
      },
    },
  });

  const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000); // 24h
  let downloadUrl = null;
  try {
    const [signed] = await file.getSignedUrl({
      action: 'read',
      expires: expiresAt,
    });
    downloadUrl = signed;
  } catch (_) {
    // Signing not available in emulator — fall back to gs:// path.
    downloadUrl = `gs://${bucket.name}/${objectName}`;
  }

  // Audit
  await db.collection('audits').add({
    kind: 'export',
    userId,
    objectName,
    bytes: Buffer.byteLength(jsonString, 'utf8'),
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return {
    downloadUrl,
    objectName,
    bytes: Buffer.byteLength(jsonString, 'utf8'),
    expiresAt: expiresAt.toISOString(),
  };
}

module.exports = {
  exportUserDataBundle,
  dumpCollection,
  dumpUserTree,
};
