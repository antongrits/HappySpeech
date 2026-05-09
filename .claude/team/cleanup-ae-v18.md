# Block AE v18 — Simulator Cleanup

## Date: 2026-05-09

## Pre-cleanup
- Disk: 39 GB free (81% used, 228 GB total)
- DerivedData: 1.5 MB (уже почти пустой — HappySpeech-* не найден)
- CoreSimulator: 3.9 GB

## Actions
- xcrun simctl shutdown all
- xcrun simctl erase all (очищает данные, оставляет устройства)
- xcrun simctl delete unavailable
- DerivedData cleanup (HappySpeech-*, ModuleCache.noindex)
- Caches cleanup (com.apple.dt.Xcode, org.swift.swiftpm)
- Re-boot iPhone SE (3rd generation)

## Post-cleanup
- Disk: 41 GB free (80% used) — delta +2 GB
- DerivedData: 1.5 MB
- CoreSimulator: 567 MB (delta -3.3 GB)
- iPhone SE (3rd generation): Booted (4166BD56-19F6-4BE6-AA6C-5E4A0F3F6A32)
- Project ready для clean install
