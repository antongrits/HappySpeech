# Политика конфиденциальности / Privacy Policy

**Версия:** 1.0
**Дата вступления в силу:** 2026-04-23

---

## Русская версия

### 1. Введение

Настоящая Политика конфиденциальности описывает, как приложение HappySpeech («Приложение», «мы», «нас») обрабатывает персональные данные пользователей. Мы уважаем вашу частную жизнь и частную жизнь ваших детей и берём на себя обязательство обрабатывать данные честно, прозрачно и только в тех целях, которые указаны ниже.

HappySpeech — логопедическое приложение для детей 5–8 лет. Приложение ориентировано прежде всего на детей как конечных пользователей. Родители или законные опекуны управляют аккаунтом и дают согласие на обработку данных от имени ребёнка.

### 2. Оператор данных

Оператором персональных данных является:

**Антон Гриц**
Индивидуальный разработчик
Email: antongric558@gmail.com

По всем вопросам, связанным с обработкой данных, обращайтесь на указанный email с пометкой «HappySpeech Privacy».

### 3. Какие данные мы собираем и зачем

#### 3.1 Данные профиля ребёнка
- **Что:** имя ребёнка, возраст, пол (по желанию).
- **Зачем:** персонализация обращения маскота Ляли, адаптация контента под возраст, корректная работа адаптивного планировщика занятий.
- **Где хранится:** локально (Realm на устройстве) + Firebase Firestore (синхронизация при наличии интернета).

#### 3.2 Данные об аккаунте родителя / специалиста
- **Что:** email-адрес, метод аутентификации (Email+Password, Google Sign-in или анонимный вход через Firebase Auth).
- **Зачем:** аутентификация, привязка прогресса к аккаунту, восстановление доступа.
- **Где хранится:** Firebase Authentication (Google LLC).

#### 3.3 Прогресс и результаты сессий
- **Что:** дата и время занятия, идентификатор упражнения, оценка произношения (числовая метрика 0–100), количество попыток, флаг завершения.
- **Зачем:** отслеживание динамики, формирование рекомендаций адаптивным планировщиком, отчёты для специалиста-логопеда.
- **Где хранится:** локально (Realm) + Firebase Firestore.

#### 3.4 Голосовые записи
- **Что:** короткие аудиофрагменты (до 10 секунд) произношения ребёнка во время упражнений.
- **Зачем:** оценка произношения моделью PronunciationScorer и распознавание речи WhisperKit — **исключительно на устройстве (on-device)**. Голосовые записи **не передаются** на сервер, не хранятся после завершения упражнения и не покидают оперативную память устройства.
- **Где хранится:** только в оперативной памяти устройства в ходе сессии. После завершения упражнения автоматически удаляются.

#### 3.5 Метаданные упражнений
- **Что:** идентификатор шаблона игры, тип звука (С, Ш, Р и т.д.), этап работы.
- **Зачем:** аналитика прогресса внутри приложения без передачи сторонним сервисам.
- **Где хранится:** локально (Realm) + Firebase Firestore.

#### 3.6 Данные, которые мы НЕ собираем
- Геолокация.
- Контакты телефонной книги.
- Фото из библиотеки устройства.
- Идентификатор для рекламодателей (IDFA).
- Данные о поведении для рекламных целей.
- Какие-либо биометрические данные за пределами on-device ML.

### 4. Правовое основание обработки

- **GDPR (ЕС/ЕЭП), ст. 6(1)(b):** исполнение договора (предоставление функционала Приложения).
- **GDPR, ст. 6(1)(f):** законный интерес оператора в обеспечении работы сервиса.
- **GDPR, ст. 8 + ст. 6(1)(a):** согласие родителя/опекуна при регистрации ребёнка младше 16 лет.
- **ФЗ-152 «О персональных данных» (РФ), ст. 6:** согласие субъекта или его законного представителя.
- **COPPA (США):** мы получаем верифицируемое родительское согласие (verifiable parental consent) до сбора любых данных о детях младше 13 лет.

### 5. Хранение данных

| Тип данных | Местонахождение | Шифрование |
|---|---|---|
| Профиль ребёнка | Realm (устройство) + Firestore | AES-256 at-rest (Realm); TLS 1.3 in-transit |
| Аккаунт родителя | Firebase Auth | Управляется Google LLC |
| Прогресс / метаданные | Realm (устройство) + Firestore | AES-256 / TLS 1.3 |
| Голосовые записи | ОЗУ устройства (только на время упражнения) | Не хранятся |

Данные в Firestore не передаются в другие страны за пределы дата-центров Google LLC (EU/US) без дополнительного уведомления.

### 6. Передача данных третьим лицам

Мы передаём данные **только Firebase (Google LLC)** в качестве технического обработчика (data processor). Google LLC действует на основании Соглашения об обработке данных (DPA), соответствующего требованиям GDPR и SCCs.

Мы **не продаём**, **не передаём** и **не предоставляем** ваши данные рекламным сетям, брокерам данных или иным третьим лицам.

### 7. Особая защита детей (COPPA / ФЗ-152)

HappySpeech предназначено для детей 5–8 лет. Мы применяем усиленный режим защиты детских данных:

- **Верифицируемое родительское согласие.** До создания профиля ребёнка родитель или опекун проходит отдельный экран подтверждения согласия (onboarding). Аккаунт активируется только после явного принятия условий.
- **Нет сбора данных без согласия родителя.** Ребёнок не может самостоятельно зарегистрироваться или изменить настройки конфиденциальности.
- **Право родителя на просмотр.** Родитель может в любой момент просмотреть все данные профиля ребёнка в разделе «Профиль» → «Настройки данных».
- **Право родителя на удаление.** Родитель может удалить профиль ребёнка и все связанные данные из Приложения или отправив запрос на antongric558@gmail.com. Удаление выполняется в течение 30 дней.
- **Нет поведенческой рекламы.** Данные детей не используются ни в каких рекламных целях.
- **Нет передачи данных третьим лицам** в маркетинговых или аналитических целях.
- **Нет внешних ссылок без родительского контроля.** Все внешние ссылки закрыты за «родительским воротником» (parental gate) с проверочным вопросом.

Для детей младше 14 лет (ФЗ-152, ст. 9) согласие на обработку данных даёт родитель или законный опекун.
Для детей младше 13 лет (COPPA) мы применяем процедуру verifiable parental consent согласно 16 CFR Part 312.

### 8. Права пользователя

В соответствии с GDPR (ст. 15–22) и ФЗ-152 (ст. 14) вы имеете право:

- **Доступ:** получить копию всех персональных данных, которые мы храним о вас или вашем ребёнке.
- **Исправление:** потребовать исправления неточных данных.
- **Удаление («право быть забытым»):** потребовать удаления всех данных.
- **Ограничение обработки:** потребовать приостановки обработки при оспаривании точности данных.
- **Переносимость:** получить данные в машиночитаемом формате (JSON/CSV).
- **Возражение:** возразить против обработки на основании законного интереса.
- **Отзыв согласия:** отозвать ранее данное согласие в любой момент. Отзыв не влияет на законность обработки до момента отзыва.

Для реализации прав — email: antongric558@gmail.com, тема «HappySpeech Data Request». Срок ответа: 30 дней.

### 9. Сроки хранения

- **Профиль ребёнка и прогресс:** хранятся до удаления аккаунта или до запроса на удаление.
- **Аккаунт родителя:** хранится до удаления аккаунта.
- **Голосовые записи:** не хранятся (удаляются из ОЗУ сразу после завершения упражнения).
- **Анонимный аккаунт (Firebase Auth anonymous):** данные хранятся до явного удаления или до истечения 12 месяцев бездействия.

После удаления аккаунта данные из Firestore удаляются в течение 30 дней, из систем резервного копирования Google — в срок согласно политике Google LLC.

### 10. Безопасность

- Данные на устройстве хранятся в зашифрованной базе Realm (AES-256).
- Передача данных осуществляется только по TLS 1.3.
- Firebase App Check защищает API от несанкционированного доступа.
- Доступ к базе Firestore ограничен правилами безопасности: пользователь видит только свои данные.
- Голосовые данные не покидают устройство ни при каких условиях.

### 11. Аналитика и cookies

Приложение **не использует** сторонние аналитические SDK (Firebase Analytics, Mixpanel, Amplitude и т.д.).
Приложение **не использует** рекламные идентификаторы.
Приложение **не устанавливает** cookies.

Внутренняя аналитика прогресса ребёнка — исключительно локальная, используется только для отображения внутри Приложения.

### 12. Изменения в политике

Мы оставляем за собой право изменять настоящую Политику. При существенных изменениях мы уведомим вас через push-уведомление или через экран при следующем входе в Приложение. Продолжение использования Приложения после уведомления означает принятие новой редакции.

### 13. Контакты оператора

По вопросам конфиденциальности, запросам на доступ или удаление данных:

**Email:** antongric558@gmail.com
**Тема письма:** HappySpeech Privacy

Мы ответим в течение 30 дней с момента получения запроса.

### 14. Дата вступления в силу

Настоящая Политика вступает в силу **23 апреля 2026 года**.

---

## English version

### 1. Introduction

This Privacy Policy explains how the HappySpeech application ("App", "we", "us") processes personal data of users. We are committed to handling data fairly, transparently, and only for the purposes described below.

HappySpeech is a speech therapy app for children aged 5–8 years. Children are the primary end-users of the App. Parents or legal guardians manage the account and provide consent on behalf of the child.

### 2. Data Controller

The data controller is:

**Anton Grits**
Individual developer
Email: antongric558@gmail.com

For any privacy-related questions, contact us at the email above with the subject line "HappySpeech Privacy".

### 3. What Data We Collect and Why

#### 3.1 Child Profile Data
- **What:** child's name, age, gender (optional).
- **Why:** to personalize the mascot Lyalya's interactions, adapt content to the child's age, and enable the adaptive lesson planner.
- **Where stored:** locally on-device (Realm) + Firebase Firestore (synced when internet is available).

#### 3.2 Parent / Specialist Account Data
- **What:** email address, authentication method (Email+Password, Google Sign-in, or anonymous sign-in via Firebase Auth).
- **Why:** authentication, linking progress to the account, account recovery.
- **Where stored:** Firebase Authentication (Google LLC).

#### 3.3 Session Progress and Results
- **What:** session date and time, exercise identifier, pronunciation score (numeric metric 0–100), number of attempts, completion flag.
- **Why:** to track progress, generate recommendations via the adaptive planner, and provide reports for speech-language pathologists.
- **Where stored:** locally (Realm) + Firebase Firestore.

#### 3.4 Voice Recordings
- **What:** short audio fragments (up to 10 seconds) of the child's speech during exercises.
- **Why:** on-device pronunciation scoring (PronunciationScorer model) and speech recognition (WhisperKit) — **processed entirely on the device**. Voice recordings are **never transmitted** to any server, are not stored after the exercise ends, and never leave device memory.
- **Where stored:** device RAM only, for the duration of the exercise. Automatically discarded when the exercise ends.

#### 3.5 Exercise Metadata
- **What:** game template identifier, target sound type (S, Sh, R, etc.), stage of work.
- **Why:** in-app progress analytics, never shared with third parties.
- **Where stored:** locally (Realm) + Firebase Firestore.

#### 3.6 Data We Do NOT Collect
- Geolocation.
- Device contacts.
- Photos from device library.
- Advertising identifier (IDFA).
- Behavioral data for advertising purposes.
- Any biometric data beyond on-device ML processing.

### 4. Legal Basis for Processing

- **GDPR, Art. 6(1)(b):** performance of a contract (providing App functionality).
- **GDPR, Art. 6(1)(f):** legitimate interest of the controller in operating the service.
- **GDPR, Art. 8 + Art. 6(1)(a):** parental/guardian consent when registering a child under 16.
- **Russian Federal Law No. 152-FZ:** consent of the data subject or their legal representative.
- **COPPA (US):** we obtain verifiable parental consent prior to collecting any personal information from children under 13.

### 5. Data Storage

| Data Type | Location | Encryption |
|---|---|---|
| Child profile | Realm (device) + Firestore | AES-256 at-rest; TLS 1.3 in-transit |
| Parent account | Firebase Auth | Managed by Google LLC |
| Progress / metadata | Realm (device) + Firestore | AES-256 / TLS 1.3 |
| Voice recordings | Device RAM only (exercise duration) | Not stored |

Firestore data is not transferred outside Google LLC data centers (EU/US) without additional notice.

### 6. Data Sharing with Third Parties

We share data **only with Firebase (Google LLC)** as a technical data processor. Google LLC operates under a Data Processing Agreement (DPA) compliant with GDPR and Standard Contractual Clauses (SCCs).

We **do not sell**, **share**, or **provide** your data to advertising networks, data brokers, or any other third parties.

### 7. Children's Privacy Protections (COPPA / Russian Law)

HappySpeech is designed for children aged 5–8. We apply enhanced protections for children's data:

- **Verifiable Parental Consent.** Before a child profile is created, the parent or guardian completes a dedicated consent screen during onboarding. The account is activated only after explicit acceptance of these terms.
- **No data collection without parental consent.** A child cannot independently register or change privacy settings.
- **Parental right to review.** Parents can review all child profile data at any time via Profile → Data Settings.
- **Parental right to delete.** Parents can delete the child profile and all associated data from within the App or by emailing antongric558@gmail.com. Deletion is completed within 30 days.
- **No behavioral advertising.** Children's data is not used for any advertising purpose.
- **No third-party sharing** for marketing or analytics purposes.
- **No external links without parental gate.** All external links require a parental gate verification before proceeding.

For children under 13 (COPPA, 16 CFR Part 312), we apply verifiable parental consent procedures before any personal data collection.

### 8. User Rights

Under GDPR (Art. 15–22) and Russian Federal Law No. 152-FZ (Art. 14), you have the right to:

- **Access:** receive a copy of all personal data we hold about you or your child.
- **Rectification:** request correction of inaccurate data.
- **Erasure ("right to be forgotten"):** request deletion of all data.
- **Restriction of processing:** request suspension of processing while disputing accuracy.
- **Data portability:** receive your data in a machine-readable format (JSON/CSV).
- **Objection:** object to processing based on legitimate interest.
- **Withdrawal of consent:** withdraw previously given consent at any time without affecting the lawfulness of prior processing.

To exercise your rights: email antongric558@gmail.com, subject "HappySpeech Data Request". Response within 30 days.

### 9. Data Retention

- **Child profile and progress:** retained until account deletion or deletion request.
- **Parent account:** retained until account deletion.
- **Voice recordings:** not retained; discarded from device RAM immediately after each exercise.
- **Anonymous Firebase accounts:** retained until explicit deletion or after 12 months of inactivity.

After account deletion, Firestore data is removed within 30 days; Google backup systems follow Google LLC's own retention policy.

### 10. Security

- On-device data is stored in an encrypted Realm database (AES-256).
- All data transmission uses TLS 1.3.
- Firebase App Check protects the API from unauthorized access.
- Firestore security rules restrict each user to their own data only.
- Voice data never leaves the device under any circumstances.

### 11. Analytics and Cookies

The App does **not use** any third-party analytics SDKs (Firebase Analytics, Mixpanel, Amplitude, etc.).
The App does **not use** advertising identifiers.
The App does **not set** any cookies.

Internal progress analytics are entirely local and are displayed only within the App.

### 12. Changes to This Policy

We reserve the right to update this Policy. For material changes, we will notify you via push notification or an in-app prompt at next login. Continued use of the App after notification constitutes acceptance of the updated Policy.

### 13. Contact

For privacy questions, data access, or deletion requests:

**Email:** antongric558@gmail.com
**Subject:** HappySpeech Privacy

We will respond within 30 days of receiving your request.

### 14. Effective Date

This Privacy Policy is effective as of **April 23, 2026**.
