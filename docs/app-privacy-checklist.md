# App Privacy Checklist — HappySpeech

Дата обновления: 2026-04-29  
Статус: Актуально для App Store Connect (Kids Category 5–8 лет)

---

## Сводка: данные не используются для отслеживания

HappySpeech не использует трекинговые SDK. Нет рекламы. Нет аналитических сервисов третьих сторон.

---

## Данные, которые НЕ собираются

- Данные о местоположении
- Контакты
- Здоровье (только опциональная запись через HealthKit — только с согласия родителя)
- Финансовые данные
- Данные чувствительных документов
- История браузера
- Поисковые запросы
- Данные о подписках на приложения
- Диагностические данные (MetricKit — только локальные crash reports)
- Данные об использовании (нет Firebase Analytics, нет Amplitude)

---

## Данные, связанные с пользователем (опционально, только при входе)

| Тип | Описание | Цель | Трекинг? |
|-----|----------|------|----------|
| Email родителя | Firebase Auth (опциональный вход) | Синхронизация прогресса | Нет |
| Имя ребёнка | Realm / Firestore | Персонализация UX | Нет |
| Возраст ребёнка | Realm / Firestore | Адаптивный план | Нет |

---

## Данные, НЕ связанные с пользователем

| Тип | Описание | Цель |
|-----|----------|------|
| Прогресс сессий | Анонимный Realm — локально | Алгоритм повторений |
| Произношение (MFCC) | Только локальная обработка, не хранится | Оценка Core ML |
| Голосовые записи | Только в памяти при активном упражнении | ASR WhisperKit |

Голосовые данные НИКОГДА не отправляются на серверы. Распознавание речи — полностью на устройстве (WhisperKit).

---

## Отслеживание (Tracking)

**NONE** — нет трекинга ни в каком виде.

`NSUserTrackingUsageDescription` — отсутствует в Info.plist намеренно (Kids Category).

---

## Encryption

`ITSAppUsesNonExemptEncryption = false`  
Приложение использует только стандартное iOS шифрование (HTTPS/TLS через URLSession).  
Кастомное или военное шифрование не применяется.

---

## Kids Category compliance (Apple 5.1.4)

- Нет рекламы третьих сторон
- Нет аналитики третьих сторон
- Нет ссылок на внешние сайты без Parental Gate
- Нет In-App Purchases
- Нет возможности создания аккаунта ребёнком напрямую
- Все внешние ссылки проходят через `ParentalGate` (math problem)
- Возрастная группа: 5–8 лет (App Store Connect: Kids 5 and Under / 6-8 category)

---

## Ответы для App Store Connect Privacy Nutrition Label

### Data not collected
Выбрать "We do not collect data from this app" если родитель не вошёл.

### Data linked to user (если вошёл)
- Contact Info → Email Address → Analytics / App Functionality (not tracking)

### Data not linked to user
- Usage Data → Product Interaction → нет (не собираем)
- Diagnostics → Crash Data → нет (нет Crashlytics)
