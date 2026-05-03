# Firebase Storage — Content Packs

## Bucket

`happyspeech-dfd95.firebasestorage.app`

Region: us-central1 (выбран при создании Firebase проекта; не может быть изменён).

## Storage Paths

### Seasonal Content Packs (прямой доступ)
```
content-packs/seasonal/halloween-2027.json
content-packs/seasonal/new-year-2028.json     (планируется)
content-packs/seasonal/easter-2028.json       (планируется)
```

### ContentPackDownloadService paths (iOS SDK)
```
content_packs/{packId}/pack.json
content_packs/{packId}/audio/{wordId}.m4a     (будущее)
```

## Загруженные паки (Phase 2.7-C v15, 2026-05-04)

| Pack ID | Path | Size | Status |
|---------|------|------|--------|
| halloween_2027 | content_packs/halloween_2027/pack.json | 14 KB | Uploaded |
| halloween_2027 | content-packs/seasonal/halloween-2027.json | 14 KB | Uploaded |

## iOS Integration

`ContentPackDownloadService.downloadPack(id: "halloween_2027")` скачивает из
`content_packs/halloween_2027/pack.json` в `Documents/ContentPacks/halloween_2027/pack.json`.

Кэш: 7 дней. Resumable download. Progress через `AsyncStream<Double>`.

## Загрузка новых паков

```bash
# Через REST API (при отсутствии gsutil/gcloud)
ACCESS_TOKEN=$(python3 -c "import json; print(json.load(open('~/.config/configstore/firebase-tools.json'))['tokens']['access_token'])")
BUCKET="happyspeech-dfd95.firebasestorage.app"
OBJECT="content_packs/new_pack/pack.json"
ENCODED=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$OBJECT', safe=''))")

curl -X POST \
  "https://storage.googleapis.com/upload/storage/v1/b/${BUCKET}/o?uploadType=media&name=${ENCODED}" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  --data-binary @pack.json
```

## Storage Rules

Правила в `storage.rules`:
- Аутентифицированные пользователи: read content-packs/
- Родитель: write audio/recordings/{uid}/
- Публичная запись: запрещена
