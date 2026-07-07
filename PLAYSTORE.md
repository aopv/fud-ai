# Play Store Listing

Google Play Console listing copy for Fud AI Android (current: v3.0.2 / versionCode 29). Each field is in a code block for easy copy-paste. Char counts are tracked because Play Console enforces hard caps and silently truncates anything over.

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

NEW in v3.0: a Workouts tab with an 873-exercise library, a Home redesign with a speedometer calorie gauge (widgets match), Coach by voice, meal links, diary export, AI meal reprocessing, 10 new theme colors, and automatic restore of your data from Health Connect after a reinstall. A small banner ad now keeps Fud AI free.

Open source, privacy-first. Bring your own API key.

HOW TO USE
1) Set up your profile with goals + body stats
2) Snap, scan, speak, type, or manually enter a meal — review/edit nutrition, preview What if?, and save
3) Ask Coach anything: trends, predictions, advice
4) Track progress on charts and home screen widgets

11 WAYS TO LOG A MEAL
• Photo — AI identifies food
• Photo + Note — add context
• Photo + Photo — two images, one analysis
• Nutrition Label — scan package nutrition facts
• Barcode — Open Food Facts lookup
• From Photos — analyze an existing image
• From Photos + Note
• Voice — 6 STT engines
• Text — describe it, AI parses it
• Manual Entry
• Saved Meals — recents, frequent, favorites
• Copy from Day — copy meals from another date

BODY COMPOSITION TRACKING
Log body fat %, set a goal %, and see it alongside weight on Progress. Health Connect can auto-import compatible samples.

13 AI PROVIDERS
Gemini, OpenAI, Claude, Grok, Groq, OpenRouter, Together, Hugging Face, Fireworks, DeepInfra, Mistral, Ollama, or any OpenAI-compatible endpoint. Keys are stored encrypted.

6 SPEECH-TO-TEXT ENGINES
Native Android, Gemini, OpenAI Whisper, Groq, Deepgram, AssemblyAI. Choose Provider Auto, Use Device Language, or a fixed language.

COACH
Multi-turn chat sees your profile, weight, body fat, and food log. Ask "what was my weight in March?" — Coach pulls the date range it needs. You can attach an image.

REVIEW BEFORE LOGGING
Unlock Nutrition to correct calories, macros, and detailed nutrients before saving; serving changes then scale from your edits. What if? previews today's macro impact and can ask AI for a suggestion.

WORKOUTS
Browse 873 exercises with photos. Filter by primary/secondary muscle and equipment, search, sort, and open per-exercise detail pages.

PERSONALIZED GOALS
BMR via Katch-McArdle or Mifflin-St Jeor. TDEE with 6 activity levels. Auto-calculated calorie + protein + carbs + fat targets — fully customizable. Activity Level shows protein in g/kg.

OPTIONAL NUTRIENT GOALS
Set expanded nutrient goals separately from the macro calculator — fiber, sugar, fats, sodium, vitamins, minerals, and more. Use AI Estimate or set them manually. Home cards can show macros or selected nutrients.

PROGRESS
Unified Weight / Body Fat chart with goal, net change, average, and trend lines. Calorie trend vs goal. Macro averages from 1W to All Time.

WIDGETS
Calorie and nutrient widgets in the Home speedometer style, drawn at each widget's true size. They refresh the moment you log a meal.

15 LANGUAGES
Auto-selected by phone language: English, Spanish, French, German, Italian, Portuguese (BR), Dutch, Russian, Japanese, Korean, Chinese, Hindi, Arabic, Romanian, Azerbaijani.

PRIVACY FIRST
No account, no sign-in, no cloud sync, no analytics, no behavioral tracking. Your data stays on your device; a single small banner ad keeps the app free. MIT licensed.

HEALTH CONNECT
Sync nutrition, weight, and body fat, with backfill support. Reinstalled or switched phones? Your food log, weight, and body fat restore automatically from Health Connect.

NOTE: Not medical advice. Estimates are AI-generated; consult a healthcare professional before significant diet changes.

Terms: https://fud-ai.app/terms.html
Privacy: https://fud-ai.app/privacy.html
Source: https://github.com/apoorvdarshan/fud-ai

```

### Other 14 languages
English-only on Play Console — non-English Play Store browsers (ar, az-AZ, de-DE, es-ES, fr-FR, hi-IN, it-IT, ja-JP, ko-KR, nl-NL, pt-BR, ro, ru-RU, zh-CN) see the English source as fallback. The in-app UI itself is fully translated into all 14 locales via per-locale `values-{lang}/strings.xml`, so the localization gap is only on the Play Store listing surface, not inside the app.

---

## 4. What's New (v3.0.2 / versionCode 29)

**500 char hard cap per language.** Paste the entire block below into Play Console's "Release notes" field — it auto-routes each `<lang-tag>` block to the matching locale.

```
<en-US>
• New Workouts tab: 873 exercises with photos, filters, search, and detail pages.
• Home redesign: speedometer gauge, macro bars, nutrient cards, floating add button — widgets match.
• Ask Coach by voice, share meals as links, export your diary, reprocess meals with AI.
• 10 new theme colors, body-fat history, independent units.
• Reinstalled? Your food log, weight, and body fat restore from Health Connect.
• Adaptive Goals and Energy Burn on by default. A small banner ad keeps Fud AI free.
</en-US>

<ar>
• علامة تبويب تمارين جديدة: 873 تمرينًا مع الصور والفلاتر والبحث وصفحات التفاصيل.
• تصميم جديد للرئيسية: عدّاد سرعة للسعرات وأشرطة ماكرو وأربع بطاقات مغذّيات وزر إضافة عائم — والودجات تواكبه.
• اسأل المدرب صوتيًا، وشارك الوجبات كروابط، وصدّر يومياتك، وأعد معالجة الوجبات بالذكاء الاصطناعي.
• 10 ألوان سمة جديدة، وسجل دهون الجسم، ووحدات مستقلة.
• أعدت التثبيت؟ يُستعاد سجلك ووزنك ودهون جسمك من Health Connect.
• الأهداف التكيفية وحرق الطاقة مفعّلان افتراضيًا. إعلان بانر صغير يُبقي Fud AI مجانيًا.
</ar>

<az-AZ>
• Yeni Məşqlər tabı: şəkillər, filtrlər, axtarış və detallar ilə 873 məşq.
• Yeni Ana səhifə: spidometr göstəricisi, makro zolaqları, qida kartları, üzən düymə — vidcetlər yeniləndi.
• Koça səslə sual verin, yemək linkləri paylaşın, gündəliyi ixrac edin, Sİ ilə yenidən analiz edin.
• 10 yeni tema rəngi, bədən yağı tarixçəsi, ayrı vahidlər.
• Jurnal, çəki və bədən yağı Health Connect-dən bərpa olunur.
• Adaptiv Məqsədlər və Enerji Sərfi defolt aktivdir. Kiçik banner Fud AI-ni pulsuz saxlayır.
</az-AZ>

<de-DE>
• Neuer Workouts-Tab: 873 Übungen: Fotos, Filter, Suche.
• Home neu: Tacho-Anzeige, Makro-Balken, Nährstoffkarten, Plus-Button — Widgets passen.
• Coach per Sprache fragen, Mahlzeiten als Link teilen, Tagebuch exportieren, Mahlzeiten neu mit KI.
• 10 neue Themenfarben, Körperfett-Verlauf, unabhängige Einheiten.
• Neu installiert? Tagebuch, Gewicht und Körperfett kommen aus Health Connect zurück.
• Adaptive Ziele und Energieverbrauch standardmäßig an. Ein kleines Banner hält Fud AI kostenlos.
</de-DE>

<es-ES>
• Entrenamientos: 873 ejercicios con fotos, filtros y búsqueda.
• Nuevo Inicio: velocímetro, barras de macros, tarjetas de nutrientes y botón flotante — widgets a juego.
• Coach por voz, comidas como enlaces, exporta el diario, reprocesa con IA.
• 10 colores nuevos, historial de grasa corporal, unidades independientes.
• ¿Reinstalaste? Registro, peso y grasa se restauran desde Health Connect.
• Objetivos adaptativos y Quema de energía activos por defecto. Un banner mantiene Fud AI gratis.
</es-ES>

<fr-FR>
• Entraînements : 873 exercices avec photos, filtres et recherche.
• Nouvel accueil : compteur, barres de macros, cartes de nutriments, bouton flottant — widgets assortis.
• Coach à la voix, repas partagés en liens, journal exportable, retraités par IA.
• 10 nouvelles couleurs, historique de masse grasse, unités indépendantes.
• Réinstallé ? Journal, poids et masse grasse se restaurent depuis Health Connect.
• Objectifs adaptatifs et Énergie brûlée par défaut. Une bannière garde Fud AI gratuit.
</fr-FR>

<hi-IN>
• नया Workouts टैब: फ़ोटो, फ़िल्टर और खोज के साथ 873 व्यायाम।
• नया होम: स्पीडोमीटर कैलोरी गेज, मैक्रो बार, चार पोषक कार्ड और फ़्लोटिंग जोड़ें बटन — विजेट भी नए रूप में।
• कोच से आवाज़ में पूछें, भोजन लिंक के रूप में साझा करें, डायरी निर्यात करें, भोजन AI से दोबारा प्रोसेस करें।
• 10 नए थीम रंग, बॉडी फ़ैट इतिहास, अलग इकाइयाँ।
• दोबारा इंस्टॉल किया? लॉग, वज़न और बॉडी फ़ैट Health Connect से बहाल होते हैं।
• Adaptive Goals और Energy Burn डिफ़ॉल्ट रूप से चालू। एक छोटा बैनर Fud AI को मुफ़्त रखता है।
</hi-IN>

<it-IT>
• Allenamenti: 873 esercizi con foto, filtri e ricerca.
• Nuova Home: tachimetro, barre dei macro, schede nutrienti e pulsante flottante — widget rinnovati.
• Chiedi al Coach a voce, condividi i pasti come link, esporta il diario, rielabora con l'AI.
• 10 nuovi colori tema, storico grasso corporeo, unità indipendenti.
• Reinstallato? Diario, peso e grasso si ripristinano da Health Connect.
• Obiettivi adattivi ed Energia bruciata attivi di default. Un piccolo banner mantiene Fud AI gratuito.
</it-IT>

<ja-JP>
• 新しいワークアウトタブ：写真・フィルター・検索・詳細ページ付きの873種目。
• ホーム刷新：スピードメーター型カロリーゲージ、マクロバー、栄養素カード4枚、フローティング追加ボタン。ウィジェットも刷新。
• コーチに音声で質問、食事をリンクで共有、日記をエクスポート、食事をAIで再解析。
• テーマカラー10色追加、体脂肪履歴、単位の個別設定、カメラ＋カメラ。
• 再インストールしても記録・体重・体脂肪はHealth Connectから復元されます。
• アダプティブ目標とエネルギー消費がデフォルトでオンに。小さなバナー広告でFud AIは無料のままです。
</ja-JP>

<ko-KR>
• 새로운 운동 탭: 사진, 필터, 검색, 상세 페이지와 함께 873가지 운동.
• 홈 개편: 속도계 칼로리 게이지, 매크로 바, 영양소 카드 4개, 플로팅 추가 버튼 — 위젯도 새 디자인.
• 코치에게 음성으로 질문, 식사를 링크로 공유, 일기 내보내기, 식사를 AI로 재분석.
• 테마 색상 10종 추가, 체지방 기록, 단위 개별 설정, 카메라 + 카메라.
• 재설치해도 기록, 체중, 체지방이 Health Connect에서 복원됩니다.
• 적응형 목표와 에너지 소모 기본 켜짐. 작은 배너 광고로 Fud AI는 계속 무료입니다.
</ko-KR>

<nl-NL>
• Workouts: 873 oefeningen met foto's, filters en zoeken.
• Home vernieuwd: snelheidsmeter, macrobalken, voedingskaarten en zwevende knop — widgets doen mee.
• Vraag de Coach met je stem, deel maaltijden als links, exporteer je dagboek, herverwerk met AI.
• 10 nieuwe themakleuren, vetpercentagegeschiedenis, aparte eenheden.
• Opnieuw geïnstalleerd? Logboek, gewicht en vet komen terug uit Health Connect.
• Adaptieve doelen en Energieverbruik standaard aan. Een kleine banner houdt Fud AI gratis.
</nl-NL>

<pt-BR>
• Nova aba Treinos: 873 exercícios com fotos, filtros e busca.
• Nova tela inicial: velocímetro, barras de macros, cartões de nutrientes e botão flutuante — widgets combinando.
• Coach por voz, refeições como links, exporte o diário, reprocesse com IA.
• 10 novas cores de tema, histórico de gordura corporal, unidades separadas.
• Reinstalou? Diário, peso e gordura são restaurados do Health Connect.
• Metas adaptativas e Queima de energia por padrão. Um banner mantém o Fud AI gratuito.
</pt-BR>

<ro>
• Antrenamente: 873 de exerciții cu fotografii, filtre și căutare.
• Ecran principal nou: vitezometru, bare de macronutrienți, carduri de nutrienți, buton plutitor — widgeturi asortate.
• Coach cu vocea, mese ca linkuri, exportă jurnalul, reprocesează cu AI.
• 10 culori noi de temă, istoric de grăsime, unități separate.
• Ai reinstalat? Jurnalul, greutatea și grăsimea se restaurează din Health Connect.
• Obiective adaptive și Energie consumată implicit active. Un banner menține Fud AI gratuit.
</ro>

<ru-RU>
• «Тренировки»: 873 упражнения с фото, фильтрами и поиском.
• Новый главный экран: спидометр, полосы макросов, карточки нутриентов и плавающая кнопка — виджеты обновлены.
• Спрашивайте Коуча голосом, делитесь едой ссылками, экспортируйте дневник, переобработка с ИИ.
• 10 новых цветов темы, история жира, независимые единицы.
• Переустановили? Дневник, вес и жир восстановятся из Health Connect.
• «Адаптивные цели» и «Расход энергии» по умолчанию. Небольшой баннер сохраняет Fud AI бесплатным.
</ru-RU>

<zh-CN>
• 全新“锻炼”标签页：873 个动作，配照片、筛选、搜索和详情页。
• 主页焕新：仪表盘式卡路里表、宏量条、四张营养卡片和悬浮添加按钮 — 小组件同步焕新。
• 语音向教练提问、把餐食分享为链接、导出饮食日记、用 AI 重新处理餐食。
• 新增 10 种主题色、体脂历史、独立单位设置、相机 + 相机拼接。
• 重新安装后，记录、体重和体脂会从 Health Connect 恢复。
• 自适应目标和能量消耗默认开启。一条小横幅广告让 Fud AI 保持免费。
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
- **Health features**: Yes — fitness/nutrition tracking. Local-only. v3.0 adds the Health Connect nutrition READ permission (used only to restore the user's own previously-written records after a reinstall) — include it in the Health Connect permissions declaration alongside the existing weight/body-fat/energy reads and writes.
