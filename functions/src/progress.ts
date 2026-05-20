import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";

import {
  STAGES,
  STAGE_PASS_THRESHOLD,
  MIN_ATTEMPTS_FOR_STAGE,
} from "./constants";
import type {
  CalculateProgressOptions,
  CalculateProgressResult,
  Firestore,
  QueryDocumentSnapshot,
  SoundProgressBucket,
  SoundProgressSummary,
  StageProgress,
} from "./types";

interface SessionData {
  targetSound?: string;
  stage?: string;
  durationSeconds?: number;
  totalAttempts?: number;
  correctAttempts?: number;
}

/** Build an empty progress stage map. */
export function emptyStageProgress(): StageProgress {
  const out: StageProgress = {};
  for (const stage of STAGES) {
    out[stage] = { done: false, rate: 0.0, attempts: 0 };
  }
  return out;
}

/**
 * Group sessions by targetSound and stage, then compute aggregate accuracy.
 */
export function groupSessionsBySound(
  sessionDocs: ReadonlyArray<QueryDocumentSnapshot | { data: () => SessionData }>,
): Map<string, SoundProgressBucket> {
  const bySound = new Map<string, SoundProgressBucket>();

  for (const doc of sessionDocs) {
    const data = doc.data() as SessionData;
    const sound = data.targetSound;
    if (!sound) continue;

    let bucket = bySound.get(sound);
    if (!bucket) {
      bucket = {
        stages: emptyStageProgress(),
        totalSessions: 0,
        totalMinutes: 0,
        totalAttempts: 0,
        correctAttempts: 0,
      };
      bySound.set(sound, bucket);
    }

    bucket.totalSessions += 1;
    bucket.totalMinutes += Math.round((data.durationSeconds || 0) / 60);
    bucket.totalAttempts += data.totalAttempts || 0;
    bucket.correctAttempts += data.correctAttempts || 0;

    const stageKey = data.stage && STAGES.includes(data.stage) ? data.stage : null;
    if (stageKey) {
      const stageBucket = bucket.stages[stageKey];
      const attemptsBefore = stageBucket.attempts;
      stageBucket.attempts += data.totalAttempts || 0;
      const prevCorrect = (stageBucket.rate * attemptsBefore) || 0;
      const newCorrect = prevCorrect + (data.correctAttempts || 0);
      stageBucket.rate = stageBucket.attempts > 0 ?
        newCorrect / stageBucket.attempts :
        0;
      stageBucket.done = stageBucket.attempts >= MIN_ATTEMPTS_FOR_STAGE &&
        stageBucket.rate >= STAGE_PASS_THRESHOLD;
    }
  }

  return bySound;
}

/**
 * Compute per-phoneme progress for a child and upsert into /progress/{soundTarget}.
 */
export async function calculateProgressForChild(
  db: Firestore,
  userId: string,
  childId: string,
  options: CalculateProgressOptions = {},
): Promise<CalculateProgressResult> {
  const sessionsRef = db
    .collection("users").doc(userId)
    .collection("children").doc(childId)
    .collection("sessions");

  const query: FirebaseFirestore.Query = options.onlySound ?
    sessionsRef.where("targetSound", "==", options.onlySound) :
    sessionsRef;

  const sessionsSnap = await query.get();
  const grouped = groupSessionsBySound(sessionsSnap.docs);

  const progressRef = db
    .collection("users").doc(userId)
    .collection("children").doc(childId)
    .collection("progress");

  const batch = db.batch();
  const summaries: SoundProgressSummary[] = [];

  for (const [sound, bucket] of grouped.entries()) {
    const docRef = progressRef.doc(sound);
    const payload: SoundProgressSummary = {
      soundTarget: sound,
      stageProgress: bucket.stages,
      lastUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
      totalSessions: bucket.totalSessions,
      totalMinutes: bucket.totalMinutes,
      overallRate: bucket.totalAttempts > 0 ?
        bucket.correctAttempts / bucket.totalAttempts :
        0,
      childId,
    };
    batch.set(docRef, payload, { merge: true });
    summaries.push(payload);
  }

  if (summaries.length > 0) {
    await batch.commit();
  } else {
    logger.info("calculateProgressForChild: no sessions yet", { userId, childId });
  }

  // Update child.progressSummary for quick read.
  if (summaries.length > 0) {
    const progressSummary: Record<string, number> = {};
    for (const s of summaries) {
      progressSummary[s.soundTarget] = Number((s.overallRate || 0).toFixed(3));
    }
    await db
      .collection("users").doc(userId)
      .collection("children").doc(childId)
      .set(
        {
          progressSummary,
          lastProgressAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
  }

  return {
    soundTargets: summaries,
    updatedAt: new Date().toISOString(),
  };
}
