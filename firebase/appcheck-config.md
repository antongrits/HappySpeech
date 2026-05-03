# Firebase App Check — Configuration

## Status: ENFORCED (Phase 2.7-D v15)

## Provider configuration

| Build | Provider | Notes |
|-------|----------|-------|
| DEBUG / Simulator | `AppCheckDebugProviderFactory` | Uses `FIREBASE_APP_CHECK_DEBUG_TOKEN` env var |
| RELEASE | `DeviceCheckProviderFactory` | Apple DeviceCheck — hardware attestation |

## iOS code (HappySpeechApp.swift)

```swift
#if DEBUG
let appCheckFactory = AppCheckDebugProviderFactory()
#else
let appCheckFactory = DeviceCheckProviderFactory()
#endif
AppCheck.setAppCheckProviderFactory(appCheckFactory)
FirebaseApp.configure()
```

IMPORTANT: `AppCheck.setAppCheckProviderFactory()` MUST be called before `FirebaseApp.configure()`.

## Firebase Console enforcement

`firebase.json` configures:
```json
"appcheck": {
  "enforcementMode": "ENFORCED",
  "providers": {
    "deviceCheck": { "enabled": true },
    "debug": { "enabled": true }
  }
}
```

## Debug token usage (Simulator / CI)

1. Run app in simulator once — console prints debug token
2. Add token in Firebase Console → App Check → Apps → Manage debug tokens
3. Or set `FIREBASE_APP_CHECK_DEBUG_TOKEN` environment variable

## Services covered

- Firestore: enforced
- Storage: enforced
- Cloud Functions: enforced via Firebase Console (not via `enforceAppCheck` flag in function code — that flag is deprecated for v2 functions)
- Remote Config: enforced

## ADR

ADR-V15-APP-CHECK-ENFORCE in `.claude/team/decisions.md`
