# Play Store Listing

Google Play Console listing copy for Fud AI Android v6.0 / versionCode 33. Each field is in a code block for easy copy-paste. Char counts are tracked because Play Console enforces hard caps and silently truncates anything over.

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

NEW in v6.0: plan and log strength workouts with sets, reps, weight, and RPE. Estimate daily workout burn, review it in Progress, and optionally sync it with Health Connect. Switch between the diary and 873-exercise library; Fud AI remembers your view.

Meal reuse is faster, copied foods use the current time, and exports include every stored nutrient. Water tracking adds selectable units. AI presets use current models, with configurable Ollama/custom timeouts.

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

AI PROVIDERS
Use Gemini, OpenAI, Claude, Grok, Groq, OpenRouter, Together, Hugging Face, Fireworks, DeepInfra, Mistral, Ollama, or an OpenAI-compatible endpoint. Keys are encrypted.

6 SPEECH-TO-TEXT ENGINES
Native Android, Gemini, OpenAI Whisper, Groq, Deepgram, or AssemblyAI, with automatic or fixed language handling.

COACH
Multi-turn chat can access your profile, goals, food log, progress, and workouts when requested. Images are supported.

REVIEW BEFORE LOGGING
Unlock Nutrition to correct calories, macros, and detailed nutrients before saving; serving changes then scale from your edits. What if? previews today's macro impact and can ask AI for a suggestion.

WORKOUTS
Plan by day and log sets, reps, weight, and RPE without a timer. Swipe weeks, estimate calorie burn, and review history in Progress. The 873-exercise photo library includes muscle/equipment filters, search, sorting, and details.

PERSONALIZED GOALS
BMR and TDEE calculators, six activity levels, automatic or editable macro targets, and customizable meal-time boundaries.

OPTIONAL NUTRIENT GOALS
Set expanded nutrient goals separately from the macro calculator — fiber, sugar, fats, sodium, vitamins, minerals, and more. Use AI Estimate or set them manually. Home cards can show macros or selected nutrients.

WIDGETS
Separate Calorie, Protein, Today, and Water widgets in the Home speedometer style. They refresh from local snapshots when you log.

OPTIONAL WATER TRACKING
Off by default. Set your own daily goal, quick-log one to three glasses or a custom amount, view progress below calories, schedule a local reminder, and use the dedicated Water widget. Water history stays on your device and is not sent to Health Connect.

15 LANGUAGES
Auto-selected by phone language: English, Spanish, French, German, Italian, Portuguese (BR), Dutch, Russian, Japanese, Korean, Chinese, Hindi, Arabic, Romanian, Azerbaijani.

PRIVACY FIRST
No account, Fud AI cloud, analytics, behavioral tracking, or ads. Android backup may apply under system settings. Keys are encrypted; AI/STT requests go directly to your provider. MIT licensed.

HEALTH CONNECT
Optional sync for nutrition, weight, body fat, and calculated workout calories, plus energy reads for goal estimates. Records can restore from Health Connect after reinstall.

NOTE: Not medical advice. Estimates are AI-generated; consult a healthcare professional before significant diet changes.

Terms: https://fud-ai.app/terms.html
Privacy: https://fud-ai.app/privacy.html
Source: https://github.com/apoorvdarshan/fud-ai

```

### Other 14 languages
English-only on Play Console — non-English Play Store browsers (ar, az-AZ, de-DE, es-ES, fr-FR, hi-IN, it-IT, ja-JP, ko-KR, nl-NL, pt-BR, ro, ru-RU, zh-CN) see the English source as fallback. The app includes 14 localized interfaces; newer strings may temporarily use the English fallback.

---

## 4. What's New (v6.0 / versionCode 33)

**500 char hard cap per language.** Paste the entire block below into Play Console's "Release notes" field — it auto-routes each `<lang-tag>` block to the matching locale.

```
<en-US>
• New workout diary/logger: plan exercises, enter sets, reps, weight and RPE, estimate daily calorie burn, and review workout history.
• Switch between the logger and 873-exercise library; your last view stays selected.
• Faster meal reuse, complete nutrient export, and selectable water units.
• Updated AI model presets, configurable local/custom timeouts, Health Connect workout sync, and reliability fixes.
</en-US>

<ar>
• يوميات ومسجل تمارين جديد: خطط للتمارين وسجل المجموعات والتكرارات والوزن وRPE والسعرات.
• بدّل بين المسجل ومكتبة تضم 873 تمرينًا، مع حفظ آخر عرض.
• إعادة استخدام أسرع للوجبات، وتصدير كامل للمغذيات، ووحدات ماء قابلة للاختيار.
• نماذج AI محدثة ومزامنة التمارين مع Health Connect وتحسينات للموثوقية.
</ar>

<az-AZ>
• Yeni məşq gündəliyi: hərəkətləri planlayın, set, təkrar, çəki, RPE və kalori sərfini qeyd edin.
• Gündəliklə 873 hərəkətlik kitabxana arasında keçin; son görünüş yadda qalır.
• Yeməkləri daha sürətli təkrar istifadə edin, bütün qidaları ixrac edin və su vahidini seçin.
• Yenilənmiş AI modelləri, Health Connect məşq sinxronu və etibarlılıq düzəlişləri.
</az-AZ>

<de-DE>
• Neues Trainingstagebuch: Übungen planen und Sätze, Wiederholungen, Gewicht, RPE und Kalorien erfassen.
• Zwischen Logger und Bibliothek mit 873 Übungen wechseln; die letzte Ansicht bleibt gewählt.
• Mahlzeiten schneller wiederverwenden, alle Nährstoffe exportieren und Wassereinheit wählen.
• Aktualisierte KI-Modelle, Health-Connect-Trainingssync und Zuverlässigkeitskorrekturen.
</de-DE>

<es-ES>
• Nuevo diario de entrenamiento: planifica ejercicios y registra series, repeticiones, peso, RPE y calorías.
• Cambia entre el registro y la biblioteca de 873 ejercicios; se conserva la última vista.
• Reutiliza comidas más rápido, exporta todos los nutrientes y elige la unidad de agua.
• Modelos de IA actualizados, sincronización de entrenos con Health Connect y mejoras de fiabilidad.
</es-ES>

<fr-FR>
• Nouveau journal d'entraînement : planifiez puis notez séries, répétitions, poids, RPE et calories.
• Basculez entre le journal et la bibliothèque de 873 exercices ; la dernière vue est mémorisée.
• Réutilisation des repas accélérée, export de tous les nutriments et unité d'eau au choix.
• Modèles IA actualisés, synchronisation Health Connect et correctifs de fiabilité.
</fr-FR>

<hi-IN>
• नया वर्कआउट लॉगर: व्यायाम प्लान करें और सेट, रेप, वजन, RPE व कैलोरी बर्न दर्ज करें।
• लॉगर और 873 व्यायामों की लाइब्रेरी के बीच बदलें; पिछला दृश्य याद रहता है।
• भोजन जल्दी दोबारा उपयोग करें, सभी पोषक तत्व निर्यात करें और पानी की इकाई चुनें।
• नए AI मॉडल, Health Connect वर्कआउट सिंक और विश्वसनीयता सुधार।
</hi-IN>

<it-IT>
• Nuovo diario allenamenti: pianifica esercizi e registra serie, ripetizioni, peso, RPE e calorie.
• Passa tra diario e libreria di 873 esercizi; l'ultima vista resta selezionata.
• Riutilizzo pasti più rapido, esportazione di tutti i nutrienti e unità dell'acqua selezionabile.
• Modelli IA aggiornati, sincronizzazione allenamenti Health Connect e correzioni di affidabilità.
</it-IT>

<ja-JP>
• 新しいワークアウト日記：種目を計画し、セット、回数、重量、RPE、消費カロリーを記録。
• ロガーと873種目のライブラリを切替。最後に開いた表示を保持します。
• 食事の再利用を高速化し、全栄養素の書き出しと水分単位の選択に対応。
• AIモデルを更新し、Health Connectの運動同期と信頼性を改善。
</ja-JP>

<ko-KR>
• 새 운동 일지: 운동을 계획하고 세트, 횟수, 무게, RPE와 칼로리 소모를 기록하세요.
• 로거와 873개 운동 라이브러리를 전환하며 마지막 화면이 유지됩니다.
• 식사 재사용 속도 향상, 모든 영양소 내보내기, 물 단위 선택 기능.
• 최신 AI 모델, Health Connect 운동 동기화 및 안정성 개선.
</ko-KR>

<nl-NL>
• Nieuw trainingsdagboek: plan oefeningen en log sets, herhalingen, gewicht, RPE en calorieën.
• Wissel tussen logger en bibliotheek met 873 oefeningen; de laatste weergave blijft gekozen.
• Maaltijden sneller hergebruiken, alle voedingsstoffen exporteren en watereenheid kiezen.
• Bijgewerkte AI-modellen, Health Connect-trainingssync en betrouwbaarheidsfixes.
</nl-NL>

<pt-BR>
• Novo diário de treino: planeje exercícios e registre séries, repetições, peso, RPE e calorias.
• Alterne entre o registro e a biblioteca de 873 exercícios; a última tela fica salva.
• Reutilize refeições mais rápido, exporte todos os nutrientes e escolha a unidade de água.
• Modelos de IA atualizados, sincronização de treinos com Health Connect e correções de estabilidade.
</pt-BR>

<ro>
• Jurnal nou de antrenament: planifică exerciții și notează seturi, repetări, greutate, RPE și calorii.
• Comută între jurnal și biblioteca cu 873 de exerciții; ultima vizualizare rămâne selectată.
• Refolosește mesele mai rapid, exportă toți nutrienții și alege unitatea pentru apă.
• Modele AI actualizate, sincronizare Health Connect și remedieri de fiabilitate.
</ro>

<ru-RU>
• Новый дневник тренировок: планируйте упражнения и записывайте подходы, повторы, вес, RPE и калории.
• Переключайтесь между дневником и библиотекой из 873 упражнений; последний экран сохраняется.
• Быстрее используйте блюда повторно, экспортируйте все нутриенты и выбирайте единицу воды.
• Обновлены модели ИИ, синхронизация тренировок Health Connect и надёжность.
</ru-RU>

<zh-CN>
• 新增训练日记：规划动作并记录组数、次数、重量、RPE 和消耗热量。
• 可在记录器与 873 个动作库之间切换，并保留上次视图。
• 更快复用餐食、导出全部营养素，并可选择饮水单位。
• 更新 AI 模型、Health Connect 训练同步及多项稳定性修复。
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
- **Health features**: Yes — nutrition, body measurements, energy-based goals, calculated workout calories, and optional local water tracking. Health Connect permissions are READ/WRITE nutrition, weight, body fat, and active calories burned, plus READ total calories burned. Water history is local and is not written to Health Connect. Explain restore/backfill, Energy Burn Goals, and calculated workout-burn sync in the permissions declaration, and keep the in-app rationale/Manage Access flow aligned with the privacy policy.
