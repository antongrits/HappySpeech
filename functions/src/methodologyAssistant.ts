/**
 * Methodology Assistant — server bridge to Vertex AI Search (Discovery Engine).
 *
 * Adult-only RAG assistant. An authenticated parent / specialist asks a
 * free-text question about speech-therapy methodology; we call the grounded
 * Discovery Engine `:answer` endpoint over the imported methodology corpus and
 * return a Russian answer plus deduplicated source citations.
 *
 * COPPA / privacy posture:
 *   • Text-only. No child audio, no recordings, no child PII ever leaves device.
 *   • We never log the question text or the answer text (PII-free logging).
 *   • App Check is enforced by the callable wrapper in index.ts.
 *
 * The Discovery Engine resources live in a SEPARATE GCP project
 * (`happyspeech-assets-v2`) where the GenAI App Builder credit sits.
 * The Functions runtime service account therefore needs cross-project
 * `roles/discoveryengine.viewer` on that project (see deploy notes in
 * functions/README and the task report).
 */

import { GoogleAuth } from "google-auth-library";
import { HttpsError } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import type {
  AskMethodologyResponse,
  MethodologyCitation,
} from "./types";

// ── Discovery Engine target (Vertex AI Search) ──────────────────────────────
// Project NUMBER (not id) is what the REST path expects.
export const VAIS_PROJECT_NUMBER = "748066984647"; // happyspeech-assets-v2
export const VAIS_LOCATION = "eu";
export const VAIS_ENGINE_ID = "hs-methodology-engine";
export const VAIS_COLLECTION = "default_collection";
export const VAIS_SERVING_CONFIG = "default_search";

const ANSWER_ENDPOINT =
  `https://${VAIS_LOCATION}-discoveryengine.googleapis.com/v1/` +
  `projects/${VAIS_PROJECT_NUMBER}/locations/${VAIS_LOCATION}/` +
  `collections/${VAIS_COLLECTION}/engines/${VAIS_ENGINE_ID}/` +
  `servingConfigs/${VAIS_SERVING_CONFIG}:answer`;

const PREAMBLE =
  "Ты — помощник по методике русскоязычной логопедии для родителей и " +
  "специалистов. Отвечай по-русски, спокойно, конкретно и по делу, опираясь " +
  "ТОЛЬКО на предоставленный методический корпус. Если в корпусе нет ответа — " +
  "честно скажи об этом. Не давай медицинских диагнозов: приложение оказывает " +
  "педагогическую поддержку и не заменяет живого логопеда.";

const MAX_QUESTION_LENGTH = 600;

// ── Simple per-instance rate limiter (best-effort, not distributed) ─────────
// Discovery Engine answer calls are billable; cap per-user request rate to
// blunt abuse / runaway clients. A Firestore-backed limiter could replace this
// if stricter global limits are needed.
const RATE_WINDOW_MS = 60_000;
const RATE_MAX_PER_WINDOW = 8;
const rateState = new Map<string, number[]>();

function checkRateLimit(uid: string): void {
  const now = Date.now();
  const hits = (rateState.get(uid) ?? []).filter((t) => now - t < RATE_WINDOW_MS);
  if (hits.length >= RATE_MAX_PER_WINDOW) {
    throw new HttpsError(
      "resource-exhausted",
      "Слишком много запросов. Попробуйте через минуту.",
    );
  }
  hits.push(now);
  rateState.set(uid, hits);
}

// Cached auth client across warm invocations.
let cachedAuth: GoogleAuth | null = null;
function auth(): GoogleAuth {
  if (!cachedAuth) {
    cachedAuth = new GoogleAuth({
      scopes: ["https://www.googleapis.com/auth/cloud-platform"],
    });
  }
  return cachedAuth;
}

interface DiscoveryReference {
  chunkInfo?: { documentMetadata?: { title?: string; uri?: string } };
}
interface DiscoveryAnswer {
  state?: string;
  answerText?: string;
  references?: DiscoveryReference[];
}
interface DiscoveryAnswerResponse {
  answer?: DiscoveryAnswer;
  session?: string;
}

function uriToSource(uri: string | undefined): string | null {
  if (!uri) return null;
  // gs://.../docs/therapy-stages.txt  →  therapy-stages.md
  const file = uri.split("/").pop();
  if (!file) return null;
  return file.replace(/\.txt$/i, ".md");
}

function extractCitations(refs: DiscoveryReference[] | undefined): MethodologyCitation[] {
  const seen = new Map<string, MethodologyCitation>();
  for (const r of refs ?? []) {
    const meta = r.chunkInfo?.documentMetadata;
    const title = (meta?.title ?? "").trim();
    const source = uriToSource(meta?.uri);
    if (!title || !source) continue;
    if (!seen.has(source)) {
      seen.set(source, { title, source });
    }
  }
  return Array.from(seen.values());
}

/**
 * Calls the Discovery Engine answer endpoint and shapes the result for iOS.
 * Throws HttpsError with safe, user-facing Russian messages — never leaks raw
 * upstream errors or the question text.
 */
export async function askMethodology(
  uid: string,
  rawQuestion: unknown,
  rawSessionId: unknown,
): Promise<AskMethodologyResponse> {
  if (typeof rawQuestion !== "string") {
    throw new HttpsError("invalid-argument", "Вопрос обязателен.");
  }
  const question = rawQuestion.trim();
  if (question.length < 3) {
    throw new HttpsError("invalid-argument", "Слишком короткий вопрос.");
  }
  if (question.length > MAX_QUESTION_LENGTH) {
    throw new HttpsError(
      "invalid-argument",
      `Вопрос слишком длинный (макс. ${MAX_QUESTION_LENGTH} символов).`,
    );
  }

  checkRateLimit(uid);

  const sessionId =
    typeof rawSessionId === "string" && rawSessionId.length > 0 && rawSessionId.length < 256 ?
      rawSessionId :
      null;

  // Build request body for the grounded answer API.
  const body: Record<string, unknown> = {
    query: { text: question },
    answerGenerationSpec: {
      includeCitations: true,
      ignoreLowRelevantContent: true,
      modelSpec: { modelVersion: "stable" },
      promptSpec: { preamble: PREAMBLE },
    },
  };
  if (sessionId) {
    body.session =
      `projects/${VAIS_PROJECT_NUMBER}/locations/${VAIS_LOCATION}/` +
      `collections/${VAIS_COLLECTION}/engines/${VAIS_ENGINE_ID}/sessions/${sessionId}`;
  }

  let token: string | null | undefined;
  try {
    const client = await auth().getClient();
    const at = await client.getAccessToken();
    token = typeof at === "string" ? at : at?.token;
  } catch (error) {
    logger.error("methodologyAssistant: failed to mint access token", {
      error: String(error),
    });
    throw new HttpsError("internal", "Сервис помощника временно недоступен.");
  }
  if (!token) {
    throw new HttpsError("internal", "Сервис помощника временно недоступен.");
  }

  let res: Response;
  try {
    res = await fetch(ANSWER_ENDPOINT, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${token}`,
        "Content-Type": "application/json",
        "X-Goog-User-Project": VAIS_PROJECT_NUMBER,
      },
      body: JSON.stringify(body),
    });
  } catch (error) {
    logger.error("methodologyAssistant: upstream fetch failed", {
      error: String(error),
    });
    throw new HttpsError("unavailable", "Сервис помощника временно недоступен.");
  }

  if (!res.ok) {
    // Log status only — never the upstream body (may echo the question).
    logger.error("methodologyAssistant: upstream non-OK", { status: res.status });
    if (res.status === 429) {
      throw new HttpsError("resource-exhausted", "Сервис занят, попробуйте позже.");
    }
    if (res.status === 401 || res.status === 403) {
      throw new HttpsError("internal", "Сервис помощника недоступен (доступ).");
    }
    throw new HttpsError("internal", "Не удалось получить ответ.");
  }

  let data: DiscoveryAnswerResponse;
  try {
    data = (await res.json()) as DiscoveryAnswerResponse;
  } catch (error) {
    logger.error("methodologyAssistant: bad upstream JSON", { error: String(error) });
    throw new HttpsError("internal", "Не удалось получить ответ.");
  }

  const answerText = (data.answer?.answerText ?? "").trim();
  if (!answerText) {
    throw new HttpsError(
      "not-found",
      "По этому вопросу в методическом корпусе ничего не нашлось.",
    );
  }

  const citations = extractCitations(data.answer?.references);

  // Return the upstream session tail so the client can chain follow-ups.
  const returnedSession = data.session ? data.session.split("/").pop() ?? null : sessionId;

  // PII-free telemetry: counts only, never the text.
  logger.info("methodologyAssistant: answered", {
    citationCount: citations.length,
    answerChars: answerText.length,
  });

  return { answer: answerText, citations, sessionId: returnedSession };
}
