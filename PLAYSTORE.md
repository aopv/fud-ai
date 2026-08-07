# Play Store Listing

Google Play Console listing copy for Fud AI Android v6.1 / versionCode 34. Each field is in a code block for easy copy-paste. Char counts are tracked because Play Console enforces hard caps and silently truncates anything over.

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

NEW in v6.1: optionally track intermittent fasts with a persistent timer, a custom 1–168 hour goal, editable history, and a local goal alert. Start, end, or cancel from the Home + menu. Fasting stays separate from nutrition and Health Connect.

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
Multi-turn chat can access your profile, goals, food log, progress, workouts, and explicitly logged fasts when requested. It never assumes a missing meal means you fasted. Images are supported.

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

OPTIONAL FASTING TRACKING
Off by default. Choose a 1–168 hour goal, start/end/cancel from the Home + menu, keep the timer across app restarts, optionally receive a local goal alert, and edit completed sessions. Fasting stays on your device and is not sent to Health Connect.

15 LANGUAGES
Auto-selected by phone language: English, Spanish, French, German, Italian, Portuguese (BR), Dutch, Russian, Japanese, Korean, Chinese, Hindi, Arabic, Romanian, Azerbaijani.

PRIVACY FIRST
No account, Fud AI cloud, analytics, behavioral tracking, or ads. Android backup may apply under system settings. Keys are encrypted; AI/STT requests go directly to your provider. MIT licensed.

HEALTH CONNECT
Optional sync for nutrition, weight, body fat, and calculated workout calories, plus energy reads for goal estimates. Records can restore from Health Connect after reinstall. Fasting is local-only.

NOTE: Not medical advice. Estimates are AI-generated; consult a healthcare professional before significant diet changes.

Terms: https://fud-ai.app/terms.html
Privacy: https://fud-ai.app/privacy.html
Source: https://github.com/apoorvdarshan/fud-ai

```

### Other 14 languages
English-only on Play Console — non-English Play Store browsers (ar, az-AZ, de-DE, es-ES, fr-FR, hi-IN, it-IT, ja-JP, ko-KR, nl-NL, pt-BR, ro, ru-RU, zh-CN) see the English source as fallback. The app includes 14 localized interfaces; newer strings may temporarily use the English fallback.

---

## 4. What's New (v6.1 / versionCode 34)

**500 char hard cap per language.** Paste the entire block below into Play Console's "Release notes" field — it auto-routes each `<lang-tag>` block to the matching locale.

```
<en-US>
• Optional fasting tracker with a persistent timer, custom 1–168 hour goal, editable history, and an optional local goal alert.
• Start, end, or cancel from Home. Fasting stays separate from nutrition and Health Connect; Coach can review only explicitly logged fasts.
• Reliability and security improvements.
</en-US>

<ar>
• متتبع صيام اختياري بمؤقت مستمر وهدف مخصص من 1 إلى 168 ساعة وسجل قابل للتعديل وتنبيه محلي اختياري.
• يبقى الصيام منفصلًا عن التغذية وHealth Connect، مع تحسينات في الموثوقية والأمان.
</ar>

<az-AZ>
• Davamlı taymer, 1–168 saatlıq xüsusi məqsəd, redaktə edilən tarixçə və istəyə bağlı yerli bildiriş ilə oruc izləmə.
• Oruc qidalanma və Health Connect-dən ayrı qalır; etibarlılıq və təhlükəsizlik təkmilləşdirildi.
</az-AZ>

<de-DE>
• Optionaler Fasten-Tracker mit dauerhaftem Timer, eigenem Ziel von 1–168 Stunden, bearbeitbarem Verlauf und optionaler lokaler Erinnerung.
• Fasten bleibt von Ernährung und Health Connect getrennt; Zuverlässigkeit und Sicherheit wurden verbessert.
</de-DE>

<es-ES>
• Seguimiento de ayuno opcional con temporizador persistente, objetivo de 1–168 horas, historial editable y aviso local opcional.
• El ayuno se mantiene separado de la nutrición y Health Connect; mejoras de fiabilidad y seguridad.
</es-ES>

<fr-FR>
• Suivi du jeûne optionnel avec minuteur persistant, objectif de 1 à 168 h, historique modifiable et alerte locale facultative.
• Le jeûne reste séparé de la nutrition et de Health Connect ; fiabilité et sécurité améliorées.
</fr-FR>

<hi-IN>
• लगातार चलने वाला टाइमर, 1–168 घंटे का कस्टम लक्ष्य, संपादन योग्य इतिहास और वैकल्पिक स्थानीय अलर्ट वाला उपवास ट्रैकर।
• उपवास पोषण और Health Connect से अलग रहता है; विश्वसनीयता और सुरक्षा में सुधार।
</hi-IN>

<it-IT>
• Monitoraggio del digiuno opzionale con timer persistente, obiettivo da 1–168 ore, cronologia modificabile e avviso locale facoltativo.
• Il digiuno resta separato da nutrizione e Health Connect; affidabilità e sicurezza migliorate.
</it-IT>

<ja-JP>
• 継続タイマー、1〜168時間のカスタム目標、編集可能な履歴、任意のローカル通知を備えた断食トラッカー。
• 断食は栄養記録とHealth Connectから分離。信頼性とセキュリティも改善しました。
</ja-JP>

<ko-KR>
• 지속 타이머, 1~168시간 사용자 목표, 편집 가능한 기록, 선택적 로컬 알림을 갖춘 단식 추적 기능.
• 단식은 영양 기록 및 Health Connect와 분리되며 안정성과 보안도 개선했습니다.
</ko-KR>

<nl-NL>
• Optionele vastentracker met blijvende timer, eigen doel van 1–168 uur, bewerkbare geschiedenis en optionele lokale melding.
• Vasten blijft los van voeding en Health Connect; betrouwbaarheid en beveiliging zijn verbeterd.
</nl-NL>

<pt-BR>
• Rastreador de jejum opcional com cronômetro persistente, meta de 1–168 horas, histórico editável e alerta local opcional.
• O jejum fica separado da nutrição e do Health Connect; melhorias de confiabilidade e segurança.
</pt-BR>

<ro>
• Urmărire opțională a postului cu cronometru persistent, obiectiv de 1–168 ore, istoric editabil și alertă locală opțională.
• Postul rămâne separat de nutriție și Health Connect; fiabilitate și securitate îmbunătățite.
</ro>

<ru-RU>
• Необязательный трекер голодания: постоянный таймер, цель 1–168 часов, редактируемая история и локальное уведомление.
• Голодание отделено от питания и Health Connect; улучшены надёжность и безопасность.
</ru-RU>

<zh-CN>
• 新增可选断食追踪：持续计时器、1–168 小时自定义目标、可编辑历史及可选本地提醒。
• 断食与营养记录和 Health Connect 完全分离，并提升可靠性与安全性。
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
- **Data safety**: The developer operates no Fud AI account, analytics, advertising, or app-data backend. Do not declare Advertising ID. Most app data, including fasting history, is local, and API keys are stored in EncryptedSharedPreferences. User-initiated AI/STT requests send the selected photos/text/audio directly to the provider the user configures; Coach requests may include explicitly logged fasting context when relevant; barcode lookup sends the barcode to Open Food Facts; optional shared-meal links place selected meal data in the URL; optional Health Connect sync reads/writes the declared health types. Complete the Play form according to Google's current definitions for these direct user-initiated transfers rather than broadly claiming that no data is processed. Network requests use HTTPS except a user-configured local/custom endpoint may use the URL the user supplies. Delete All Data removes local app data, including fasting history, but not Health Connect records.
- **Government app**: No
- **Financial features**: No
- **Health features**: Yes — nutrition, body measurements, energy-based goals, calculated workout calories, optional local water tracking, and optional local fasting tracking. Health Connect permissions are READ/WRITE nutrition, weight, body fat, and active calories burned, plus READ total calories burned. Water and fasting history are local and are not written to Health Connect. Explain restore/backfill, Energy Burn Goals, and calculated workout-burn sync in the permissions declaration, and keep the in-app rationale/Manage Access flow aligned with the privacy policy.
