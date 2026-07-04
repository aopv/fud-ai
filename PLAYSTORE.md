# Play Store Listing

Google Play Console listing copy for Fud AI Android (current: v3.0 / versionCode 27). Each field is in a code block for easy copy-paste. Char counts are tracked because Play Console enforces hard caps and silently truncates anything over.

**Where to paste each field in Play Console:**
- App name / Short description / Full description → Grow → Store presence → **Main store listing** (default English) and Grow → Store presence → **Custom store listings** → Manage translations (per-language overrides)
- What's new → **Releases → Production / Closed testing → Create new release → Release notes** field (paste the entire `<lang-tag>` block; Play Console parses tags automatically)

---

## 1. App Name

**30 char hard cap per language.** Brand name stays as `Fud AI` untranslated; the descriptor after the dash is what gets localized. English-only on Play Console — non-English Play Store browsers see the English source as fallback.

### English (en-US) — 24 chars
```
Fud AI - Calorie Tracker
```

---

## 2. Short Description

**80 char hard cap per language. Cannot include price/promotion keywords ("free", "discount", "sale", "best", "#1", etc.) — Play Console will block promotion of the listing.** Live Play Store currently has "Snap, speak, or type a meal. AI logs the calories. Free & open source." which triggers the warning; replacement below drops "Free" while keeping the same rhythm. English-only on Play Console — non-English Play Store browsers see the English source as fallback.

### English (en-US) — 63 chars
```
Snap, speak, or type a meal. AI logs the calories. Open source.
```

---

## 3. Full Description

**4000 char hard cap per language.** This is the long-form "About this app" copy. English-only on Play Console — non-English Play Store browsers see the English source as fallback (deliberate decision; the in-app UI is fully translated via per-locale `values-{lang}/strings.xml` so users still get a localized experience once installed).

### English (en-US)
```
Fud AI makes calorie tracking effortless with AI-powered food recognition. Snap a photo, scan a barcode, speak it, or type it — get instant nutrition: calories, protein, carbs, fats, vitamins, minerals, and more.

NEW in v3.0: a Workouts tab with an 873-exercise library — photos, primary/secondary muscle and equipment filters, search, sort, and detail pages. Refreshed onboarding, and Adaptive Goals + Energy Burn on by default for new installs. A small banner ad now keeps Fud AI free.

Open source, privacy-first. Bring your own API key.

HOW TO USE
1) Set up your profile with goals + body stats
2) Snap, scan, speak, type, or manually enter a meal — review/edit nutrition, preview What if?, and save
3) Ask Coach anything: trends, predictions, advice
4) Track progress on charts and home screen widgets

11 WAYS TO LOG A MEAL
• Photo — AI identifies food and returns nutrition
• Photo + Note — add context before AI analysis
• Photo + Photo — combine two images in one analysis
• Nutrition Label — scan package nutrition facts
• Barcode — look up packaged foods with Open Food Facts
• From Photos — analyze an existing image
• From Photos + Note — add context to a library photo
• Voice — 6 STT engines with language selection
• Text — describe in plain language, AI parses it
• Manual Entry — name + calories + macros + meal type
• Saved Meals — re-log recents, frequent meals, and favorites
• Copy from Day — copy meals from another date

BODY COMPOSITION TRACKING
Log body fat %, set a goal %, and see it alongside weight on Progress. Health Connect can auto-import compatible samples.

13 AI PROVIDERS
Google Gemini, OpenAI, Claude, xAI Grok, Groq, OpenRouter, Together, Hugging Face, Fireworks, DeepInfra, Mistral, Ollama, or any OpenAI-compatible endpoint. Switch anytime. Keys are stored encrypted.

6 SPEECH-TO-TEXT ENGINES
Native Android, Gemini, OpenAI Whisper, Groq, Deepgram, AssemblyAI. Choose Provider Auto, Use Device Language, or a fixed language.

COACH
Multi-turn chat sees your profile, weight, body fat, and food log. Ask "what was my weight in March?" or "how's my protein this week?" — Coach pulls the date range it needs. You can attach a camera or photo-library image.

REVIEW BEFORE LOGGING
Unlock Nutrition to correct calories, macros, and detailed nutrients before saving; serving changes then scale from your edits. What if? previews today's macro impact and can ask AI for a suggestion.

WORKOUTS
Browse 873 exercises with photos. Filter by primary/secondary muscle and equipment, search, sort, and open per-exercise detail pages.

PERSONALIZED GOALS
BMR via Katch-McArdle or Mifflin-St Jeor. TDEE with 6 activity levels. Auto-calculated calorie + protein + carbs + fat targets — fully customizable. Activity Level shows protein in g/kg body weight, or the equivalent lean-mass multiplier when body fat is set.

OPTIONAL NUTRIENT GOALS
Set expanded nutrient goals separately from the macro calculator: fiber, sugar, fats, cholesterol, sodium, potassium, calcium, iron, magnesium, zinc, vitamins, folate, omega-3, and more when available. Use AI Estimate from your profile, or set goals manually. Home cards can show macros or selected detailed nutrients.

PROGRESS
Unified Weight / Body Fat chart with current, goal, net change, average, trend lines, and goal overlays. Calorie trend vs goal. Macro averages over 1W, 1M, 3M, 6M, 1Y, All Time.

WIDGETS
Calorie and nutrient widgets refresh when you log a meal.

15 LANGUAGES
Auto-selected by phone language: English, Spanish, French, German, Italian, Portuguese (BR), Dutch, Russian, Japanese, Korean, Chinese, Hindi, Arabic, Romanian, Azerbaijani.

PRIVACY FIRST
No account, no sign-in, no cloud sync, no analytics, no behavioral tracking. Your data stays on your device; a single small banner ad keeps the app free. MIT licensed.

HEALTH CONNECT
Sync nutrition, weight, and body fat with permission reconciliation and backfill support. Edits and deletes sync back where supported.

NOTE: Not medical advice. Estimates are AI-generated; consult a healthcare professional before significant diet changes.

Terms: https://fud-ai.app/terms.html
Privacy: https://fud-ai.app/privacy.html
Source: https://github.com/apoorvdarshan/fud-ai

```

### Other 14 languages
English-only on Play Console — non-English Play Store browsers (ar, az-AZ, de-DE, es-ES, fr-FR, hi-IN, it-IT, ja-JP, ko-KR, nl-NL, pt-BR, ro, ru-RU, zh-CN) see the English source as fallback. The in-app UI itself is fully translated into all 14 locales via per-locale `values-{lang}/strings.xml`, so the localization gap is only on the Play Store listing surface, not inside the app.

---

## 4. What's New (v3.0 / versionCode 27)

**500 char hard cap per language.** Paste the entire block below into Play Console's "Release notes" field — it auto-routes each `<lang-tag>` block to the matching locale.

```
<en-US>
• New Workouts tab: browse 873 exercises with photos, muscle and equipment filters, search, sort, and detail pages.
• Adaptive Goals and Energy Burn have graduated from Experimental and are on by default for new installs.
• Refreshed onboarding with a quick feature tour.
• A small banner ad now keeps Fud AI free.
</en-US>

<ar>
• علامة تبويب جديدة للتمارين: تصفّح 873 تمرينًا مع الصور وفلاتر العضلات والمعدات والبحث والفرز وصفحات التفاصيل.
• تخرّجت ميزتا الأهداف التكيفية وحرق الطاقة من المرحلة التجريبية وأصبحتا مفعّلتين افتراضيًا للتثبيتات الجديدة.
• تجربة إعداد أولي محدّثة مع جولة سريعة على الميزات.
• إعلان بانر صغير يُبقي Fud AI مجانيًا الآن.
</ar>

<az-AZ>
• Yeni Məşqlər tabı: şəkillər, əzələ və avadanlıq filtrləri, axtarış, çeşidləmə və detal səhifələri ilə 873 məşqə baxın.
• Adaptiv Məqsədlər və Enerji Sərfi eksperimental mərhələdən çıxdı və yeni quraşdırmalar üçün defolt olaraq aktivdir.
• Sürətli funksiya turu ilə yenilənmiş tanışlıq.
• Kiçik banner reklamı indi Fud AI-ni pulsuz saxlayır.
</az-AZ>

<de-DE>
• Neuer Workouts-Tab: 873 Übungen mit Fotos, Muskel- und Equipment-Filtern, Suche, Sortierung und Detailseiten.
• Adaptive Ziele und Energieverbrauch sind nicht mehr experimentell und bei Neuinstallationen standardmäßig aktiv.
• Überarbeitetes Onboarding mit kurzer Funktionstour.
• Eine kleine Banneranzeige hält Fud AI jetzt kostenlos.
</de-DE>

<es-ES>
• Nueva pestaña Entrenamientos: explora 873 ejercicios con fotos, filtros de músculo y equipamiento, búsqueda, orden y páginas de detalle.
• Objetivos adaptativos y Quema de energía dejan de ser experimentales y vienen activados por defecto en instalaciones nuevas.
• Incorporación renovada con un breve recorrido por las funciones.
• Un pequeño banner publicitario mantiene ahora Fud AI gratis.
</es-ES>

<fr-FR>
• Nouvel onglet Entraînements : parcourez 873 exercices avec photos, filtres par muscle et équipement, recherche, tri et pages de détail.
• Objectifs adaptatifs et Énergie brûlée sortent de l'expérimental et sont activés par défaut pour les nouvelles installations.
• Intégration repensée avec un rapide tour des fonctionnalités.
• Une petite bannière publicitaire garde désormais Fud AI gratuit.
</fr-FR>

<hi-IN>
• नया Workouts टैब: फ़ोटो, मांसपेशी और उपकरण फ़िल्टर, खोज, सॉर्ट और विवरण पेजों के साथ 873 व्यायाम ब्राउज़ करें।
• Adaptive Goals और Energy Burn अब प्रयोगात्मक नहीं हैं और नए इंस्टॉल पर डिफ़ॉल्ट रूप से चालू हैं।
• तेज़ फ़ीचर टूर के साथ नया ऑनबोर्डिंग।
• एक छोटा बैनर विज्ञापन अब Fud AI को मुफ़्त रखता है।
</hi-IN>

<it-IT>
• Nuova scheda Allenamenti: sfoglia 873 esercizi con foto, filtri per muscolo e attrezzatura, ricerca, ordinamento e pagine di dettaglio.
• Obiettivi adattivi ed Energia bruciata escono dalla fase sperimentale e sono attivi di default sulle nuove installazioni.
• Onboarding rinnovato con un rapido tour delle funzioni.
• Un piccolo banner pubblicitario ora mantiene Fud AI gratuito.
</it-IT>

<ja-JP>
• 新しいワークアウトタブ：写真、筋肉・器具フィルター、検索、並べ替え、詳細ページ付きの873種目をブラウズできます。
• アダプティブ目標とエネルギー消費が実験的機能を卒業し、新規インストールではデフォルトでオンになりました。
• クイック機能ツアー付きの新しいオンボーディング。
• 小さなバナー広告でFud AIは今後も無料です。
</ja-JP>

<ko-KR>
• 새로운 운동 탭: 사진, 근육·장비 필터, 검색, 정렬, 상세 페이지와 함께 873가지 운동을 둘러보세요.
• 적응형 목표와 에너지 소모가 실험 단계를 졸업하고 새 설치에서 기본으로 켜집니다.
• 빠른 기능 둘러보기가 포함된 새 온보딩.
• 작은 배너 광고로 Fud AI는 계속 무료입니다.
</ko-KR>

<nl-NL>
• Nieuw Workouts-tabblad: blader door 873 oefeningen met foto's, spier- en materiaalfilters, zoeken, sorteren en detailpagina's.
• Adaptieve doelen en Energieverbruik zijn niet langer experimenteel en staan standaard aan bij nieuwe installaties.
• Vernieuwde onboarding met een korte functietour.
• Een kleine banneradvertentie houdt Fud AI nu gratis.
</nl-NL>

<pt-BR>
• Nova aba Treinos: navegue por 873 exercícios com fotos, filtros de músculo e equipamento, busca, ordenação e páginas de detalhes.
• Metas adaptativas e Queima de energia saíram da fase experimental e vêm ativadas por padrão em novas instalações.
• Integração renovada com um tour rápido pelos recursos.
• Um pequeno banner de anúncio agora mantém o Fud AI gratuito.
</pt-BR>

<ro>
• Filă nouă Antrenamente: răsfoiește 873 de exerciții cu fotografii, filtre după mușchi și echipament, căutare, sortare și pagini de detalii.
• Obiectivele adaptive și Energia consumată au ieșit din faza experimentală și sunt activate implicit la instalările noi.
• Onboarding reîmprospătat, cu un tur rapid al funcțiilor.
• Un mic banner publicitar menține acum Fud AI gratuit.
</ro>

<ru-RU>
• Новая вкладка «Тренировки»: 873 упражнения с фото, фильтрами по мышцам и оборудованию, поиском, сортировкой и страницами деталей.
• «Адаптивные цели» и «Расход энергии» вышли из экспериментального статуса и включены по умолчанию для новых установок.
• Обновлённый онбординг с коротким обзором функций.
• Небольшой рекламный баннер теперь позволяет Fud AI оставаться бесплатным.
</ru-RU>

<zh-CN>
• 全新“锻炼”标签页：浏览 873 个动作，配照片、肌群和器械筛选、搜索、排序和详情页。
• 自适应目标和能量消耗已结束实验阶段，新安装默认开启。
• 全新引导流程，附快速功能导览。
• 一条小横幅广告让 Fud AI 保持免费。
</zh-CN>
```

---

## 5. Categorization

```
App category: Health & Fitness
Tags: Calorie tracker, Nutrition, AI, Food tracker
```

## 6. Contact details

```
Email: apoorv@fud-ai.app
Phone: (omit — optional, US-only enforcement)
Website: https://fud-ai.app
Privacy policy: https://fud-ai.app/privacy.html
```

## 7. App content declarations

These are one-time setup in Play Console → Policy → App content. Don't drift from these answers across submissions:

- **Privacy policy URL**: https://fud-ai.app/privacy.html
- **App access**: All functionality available without restrictions
- **Ads**: Yes — flip the "contains ads" declaration before releasing v3.0. The app shows a single AdMob banner at the top of each tab.
- **Content rating**: Everyone (E)
- **Target audience**: 13+
- **News app**: No
- **COVID-19 contact tracing**: No
- **Data safety**: App data processing is on-device; the app itself collects nothing. From v3.0 the Google Mobile Ads SDK collects the device advertising ID and ad-interaction data, shared with Google for advertising — declare "Device or other IDs → Collected/Shared, Advertising" (plus AdMob's documented App activity/interactions entries) per Google's AdMob data-safety guidance. API keys stored in EncryptedSharedPreferences. Encryption in transit (HTTPS). User can request deletion via in-app "Delete All Data" — no server data exists.
- **Government app**: No
- **Financial features**: No
- **Health features**: Yes — fitness/nutrition tracking. Local-only.
