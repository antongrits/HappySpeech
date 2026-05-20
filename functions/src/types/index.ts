/**
 * Shared types for HappySpeech Cloud Functions.
 *
 * Contracts mirror api-contracts.md and the iOS CloudFunctionsService
 * Swift signatures. DO NOT change wire shapes without updating both
 * sides — iOS callable expects these exact field names.
 */

import type * as admin from "firebase-admin";

// ────────────────────────────────────────────────────────────────────────────
// Firestore types
// ────────────────────────────────────────────────────────────────────────────

export type Firestore = admin.firestore.Firestore;
export type DocumentSnapshot = admin.firestore.DocumentSnapshot;
export type QueryDocumentSnapshot = admin.firestore.QueryDocumentSnapshot;
export type Messaging = admin.messaging.Messaging;

// ────────────────────────────────────────────────────────────────────────────
// Domain entities
// ────────────────────────────────────────────────────────────────────────────

export interface StageProgressEntry {
  done: boolean;
  rate: number;
  attempts: number;
}

export type StageProgress = Record<string, StageProgressEntry>;

export interface SoundProgressBucket {
  stages: StageProgress;
  totalSessions: number;
  totalMinutes: number;
  totalAttempts: number;
  correctAttempts: number;
}

export interface SoundProgressSummary {
  soundTarget: string;
  stageProgress: StageProgress;
  lastUpdatedAt: admin.firestore.FieldValue;
  totalSessions: number;
  totalMinutes: number;
  overallRate: number;
  childId: string;
}

export interface CalculateProgressResult {
  soundTargets: SoundProgressSummary[];
  updatedAt: string;
}

export interface CalculateProgressOptions {
  onlySound?: string;
}

// ────────────────────────────────────────────────────────────────────────────
// Reports
// ────────────────────────────────────────────────────────────────────────────

export type ReportPeriod = "week" | "month" | "all";

export interface DailySeriesEntry {
  date: string;
  sessions: number;
  minutes: number;
  accuracy: number;
}

export interface SoundBreakdownEntry {
  soundTarget: string;
  sessions: number;
  minutes: number;
  accuracy: number;
}

export interface ReportSummary {
  period: ReportPeriod;
  totalSessions: number;
  totalMinutes: number;
  totalAttempts: number;
  correctAttempts: number;
  overallAccuracy: number;
  generatedAt: string;
}

export interface ReportChartsData {
  daily: DailySeriesEntry[];
  perSound: SoundBreakdownEntry[];
}

export interface BuiltReport {
  summary: ReportSummary;
  chartsData: ReportChartsData;
  recommendations: string[];
}

// ────────────────────────────────────────────────────────────────────────────
// Callable request/response shapes
// ────────────────────────────────────────────────────────────────────────────

export interface CalculateProgressRequest {
  userId?: unknown;
  childId?: unknown;
}

export interface GenerateReportRequest {
  userId?: unknown;
  childId?: unknown;
  period?: unknown;
}

export interface GenerateReportResponse extends BuiltReport {
  reportId: string;
  period: ReportPeriod;
}

export interface GetUserStatsRequest {
  userId?: unknown;
}

export interface PerChildStats {
  childId: string;
  name: string;
  age: number | null;
  totalSessions: number;
  totalMinutes: number;
  lastActiveAt: string | null;
  progressSummary: Record<string, number>;
}

export interface UserStats {
  userId: string;
  childrenCount: number;
  totalSessions: number;
  totalMinutes: number;
  lastActiveAt: string | null;
  perChild: PerChildStats[];
}

export interface ExportUserDataRequest {
  userId?: unknown;
}

export interface ExportUserDataResponse {
  downloadUrl: string | null;
  objectName: string;
  bytes: number;
  expiresAt: string;
}

export interface DeleteUserDataRequest {
  userId?: unknown;
  confirm?: unknown;
}

export interface DeleteUserDataResponse {
  deletedDocuments: number;
  deletedStorageObjects: number;
  deletedAuthUser: boolean;
}

export interface SetAdminClaimRequest {
  targetUid?: unknown;
  admin?: unknown;
  secret?: unknown;
}

export interface SetAdminClaimResponse {
  ok: true;
}

export interface SendWeeklySummaryFCMRequest {
  parentId?: unknown;
}

export interface SendWeeklySummaryFCMResponse {
  sent: boolean;
  messageId: string | null;
}

export type FamilyInviteRole = "secondary" | "observer";

export interface CreateFamilyInviteTokenRequest {
  parentId?: unknown;
  role?: unknown;
  durationHours?: unknown;
}

export interface CreateFamilyInviteTokenResponse {
  token: string;
  shortCode: string;
  expiresAt: number;
  deepLinkURL: string;
}

// ────────────────────────────────────────────────────────────────────────────
// Trigger context payloads
// ────────────────────────────────────────────────────────────────────────────

export interface ModerationContext {
  userId: string;
  childId: string;
  sessionId: string;
  attemptId: string;
  before: admin.firestore.DocumentData | null;
  after: admin.firestore.DocumentData | null;
}

export interface ModerationResult {
  flagged: boolean;
}
