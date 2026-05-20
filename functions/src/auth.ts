import { HttpsError, type CallableRequest } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";

/**
 * Authorization check used by HTTPS-callable functions.
 *
 * Allows:
 *   1) owner of /users/{userId} tree (auth.uid === userId)
 *   2) admin (users/{uid}.role === 'admin')
 *   3) specialist linked to the given child
 *      (specialists/{uid}.linkedChildIds includes childId)
 *
 * Throws HttpsError when caller is not authenticated or not authorized.
 */
export async function assertAuthorized(
  auth: CallableRequest["auth"],
  userId: string,
  childId?: string,
): Promise<void> {
  if (!auth || !auth.uid) {
    throw new HttpsError("unauthenticated", "Sign in required");
  }

  if (auth.uid === userId) {
    return;
  }

  const db = admin.firestore();
  const callerDoc = await db.collection("users").doc(auth.uid).get();
  const callerRole = callerDoc.exists ?
    (callerDoc.data() as { role?: string } | undefined)?.role ?? null :
    null;

  if (callerRole === "admin") {
    return;
  }

  if (callerRole === "specialist" && childId) {
    const specialistDoc = await db.collection("specialists").doc(auth.uid).get();
    const linked = specialistDoc.exists ?
      ((specialistDoc.data() as { linkedChildIds?: string[] } | undefined)
        ?.linkedChildIds ?? []) :
      [];
    if (linked.includes(childId)) {
      return;
    }
  }

  throw new HttpsError("permission-denied", "Not allowed to access this child");
}
