# Play Store Listing

Google Play Console listing copy for Fud AI Android v3.1 / versionCode 32. Each field is in a code block for easy copy-paste. Char counts are tracked because Play Console enforces hard caps and silently truncates anything over.

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

NEW in v3.1: analyze up to 10 camera or library photos together with an optional note and retry failed AI requests. Enable local water tracking if you want it, choose any practical goal, quick-log glasses or a custom amount, see progress below calories, schedule a local reminder, and add a dedicated Water widget. Six clearer activity levels, customizable Breakfast/Lunch/Dinner/Snack boundaries, complete image previews, unit-aware weekly-change controls, and easier Health Connect permission management are also included.

Open source, privacy-first. Bring your own API key.

WAYS TO LOG A MEAL
• Camera — take up to 10 photos, add an optional note
• Photos — import up to 10 images, add an optional note
• Barcode — Open Food Facts lookup
• Voice — 6 STT engines
• Text — describe it, AI parses it
• Manual Entry
• Saved Meals — recents, frequent, favorites
• Copy from Day — copy meals from another date

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
BMR via Katch-McArdle or Mifflin-St Jeor. TDEE with six work-and-training based activity levels. Auto-calculated calorie + protein + carbs + fat targets — fully customizable. Set the times when Breakfast, Lunch, Dinner, and Snack begin.

OPTIONAL NUTRIENT GOALS
Set expanded nutrient goals separately from the macro calculator — fiber, sugar, fats, sodium, vitamins, minerals, and more. Use AI Estimate or set them manually. Home cards can show macros or selected nutrients.

WIDGETS
Separate Calorie, Protein, Today, and Water widgets in the Home speedometer style. They refresh from local snapshots when you log.

OPTIONAL WATER TRACKING
Off by default. Set your own daily goal, quick-log one to three glasses or a custom amount, view progress below calories, schedule a local reminder, and use the dedicated Water widget. Water history stays on your device and is not sent to Health Connect.

15 LANGUAGES
Auto-selected by phone language: English, Spanish, French, German, Italian, Portuguese (BR), Dutch, Russian, Japanese, Korean, Chinese, Hindi, Arabic, Romanian, Azerbaijani.

PRIVACY FIRST
No account, sign-in, Fud AI-operated cloud sync, analytics, behavioral tracking, or ads. Android backup/device transfer may still apply under your system settings. API keys are encrypted on-device. AI/STT requests go directly to your chosen provider. Shared meal links contain the meal data you choose to share. MIT licensed.

HEALTH CONNECT
Optional sync for nutrition, weight, body fat, and energy data, with backfill support. Reinstalled or switched phones? Your food log, weight, and body fat can restore from Health Connect. Review or revoke permissions through Manage Access.

NOTE: Not medical advice. Estimates are AI-generated; consult a healthcare professional before significant diet changes.

Terms: https://fud-ai.app/terms.html
Privacy: https://fud-ai.app/privacy.html
Source: https://github.com/apoorvdarshan/fud-ai

```

### Other 14 languages
English-only on Play Console — non-English Play Store browsers (ar, az-AZ, de-DE, es-ES, fr-FR, hi-IN, it-IT, ja-JP, ko-KR, nl-NL, pt-BR, ro, ru-RU, zh-CN) see the English source as fallback. The in-app UI itself is fully translated into all 14 locales via per-locale `values-{lang}/strings.xml`, so the localization gap is only on the Play Store listing surface, not inside the app.

---

## 4. What's New (v3.1 / versionCode 32)

**500 char hard cap per language.** Paste the entire block below into Play Console's "Release notes" field — it auto-routes each `<lang-tag>` block to the matching locale.

```
<en-US>
• Analyze up to 10 camera or library photos together, add an optional note, and retry failed requests.
• Optional local water tracking: custom goal, glass shortcuts, reminder, progress, and a separate Water widget.
• Six clearer activity levels and customizable Breakfast, Lunch, Dinner, and Snack times.
• Complete image previews, corrected weekly-change units, configurable meal defaults, and easier Health Connect access.
</en-US>

<ar>
• حلّل حتى 10 صور من الكاميرا أو المكتبة معًا، وأضف ملاحظة اختيارية، وأعد المحاولة عند الفشل.
• تتبع ماء محلي اختياري: هدف مخصص، اختصارات للأكواب، تذكير، تقدم وودجت ماء مستقل.
• ستة مستويات نشاط أوضح وأوقات قابلة للتخصيص للفطور والغداء والعشاء والوجبات الخفيفة.
• معاينات صور كاملة ووحدات أسبوعية مصححة ووصول أسهل إلى Health Connect.
</ar>

<az-AZ>
• Kamera və ya qalereyadan 10-a qədər şəkli birlikdə analiz edin, qeyd əlavə edin və uğursuz sorğunu təkrarlayın.
• İstəyə bağlı yerli su izləmə: fərdi hədəf, stəkan qısayolları, xatırlatma, irəliləyiş və ayrıca vidcet.
• Altı daha aydın fəaliyyət səviyyəsi və fərdiləşdirilən yemək vaxtları.
• Tam şəkil önbaxışı, düzəldilmiş həftəlik vahidlər və Health Connect girişinin rahat idarəsi.
</az-AZ>

<de-DE>
• Bis zu 10 Kamera- oder Bibliotheksfotos gemeinsam analysieren, optional notieren und Fehler erneut versuchen.
• Optionale lokale Wassererfassung: eigenes Ziel, Glas-Kürzel, Erinnerung, Fortschritt und eigenes Widget.
• Sechs klarere Aktivitätsstufen und anpassbare Essenszeiten.
• Vollständige Bildvorschau, korrigierte Wochen-Einheiten und einfacherer Health-Connect-Zugriff.
</de-DE>

<es-ES>
• Analiza juntas hasta 10 fotos de cámara o galería, añade una nota opcional y reintenta si falla.
• Agua local opcional: objetivo propio, atajos por vasos, recordatorio, progreso y widget independiente.
• Seis niveles de actividad más claros y horarios personalizables para cada comida.
• Vista previa completa, unidades semanales corregidas y acceso más fácil a Health Connect.
</es-ES>

<fr-FR>
• Analysez ensemble jusqu'à 10 photos, ajoutez une note facultative et réessayez après un échec.
• Suivi d'eau local facultatif : objectif, raccourcis par verre, rappel, progression et widget dédié.
• Six niveaux d'activité plus clairs et horaires de repas personnalisables.
• Aperçus complets, unités hebdomadaires corrigées et accès Health Connect simplifié.
</fr-FR>

<hi-IN>
• कैमरा या गैलरी की 10 फ़ोटो साथ विश्लेषित करें, वैकल्पिक नोट जोड़ें और विफल अनुरोध फिर चलाएँ।
• वैकल्पिक स्थानीय पानी ट्रैकिंग: अपना लक्ष्य, ग्लास शॉर्टकट, रिमाइंडर, प्रगति और अलग विजेट।
• छह स्पष्ट गतिविधि स्तर और हर भोजन का बदलने योग्य समय।
• पूरी इमेज प्रीव्यू, सही साप्ताहिक इकाइयाँ और आसान Health Connect एक्सेस।
</hi-IN>

<it-IT>
• Analizza insieme fino a 10 foto da fotocamera o galleria, aggiungi una nota e riprova in caso di errore.
• Acqua locale opzionale: obiettivo personale, scorciatoie per bicchieri, promemoria, progresso e widget dedicato.
• Sei livelli di attività più chiari e orari dei pasti personalizzabili.
• Anteprime complete, unità settimanali corrette e accesso Health Connect più semplice.
</it-IT>

<ja-JP>
• カメラまたはライブラリの写真を最大10枚まとめて解析。任意のメモ追加と失敗時の再試行に対応。
• 任意のローカル水分記録：自由な目標、コップ単位の追加、リマインダー、進捗、専用ウィジェット。
• より分かりやすい6段階の活動レベルと、食事時間のカスタマイズ。
• 画像全体のプレビュー、週間変化の単位修正、Health Connect権限管理を改善。
</ja-JP>

<ko-KR>
• 카메라 또는 사진 앱에서 최대 10장을 함께 분석하고 선택적 메모를 추가하며 실패 시 다시 시도할 수 있습니다.
• 선택형 로컬 물 기록: 자유 목표, 잔 단위 바로 추가, 알림, 진행률, 전용 위젯.
• 더 명확한 6단계 활동 수준과 사용자 지정 식사 시간.
• 전체 이미지 미리보기, 주간 변화 단위 수정, 더 쉬운 Health Connect 권한 관리.
</ko-KR>

<nl-NL>
• Analyseer samen maximaal 10 camera- of bibliotheekfoto's, voeg een notitie toe en probeer fouten opnieuw.
• Optionele lokale waterregistratie: eigen doel, glas-snelkoppelingen, herinnering, voortgang en aparte widget.
• Zes duidelijkere activiteitsniveaus en instelbare maaltijdtijden.
• Volledige beeldvoorbeelden, juiste weekeenheden en eenvoudiger Health Connect-toegang.
</nl-NL>

<pt-BR>
• Analise até 10 fotos da câmera ou galeria juntas, adicione nota opcional e tente novamente em caso de falha.
• Água local opcional: meta própria, atalhos por copos, lembrete, progresso e widget separado.
• Seis níveis de atividade mais claros e horários de refeições personalizáveis.
• Prévia completa, unidades semanais corrigidas e acesso mais fácil ao Health Connect.
</pt-BR>

<ro>
• Analizează împreună până la 10 fotografii, adaugă o notă opțională și reîncearcă după erori.
• Urmărire locală opțională a apei: obiectiv propriu, scurtături pentru pahare, memento, progres și widget separat.
• Șase niveluri de activitate mai clare și ore de masă personalizabile.
• Previzualizări complete, unități săptămânale corectate și acces Health Connect mai simplu.
</ro>

<ru-RU>
• Анализируйте вместе до 10 фото с камеры или из галереи, добавляйте заметку и повторяйте запрос после ошибки.
• Необязательный локальный учёт воды: своя цель, быстрые порции, напоминание, прогресс и отдельный виджет.
• Шесть понятных уровней активности и настраиваемое время приёмов пищи.
• Полные превью, исправленные недельные единицы и удобнее доступ к Health Connect.
</ru-RU>

<zh-CN>
• 可同时分析最多 10 张相机或相册照片，添加可选备注，并在失败后重试。
• 可选本地饮水记录：自定义目标、杯数快捷项、提醒、进度和独立小组件。
• 六档更清晰的活动水平，并可自定义早餐、午餐、晚餐和加餐时间。
• 完整图片预览、修正每周变化单位，并简化 Health Connect 权限管理。
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
- **Ads**: No — v3.0.3 removed the AdMob banner and the ads SDK entirely. Set "contains ads" to No, and set the Advertising ID declaration to No (the `AD_ID` permission is gone from the manifest).
- **Content rating**: Everyone (E)
- **Target audience**: 13+
- **News app**: No
- **COVID-19 contact tracing**: No
- **Data safety**: The developer operates no Fud AI account, analytics, advertising, or app-data backend. Do not declare Advertising ID. Most app data is local, and API keys are stored in EncryptedSharedPreferences. User-initiated AI/STT requests send the selected photos/text/audio directly to the provider the user configures; barcode lookup sends the barcode to Open Food Facts; optional shared-meal links place selected meal data in the URL; optional Health Connect sync reads/writes the declared health types. Complete the Play form according to Google's current definitions for these direct user-initiated transfers rather than broadly claiming that no data is processed. Network requests use HTTPS except a user-configured local/custom endpoint may use the URL the user supplies. Delete All Data removes local app data but not Health Connect records.
- **Government app**: No
- **Financial features**: No
- **Health features**: Yes — nutrition, body measurements, energy-based goals, and optional local water tracking. Health Connect permissions are READ/WRITE nutrition, weight, and body fat plus READ active and total calories burned. Water history is local and is not written to Health Connect. Explain restore/backfill and Energy Burn use in the permissions declaration, and keep the in-app rationale/Manage Access flow aligned with the privacy policy.
