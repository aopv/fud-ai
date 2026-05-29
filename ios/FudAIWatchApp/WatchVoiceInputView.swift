import SwiftUI

struct WatchVoiceInputView: View {
    @StateObject private var logger = WatchVoiceLogger()
    @State private var text = ""
    @FocusState private var fieldFocused: Bool

    var body: some View {
        ZStack {
            switch logger.state {
            case .idle:
                idleView
            case .processing:
                processingView
            case .success(let name, let calories, let protein):
                successView(name: name, calories: calories, protein: protein)
            case .error(let message):
                errorView(message: message)
            }
        }
        .navigationTitle("Log Food")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { logger.reset() }
    }

    // MARK: - States

    private var idleView: some View {
        VStack(spacing: 10) {
            // Tapping the field opens the watchOS input controller (Dictation /
            // Scribble / keyboard). Dictation handles audio + multilingual STT.
            TextField("Say what you ate", text: $text)
                .focused($fieldFocused)
                .submitLabel(.done)
                .onSubmit(submit)

            Button(action: submit) {
                Label("Log", systemImage: "checkmark")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity)
            }
            .tint(.red)
            .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, 4)
        .onAppear { fieldFocused = true }
    }

    private var processingView: some View {
        VStack(spacing: 8) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Analyzing...")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
    }

    private func successView(name: String, calories: Int, protein: Double) -> some View {
        VStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 30))
                .foregroundStyle(.green)

            Text(name)
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.8)

            Text("\(calories) kcal · \(String(format: "%.0f", protein))g protein")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Button("Done") { resetForNewEntry() }
                .font(.system(size: 13, weight: .medium))
                .tint(.green)
        }
        .padding(.horizontal, 8)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 26))
                .foregroundStyle(.orange)

            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(4)
                .minimumScaleFactor(0.8)

            Button("Try Again") { resetForNewEntry() }
                .font(.system(size: 13))
                .tint(.orange)
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Actions

    private func submit() {
        let candidate = text
        logger.submit(transcript: candidate)
    }

    private func resetForNewEntry() {
        text = ""
        logger.reset()
        fieldFocused = true
    }
}
