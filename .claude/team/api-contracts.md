# API Contracts — HappySpeech
## Version 1.0 — 2026-04-21
## iOS (Realm local) ↔ Backend (Firebase Firestore + Storage)
## Managed by Backend Lead + iOS Lead. No REST API — Firestore + Storage SDK only.

---

## Architecture Note

HappySpeech uses **no custom REST API**. All backend communication goes through:
- **Firebase Auth SDK** — authentication
- **Firestore iOS SDK** — document read/write/listen
- **Firebase Storage iOS SDK** — audio upload/download, content pack download
- **Firebase App Check** — attestation against device/app tampering

This means "API contracts" are Firestore document schemas and Storage path conventions.

---

## 1. Realm Schema Contracts (Local — Device Source of Truth)

### ChildProfile
```
class ChildProfile: Object {
  @Persisted(primaryKey: true) var id: String       // UUID
  @Persisted var name: String
  @Persisted var age: Int                           // 5–8
  @Persisted var targetSounds: List<String>         // ["С", "Ш", "Р"]
  @Persisted var createdAt: Date
  @Persisted var parentId: String
  @Persisted var progressSummary: Map<String, Double> // soundTarget -> overallRate 0.0–1.0
}
```

### Session
```
class Session: Object {
  @Persisted(primaryKey: true) var id: String
  @Persisted var childId: String
  @Persisted var date: Date
  @Persisted var templateType: String               // "listen-and-choose"
  @Persisted var targetSound: String                // "Р"
  @Persisted var stage: String                      // "word"
  @Persisted var durationSeconds: Int
  @Persisted var totalAttempts: Int
  @Persisted var correctAttempts: Int
  @Persisted var fatigueDetected: Bool
  @Persisted var attempts: List<Attempt>
}
```

### Attempt (EmbeddedObject)
```
class Attempt: EmbeddedObject {
  @Persisted var id: String
  @Persisted var word: String
  @Persisted var audioLocalPath: String             // local file path on device
  @Persisted var audioStoragePath: String           // Firebase Storage path (set after sync)
  @Persisted var asrTranscript: String
  @Persisted var asrScore: Double                   // 0.0–1.0
  @Persisted var pronunciationScore: Double         // 0.0–1.0
  @Persisted var manualScore: Double                // -1 = not set; 0.0–1.0 = specialist override
  @Persisted var isCorrect: Bool
  @Persisted var timestamp: Date
}
```

### ContentPackMeta
```
class ContentPackMeta: Object {
  @Persisted(primaryKey: true) var id: String       // "С-stage0-v1"
  @Persisted var soundTarget: String
  @Persisted var stage: String
  @Persisted var templateType: String
  @Persisted var version: String
  @Persisted var isDownloaded: Bool
  @Persisted var isBundled: Bool
  @Persisted var storageUrl: String
  @Persisted var sizeBytes: Int
  @Persisted var lastSyncAt: Date?
}
```

### AdaptivePlan
```
class AdaptivePlan: Object {
  @Persisted(primaryKey: true) var id: String
  @Persisted var childId: String
  @Persisted var date: Date
  @Persisted var plannedRoute: List<RouteStep>
  @Persisted var actualRoute: List<RouteStep>
  @Persisted var fatigueLevel: Int                  // 0=fresh, 1=normal, 2=tired
  @Persisted var llmSummary: String?
  @Persisted var homeTask: String?
}

class RouteStep: EmbeddedObject {
  @Persisted var templateType: String
  @Persisted var targetSound: String
  @Persisted var stage: String
  @Persisted var difficulty: Int
  @Persisted var wordCount: Int
  @Persisted var completed: Bool
}
```

### SyncQueueItem
```
class SyncQueueItem: Object {
  @Persisted(primaryKey: true) var id: String
  @Persisted var entityType: String                 // "session" | "attempt" | "childProfile"
  @Persisted var entityId: String
  @Persisted var operation: String                  // "upsert" | "delete"
  @Persisted var payload: String                    // JSON string
  @Persisted var createdAt: Date
  @Persisted var syncedAt: Date?
  @Persisted var retryCount: Int
}
```

---

## 2. Firestore Document Schemas

### /users/{userId}
```json
{
  "uid": "firebase_uid",
  "email": "parent@example.com",
  "role": "parent",
  "createdAt": "Timestamp",
  "lastActiveAt": "Timestamp"
}
```

### /users/{userId}/children/{childId}
```json
{
  "id": "uuid",
  "name": "Миша",
  "age": 6,
  "targetSounds": ["Р", "Л"],
  "createdAt": "Timestamp",
  "progressSummary": { "Р": 0.45, "Л": 0.70 }
}
```

### /users/{userId}/children/{childId}/sessions/{sessionId}
```json
{
  "id": "uuid",
  "childId": "uuid",
  "date": "Timestamp",
  "templateType": "listen-and-choose",
  "targetSound": "Р",
  "stage": "word",
  "durationSeconds": 480,
  "totalAttempts": 12,
  "correctAttempts": 9,
  "successRate": 0.75,
  "fatigueDetected": false
}
```

### /users/{userId}/children/{childId}/sessions/{sessionId}/attempts/{attemptId}
```json
{
  "id": "uuid",
  "word": "рак",
  "audioStoragePath": "users/uid/children/cid/attempts/aid/audio.m4a",
  "asrTranscript": "рак",
  "asrScore": 0.92,
  "pronunciationScore": 0.85,
  "manualScore": -1,
  "isCorrect": true,
  "timestamp": "Timestamp"
}
```

### /users/{userId}/children/{childId}/progress/{soundTarget}
```json
{
  "soundTarget": "Р",
  "stageProgress": {
    "prep":      { "done": true,  "rate": 0.95 },
    "isolated":  { "done": true,  "rate": 0.90 },
    "syllable":  { "done": true,  "rate": 0.85 },
    "wordInit":  { "done": false, "rate": 0.60 },
    "wordMed":   { "done": false, "rate": 0.00 },
    "wordFinal": { "done": false, "rate": 0.00 },
    "phrase":    { "done": false, "rate": 0.00 },
    "sentence":  { "done": false, "rate": 0.00 },
    "story":     { "done": false, "rate": 0.00 },
    "diff":      { "done": false, "rate": 0.00 }
  },
  "lastUpdatedAt": "Timestamp",
  "totalSessions": 14,
  "totalMinutes": 112
}
```

### /contentPacks/{packId}
```json
{
  "id": "С-stage0-v1",
  "soundTarget": "С",
  "stage": "prep",
  "templateType": "articulation-imitation",
  "version": "1.0",
  "storageUrl": "gs://happyspeech.appspot.com/content/С-stage0-v1.zip",
  "sizeBytes": 2400000,
  "updatedAt": "Timestamp"
}
```

### /specialists/{specialistId}
```json
{
  "uid": "firebase_uid",
  "email": "logopedist@clinic.ru",
  "clinicName": "Речевой центр",
  "linkedChildIds": ["child_uuid_1"],
  "createdAt": "Timestamp"
}
```

---

## 3. Sync Protocol

### Write path (offline → online)
```
1. Any data write → Realm immediately (optimistic, instant UI update)
2. SyncQueueItem appended (operation="upsert", payload=JSON)
3. NetworkMonitor detects online
4. SyncService.drainQueue():
   a. Fetch unsynced items ordered by createdAt
   b. Batch to Firestore (max 500 ops per batch)
   c. Success → syncedAt = now
   d. Failure → retryCount++, exponential backoff (2^n sec, max 32s)
   e. After 5 retries → log to AnalyticsService (local only)
5. Audio → Firebase Storage, then set audioStoragePath in Attempt Firestore doc
```

### Conflict resolution
```
Session records:       Firestore timestamp wins
AdaptivePlan:          Local wins (don't overwrite today's plan)
ManualScore:           Specialist Firestore write wins over ASR score
ProgressSummary:       Last-write-wins by updatedAt timestamp
```

### Deletion flow
```
1. Parent taps "Delete child data" → confirm dialog
2. Realm objects deleted immediately
3. SyncQueueItem with operation="delete" queued for Firestore
4. Firebase Storage audio files: batch delete queued
5. On sync: Firestore docs deleted, Storage files deleted
```

---

## 4. Firebase Storage Path Conventions

```
gs://happyspeech.appspot.com/
├── content/
│   └── {soundTarget}-{stage}-v{version}.zip     # downloadable content packs
├── users/
│   └── {userId}/
│       └── children/
│           └── {childId}/
│               └── attempts/
│                   └── {attemptId}/
│                       └── audio.m4a             # child attempt recordings
└── models/
    ├── gigaam_child.onnx                          # ASR model
    └── qwen_1.5b_mlc_config.json                 # LLM model config
```

---

## 5. LLM Structured Output Contracts (LocalLLMService)

### ParentSummary Request → Response
```json
REQUEST:
{
  "type": "parent_summary",
  "child_name": "Миша",
  "target_sound": "Р",
  "stage": "word",
  "total_attempts": 12,
  "correct_attempts": 9,
  "error_words": ["ворона", "гараж"],
  "session_duration_sec": 480
}

RESPONSE (strict JSON):
{
  "parent_summary": "Миша сегодня тренировал звук Р в словах. Из 12 попыток — 9 правильных (75%). Слова «ворона» и «гараж» пока даются трудно — повторите их дома.",
  "home_task": "Произнесите вместе с Мишей 3 раза: ворона, гараж, огород."
}
```

### RoutePlanner Request → Response
```json
REQUEST:
{
  "type": "route_planner",
  "child_id": "uuid",
  "target_sound": "Р",
  "current_stage": "word",
  "recent_success_rate": 0.72,
  "fatigue_level": 1,
  "age": 6,
  "available_templates": ["listen-and-choose", "repeat-after-model", "sorting"]
}

RESPONSE:
{
  "route": [
    { "template": "listen-and-choose", "difficulty": 2, "word_count": 10, "duration_target_sec": 180 },
    { "template": "repeat-after-model", "difficulty": 2, "word_count": 8, "duration_target_sec": 240 }
  ],
  "session_max_duration_sec": 600
}
```

### MicroStory Request → Response
```json
REQUEST:
{
  "type": "micro_story",
  "target_sound": "Р",
  "stage": "sentence",
  "age": 7,
  "word_pool": ["рак","ракета","рыба","роза","радуга","рот","рис","рожок","русалка","роща"]
}

RESPONSE:
{
  "sentences": [
    "Рома нашёл в роще красивую розу.",
    "Он взял ракету и полетел к реке.",
    "У реки плавала большая рыба."
  ],
  "gap_positions": [
    { "sentence_index": 0, "word": "розу", "image_hint": "роза" },
    { "sentence_index": 1, "word": "ракету", "image_hint": "ракета" }
  ]
}
```
