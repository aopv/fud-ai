import SwiftUI
import Speech
import AVFoundation

/// Voice input that branches based on the user's selected Speech-to-Text provider:
/// - Native iOS → live SFSpeechRecognizer streaming with partial results (original behavior)
/// - Remote providers (Gemini / OpenAI / Groq / Deepgram / AssemblyAI) → record to an m4a file, upload on stop, show transcription when it returns
struct VoiceInputView: View {
    @State private var transcription = ""
    @State private var isRecording = false
    @State private var isTranscribing = false
    @State private var permissionError: String?
    @State private var remoteNotice: String?
    @State private var pulseScale: CGFloat = 1.0

    // Native path
    @State private var speechRecognizer: SFSpeechRecognizer?
    @State private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @State private var recognitionTask: SFSpeechRecognitionTask?
    @State private var audioEngine = AVAudioEngine()

    // Remote path (file-based recorder)
    @State private var audioRecorder: AVAudioRecorder?
    @State private var recordedFileURL: URL?

    var onCancel: () -> Void
    var onSubmit: (String) -> Void

    private var provider: SpeechProvider { SpeechSettings.selectedProvider }
    private var isNative: Bool { provider == .nativeIOS }

    private var analyzeButtonLabel: String { "Analyze" }

    private var analyzeButtonDisabled: Bool {
        // Native: one-tap — allow Analyze while recording (live transcription is already visible).
        // Remote: two-tap — force user to stop recording first, review the transcription, then Analyze.
        if isNative {
            if isRecording { return false }
            return transcription.trimmingCharacters(in: .whitespaces).isEmpty
        } else {
            if isRecording || isTranscribing { return true }
            return transcription.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    var body: some View {
        VStack(spacing: 14) {
            NeoSectionBanner(title: "Voice Log", detail: "LIVE INPUT", style: .cobalt)

            // Provider badge
            HStack(spacing: 6) {
                Image(systemName: provider.icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(provider.rawValue)
                    .font(.system(.caption2, design: .rounded, weight: .medium))
            }
            .textCase(.uppercase)
            .fontWeight(.black)
            .foregroundStyle(NeoAppColors.onCobalt)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(NeoAppColors.cobalt)
            .overlay {
                Rectangle()
                    .stroke(NeoAppColors.ink, lineWidth: NeoAppMetrics.compactRule)
            }

            // Transcription area
            ZStack(alignment: .topLeading) {
                if transcription.isEmpty && !isTranscribing {
                    Text(isRecording ? "Listening…" : "Tap the mic to start")
                        .foregroundStyle(NeoAppColors.mutedInk)
                        .font(.system(.body, design: .rounded, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 14)
                        .allowsHitTesting(false)
                }

                if isTranscribing {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Transcribing via \(provider.rawValue)…")
                            .font(.footnote)
                            .foregroundStyle(NeoAppColors.mutedInk)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 14)
                }

                Text(transcription)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(NeoAppColors.ink)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 14)
            }
            .frame(minHeight: 100, alignment: .topLeading)
            .background(NeoAppColors.surface)
            .overlay {
                Rectangle()
                    .stroke(NeoAppColors.ink, lineWidth: NeoAppMetrics.rule)
            }
            .accessibilityIdentifier("quickAdd.voice.transcription")

            // Mic button
            Button {
                if isRecording {
                    stopRecording()
                } else {
                    startRecording()
                }
            } label: {
                Image(systemName: isRecording ? "mic.fill" : "mic")
                    .font(.system(size: 28, weight: .black))
                    .foregroundStyle(isRecording ? Color.white : Color.black)
                    .frame(width: 72, height: 72)
                    .background(isRecording ? NeoAppColors.warning : NeoAppColors.acid)
                    .overlay {
                        Rectangle()
                            .stroke(NeoAppColors.ink, lineWidth: NeoAppMetrics.rule)
                    }
                    .scaleEffect(pulseScale)
            }
            .buttonStyle(.plain)
            .disabled(isTranscribing)
            .accessibilityLabel(isRecording ? "Stop recording" : "Start recording")
            .accessibilityValue(isTranscribing ? "Transcribing" : (isRecording ? "Recording" : "Idle"))
            .accessibilityIdentifier("quickAdd.voice.microphone")
            .onChange(of: isRecording) { _, recording in
                if recording {
                    withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                        pulseScale = 1.15
                    }
                } else {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        pulseScale = 1.0
                    }
                }
            }

            if let error = permissionError {
                Text(error)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(NeoAppColors.warning)
                    .multilineTextAlignment(.center)
                    .padding(10)
                    .frame(maxWidth: .infinity)
                    .background(NeoAppColors.warning.opacity(0.12))
                    .overlay {
                        Rectangle()
                            .stroke(NeoAppColors.warning, lineWidth: NeoAppMetrics.compactRule)
                    }
            }

            if let notice = remoteNotice {
                Text(notice)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(NeoAppColors.mutedInk)
                    .multilineTextAlignment(.center)
            }

            // Analyze button.
            // Native: one-tap — stops the live recognizer and submits.
            // Remote: two-tap — user must stop via mic first, review the transcription, then Analyze.
            Button {
                if isNative && isRecording {
                    stopRecording()
                }
                onSubmit(transcription)
            } label: {
                Text(analyzeButtonLabel)
                    .textCase(.uppercase)
                    .font(.system(.headline, design: .rounded, weight: .black))
                    .foregroundStyle(Color.black)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 50)
                    .background(NeoAppColors.acid)
                    .overlay {
                        Rectangle()
                            .stroke(NeoAppColors.ink, lineWidth: NeoAppMetrics.rule)
                    }
            }
            .buttonStyle(.plain)
            .disabled(analyzeButtonDisabled)
            .opacity(analyzeButtonDisabled ? 0.45 : 1)
            .accessibilityIdentifier("quickAdd.voice.analyze")

            Button {
                cancel()
            } label: {
                Text("Cancel")
                    .textCase(.uppercase)
                    .font(.system(.subheadline, design: .rounded, weight: .black))
                    .foregroundStyle(NeoAppColors.cobalt)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                    .background(NeoAppColors.surface)
                    .overlay {
                        Rectangle()
                            .stroke(NeoAppColors.cobalt, lineWidth: NeoAppMetrics.rule)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("quickAdd.voice.cancel")
        }
        .padding(14)
        .frame(width: 320)
        .background(NeoAppColors.canvas)
        .onAppear { startRecording() }
        .onDisappear { stopRecording() }
    }

    // MARK: - Start / Stop dispatch

    private func startRecording() {
        permissionError = nil
        remoteNotice = nil
        transcription = ""
        if isNative {
            startNativeRecording()
        } else {
            if SpeechSettings.apiKey(for: provider) == nil {
                permissionError = "No API key configured for \(provider.rawValue). Add one in Settings → Speech-to-Text."
                return
            }
            startRemoteRecording()
        }
    }

    private func stopRecording() {
        if isNative {
            stopNativeRecording()
        } else {
            stopRemoteRecording()
        }
    }

    private func cancel() {
        stopRecording()
        onCancel()
    }

    // MARK: - Native (streaming, on-device)

    private func startNativeRecording() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            guard authStatus == .authorized else {
                permissionError = "Speech recognition permission denied. Enable it in Settings."
                return
            }
            AVAudioApplication.requestRecordPermission { allowed in
                guard allowed else {
                    permissionError = "Microphone permission denied. Enable it in Settings."
                    return
                }
                beginNativeAudioSession()
            }
        }
    }

    private func beginNativeAudioSession() {
        speechRecognizer = Self.makeNativeSpeechRecognizer(for: SpeechSettings.selectedLanguage(for: .nativeIOS))
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            permissionError = "Native speech recognition unavailable on this device."
            return
        }

        recognitionTask?.cancel()
        recognitionTask = nil

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        recognitionRequest = request

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            permissionError = "Failed to set up audio session."
            return
        }

        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
            isRecording = true
        } catch {
            permissionError = "Failed to start audio engine."
            return
        }

        recognitionTask = speechRecognizer.recognitionTask(with: request) { result, error in
            if let result { transcription = result.bestTranscription.formattedString }
            if error != nil || (result?.isFinal ?? false) { stopNativeRecording() }
        }
    }

    private func stopNativeRecording() {
        guard isRecording else { return }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private static func makeNativeSpeechRecognizer(for language: SpeechLanguage) -> SFSpeechRecognizer? {
        let supportedLocales = SFSpeechRecognizer.supportedLocales()
        let preferredLocale = language.preferredNativeLocale
        let locale = supportedNativeLocale(preferredLocale, from: supportedLocales)
        return SFSpeechRecognizer(locale: locale)
    }

    private static func supportedNativeLocale(_ preferredLocale: Locale, from supportedLocales: Set<Locale>) -> Locale {
        if let exactMatch = supportedLocales.first(where: { normalizedLocaleID($0.identifier) == normalizedLocaleID(preferredLocale.identifier) }) {
            return exactMatch
        }

        if let languageCode = preferredLocale.language.languageCode?.identifier.lowercased(),
           let languageMatch = supportedLocales.first(where: { $0.language.languageCode?.identifier.lowercased() == languageCode }) {
            return languageMatch
        }

        return Locale(identifier: "en-US")
    }

    private static func normalizedLocaleID(_ identifier: String) -> String {
        identifier.replacingOccurrences(of: "_", with: "-").lowercased()
    }

    // MARK: - Remote (record to file, upload on stop)

    private func startRemoteRecording() {
        AVAudioApplication.requestRecordPermission { allowed in
            guard allowed else {
                permissionError = "Microphone permission denied. Enable it in Settings."
                return
            }
            beginRemoteRecording()
        }
    }

    private func beginRemoteRecording() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .default, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            permissionError = "Failed to set up audio session."
            return
        }

        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("voice-\(UUID().uuidString).m4a")
        recordedFileURL = fileURL

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
        ]
        do {
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            audioRecorder?.record()
            isRecording = true
        } catch {
            permissionError = "Failed to start recording: \(error.localizedDescription)"
        }
    }

    private func stopRemoteRecording() {
        guard isRecording || audioRecorder != nil else { return }
        audioRecorder?.stop()
        audioRecorder = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        guard let fileURL = recordedFileURL else { return }
        recordedFileURL = nil

        isTranscribing = true
        Task {
            defer { isTranscribing = false }
            do {
                let text = try await SpeechService.transcribe(audioURL: fileURL)
                transcription = text
            } catch {
                permissionError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
            try? FileManager.default.removeItem(at: fileURL)
        }
    }
}
