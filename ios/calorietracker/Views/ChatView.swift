import ImageIO
import PhotosUI
import SwiftUI
import UIKit

private final class CoachImageBox: @unchecked Sendable {
    let cgImage: CGImage
    let cost: Int

    nonisolated init(cgImage: CGImage, cost: Int) {
        self.cgImage = cgImage
        self.cost = cost
    }
}

private actor CoachImagePipeline {
    static let shared = CoachImagePipeline()

    private let cache: NSCache<NSString, CoachImageBox>

    private init() {
        let cache = NSCache<NSString, CoachImageBox>()
        cache.countLimit = 48
        cache.totalCostLimit = 18 * 1_024 * 1_024
        self.cache = cache
    }

    func image(
        data: Data,
        cacheKey: String? = nil,
        maxPixelSize: Int
    ) -> CoachImageBox? {
        let key = cacheKey.map(NSString.init)
        if let key, let cached = cache.object(forKey: key) {
            return cached
        }
        guard !Task.isCancelled else { return nil }

        let sourceOptions: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions as CFDictionary) else {
            return nil
        }

        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(maxPixelSize, 1),
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard !Task.isCancelled,
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary)
        else {
            return nil
        }

        let box = CoachImageBox(
            cgImage: cgImage,
            cost: cgImage.bytesPerRow * cgImage.height
        )
        guard !Task.isCancelled else { return nil }
        if let key {
            cache.setObject(box, forKey: key, cost: box.cost)
        }
        return box
    }
}

private struct CoachPrompt: Identifiable {
    let id: String
    let title: LocalizedStringResource
    let systemImage: String
    let accent: Color
    let rotation: Double
}

private struct CoachObservation: Identifiable {
    let id: String
    let systemImage: String
    let title: LocalizedStringResource
    let detail: LocalizedStringResource
}

private struct CoachObservationRow: View {
    let observation: CoachObservation

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: observation.systemImage)
                .font(.caption.weight(.bold))
                .frame(width: 24, height: 24)
                .overlay {
                    Circle()
                        .stroke(KitchenTablePalette.cobaltDeep.opacity(0.72), lineWidth: 0.8)
                }
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(observation.title)
                    .font(.system(.caption, design: .serif, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Text(observation.detail)
                    .font(.system(.caption2, design: .monospaced, weight: .semibold))
                    .foregroundStyle(KitchenTablePalette.cobaltDeep.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .foregroundStyle(KitchenTablePalette.cobaltDeep)
        .accessibilityElement(children: .combine)
    }
}

/// "Coach" tab — a persistent AI conversation that has access to the user's profile,
/// weight history, food log, computed forecast, and workout diary. Handles multi-turn
/// chat with memory, a reset button, and prompt chips.
struct ChatView: View {
    @Environment(ChatStore.self) private var chatStore
    @Environment(ProfileStore.self) private var profileStore
    @Environment(WeightStore.self) private var weightStore
    @Environment(BodyFatStore.self) private var bodyFatStore
    @Environment(BodyMeasurementStore.self) private var bodyMeasurementStore
    @Environment(FoodStore.self) private var foodStore
    @Environment(FastingStore.self) private var fastingStore
    @Environment(StrengthWorkoutStore.self) private var strengthWorkoutStore
    @AppStorage("heightUnit") private var heightUnitRaw = "ftin"
    @AppStorage("weightUnit") private var weightUnitRaw = "lbs"

    @State private var draft = ""
    @State private var attachedImage: UIImage?
    @State private var capturedImage: UIImage?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var showResetConfirmation = false
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var voice = CoachVoiceRecorder()
    @State private var voicePressStart: Date?
    @State private var voicePulse = false
    @State private var isKeyboardPresented = false
    @FocusState private var isInputFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var userProfile: UserProfile { profileStore.profile }
    private var messages: [ChatMessage] { chatStore.messages }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                VStack(spacing: 0) {
                    if messages.isEmpty {
                        emptyConversation(viewportHeight: proxy.size.height)
                    } else {
                        coachHeader
                        messageList
                        promptChips
                        inputArea
                            .padding(.bottom, isKeyboardPresented ? 0 : 8)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background {
                    KitchenTableBackdrop()
                        .contentShape(Rectangle())
                        .onTapGesture { isInputFocused = false }
                }
            }
            .navigationTitle("Coach")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .alert("Reset Chat", isPresented: $showResetConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    chatStore.reset()
                    errorMessage = nil
                }
            } message: {
                Text("Clear all messages and start fresh? This can't be undone.")
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraView(image: $capturedImage)
                    .ignoresSafeArea()
            }
            .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotoItem, matching: .images)
            .onChange(of: capturedImage) { _, newValue in
                guard let image = newValue else { return }
                capturedImage = nil
                attachedImage = image
                errorMessage = nil
            }
            .task(id: selectedPhotoItem) {
                guard let item = selectedPhotoItem else { return }
                defer {
                    if selectedPhotoItem == item {
                        selectedPhotoItem = nil
                    }
                }

                do {
                    guard let data = try await item.loadTransferable(type: Data.self),
                          !Task.isCancelled,
                          let result = await CoachImagePipeline.shared.image(
                              data: data,
                              maxPixelSize: 1_600
                          ),
                          !Task.isCancelled,
                          selectedPhotoItem == item
                    else {
                        if !Task.isCancelled, selectedPhotoItem == item {
                            errorMessage = "Could not load that photo."
                        }
                        return
                    }
                    attachedImage = UIImage(cgImage: result.cgImage)
                    errorMessage = nil
                } catch is CancellationError {
                    return
                } catch {
                    guard selectedPhotoItem == item else { return }
                    errorMessage = "Could not load that photo."
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                isKeyboardPresented = true
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                isKeyboardPresented = false
            }
        }
    }

    private var coachHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("AI COACH")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(KitchenTablePalette.cobalt)

                Text("Conversation")
                    .font(.system(.title3, design: .serif, weight: .bold))
                    .foregroundStyle(KitchenTablePalette.espresso)
            }

            Spacer(minLength: 8)
            resetButton
        }
        .padding(.horizontal, NeoAppMetrics.screenInset)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    private var resetButton: some View {
        Button {
            if !messages.isEmpty { showResetConfirmation = true }
        } label: {
            Image(systemName: "arrow.counterclockwise")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(messages.isEmpty ? KitchenTablePalette.mutedEspresso : KitchenTablePalette.cobalt)
                .frame(width: 44, height: 44)
                .background(
                    KitchenTablePalette.paperRaised,
                    in: Circle()
                )
                .overlay {
                    Circle()
                        .stroke(KitchenTablePalette.rule, lineWidth: NeoAppMetrics.rule)
                }
        }
        .buttonStyle(KitchenTablePressableButtonStyle())
        .disabled(messages.isEmpty)
        .accessibilityLabel("Reset chat")
    }

    // MARK: - Sections

    private func emptyConversation(viewportHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    emptyState(viewportHeight: viewportHeight)
                    promptChips
                }
                .padding(.bottom, 8)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .accessibilityIdentifier("coach.empty.scroll")

            inputArea
                .padding(
                    .bottom,
                    isKeyboardPresented ? 0 : NeoAppMetrics.bottomBarHeight + 10
                )
        }
    }

    private func emptyState(viewportHeight: CGFloat) -> some View {
        let referenceHeight = min(max(viewportHeight * 0.58, 410), 470)

        return ZStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 12) {
                Text("AI COACH · TODAY")
                    .font(.system(.caption2, design: .monospaced, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(KitchenTablePalette.cobaltDeep)

                Text(coachHeadline)
                    .font(.system(.title, design: .serif, weight: .bold))
                    .foregroundStyle(KitchenTablePalette.cobaltDeep)
                    .lineSpacing(1)

                Text(coachStatus)
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(KitchenTablePalette.espresso)
                    .fixedSize(horizontal: false, vertical: true)

                Rectangle()
                    .fill(KitchenTablePalette.cobalt.opacity(0.38))
                    .frame(height: 1)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(coachObservations) { observation in
                        CoachObservationRow(observation: observation)
                            .frame(maxHeight: .infinity, alignment: .top)
                    }
                }
                .frame(maxHeight: .infinity, alignment: .top)

                Text("FROM LOCAL LOGS + SAVED TARGETS")
                    .font(.system(.caption2, design: .monospaced, weight: .semibold))
                    .tracking(1.1)
                    .foregroundStyle(KitchenTablePalette.cobaltDeep.opacity(0.78))
            }
            .padding(.horizontal, dynamicTypeSize.isAccessibilitySize ? 16 : 22)
            .padding(.top, 30)
            .padding(.bottom, 18)
            .frame(maxWidth: .infinity, minHeight: referenceHeight, alignment: .topLeading)
            .background(KitchenTablePalette.cobalt.opacity(0.18))
            .overlay {
                Rectangle()
                    .stroke(KitchenTablePalette.cobalt.opacity(0.30), lineWidth: 1)
            }
            .shadow(color: KitchenTablePalette.shadow, radius: 5, x: 0, y: 3)
            .rotationEffect(.degrees(-0.35))

            ZStack {
                Capsule()
                    .fill(KitchenTablePalette.cobaltDeep.opacity(0.22))
                    .frame(width: 13, height: 29)
                    .rotationEffect(.degrees(16))
                    .offset(y: 5)
                Circle()
                    .fill(KitchenTablePalette.cobalt)
                    .frame(width: 22, height: 22)
                    .overlay {
                        Circle()
                            .fill(.white.opacity(0.38))
                            .frame(width: 7, height: 7)
                            .offset(x: -4, y: -4)
                    }
                    .shadow(color: KitchenTablePalette.shadow, radius: 3, x: 0, y: 2)
            }
            .offset(y: -10)
            .accessibilityHidden(true)
        }
        .frame(minHeight: referenceHeight)
        .padding(.horizontal, dynamicTypeSize.isAccessibilitySize ? 16 : 36)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .accessibilityElement(children: .contain)
    }

    private var todayFoodEntries: [FoodEntry] {
        foodStore.entries(for: .now)
    }

    private var todayCalories: Int {
        todayFoodEntries.reduce(0) { $0 + $1.calories }
    }

    private var todayProtein: Double {
        todayFoodEntries.reduce(0) { $0 + $1.protein }
    }

    private var coachHeadline: LocalizedStringResource {
        guard !todayFoodEntries.isEmpty else { return "No food logged today" }
        return "\(todayCalories.formatted()) kcal logged today"
    }

    private var coachStatus: LocalizedStringResource {
        let protein = Int(todayProtein.rounded())
        return "\(protein.formatted())g protein across \(todayFoodEntries.count.formatted()) food entries."
    }

    private var coachObservations: [CoachObservation] {
        let calorieGoal = userProfile.effectiveCalories
        let proteinGoal = userProfile.effectiveProtein
        let caloriesRemaining = calorieGoal - todayCalories
        let loggedProtein = Int(todayProtein.rounded())
        let proteinRemaining = proteinGoal - loggedProtein

        let calorieDetail: LocalizedStringResource
        if caloriesRemaining > 0 {
            calorieDetail = "\(caloriesRemaining.formatted()) kcal remain to the saved target"
        } else if caloriesRemaining < 0 {
            calorieDetail = "Logged total is \((-caloriesRemaining).formatted()) kcal above the saved target"
        } else {
            calorieDetail = "Logged total matches the saved calorie target"
        }
        let calorieObservation = CoachObservation(
            id: "calories",
            systemImage: "fork.knife",
            title: "\(todayCalories.formatted()) of \(calorieGoal.formatted()) kcal logged",
            detail: calorieDetail
        )

        let proteinDetail: LocalizedStringResource
        if proteinRemaining > 0 {
            proteinDetail = "\(proteinRemaining.formatted())g remain to the saved target"
        } else if proteinRemaining < 0 {
            proteinDetail = "Logged amount is \((-proteinRemaining).formatted())g above the saved target"
        } else {
            proteinDetail = "Logged amount matches the saved protein target"
        }
        let proteinObservation = CoachObservation(
            id: "protein",
            systemImage: "checkmark",
            title: "\(loggedProtein.formatted())g of \(proteinGoal.formatted())g protein logged",
            detail: proteinDetail
        )

        let contextObservation: CoachObservation
        if !strengthWorkoutStore.completedSessions.isEmpty {
            contextObservation = CoachObservation(
                id: "history",
                systemImage: "dumbbell.fill",
                title: "\(strengthWorkoutStore.completedSessions.count.formatted()) completed workouts saved",
                detail: "Count covers all completed workout history"
            )
        } else if !weightStore.entries.isEmpty {
            contextObservation = CoachObservation(
                id: "history",
                systemImage: "chart.line.uptrend.xyaxis",
                title: "\(weightStore.entries.count.formatted()) weigh-ins saved",
                detail: "Count covers all saved weight history"
            )
        } else {
            contextObservation = CoachObservation(
                id: "history",
                systemImage: "chart.line.uptrend.xyaxis",
                title: "No saved workout or weight entries",
                detail: "No historical entries are available for this summary"
            )
        }

        return [calorieObservation, proteinObservation, contextObservation]
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(messages) { msg in
                        MessageBubble(message: msg)
                            .id(msg.id)
                    }
                    if isSending {
                        HStack {
                            TypingIndicator()
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(NeoAppColors.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(KitchenTablePalette.rule, lineWidth: NeoAppMetrics.compactRule)
                                )
                                .padding(.leading, 4)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .id("typing")
                    }
                    if let err = errorMessage {
                        Text(err)
                            .font(.system(.caption, design: .rounded, weight: .bold))
                            .foregroundStyle(NeoAppColors.ink)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(NeoAppColors.warning.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(NeoAppColors.warning, lineWidth: NeoAppMetrics.rule)
                            )
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical, 12)
            }
            .scrollDismissesKeyboard(.immediately)
            .onAppear {
                guard let lastID = messages.last?.id else { return }
                DispatchQueue.main.async {
                    proxy.scrollTo(lastID, anchor: .bottom)
                }
            }
            .onChange(of: messages.count) { _, _ in
                withAnimation { proxy.scrollTo(messages.last?.id, anchor: .bottom) }
            }
            .onChange(of: isSending) { _, sending in
                if sending { withAnimation { proxy.scrollTo("typing", anchor: .bottom) } }
            }
            .onChange(of: isInputFocused) { _, focused in
                guard focused, let lastID = messages.last?.id else { return }
                // Animate alongside the keyboard for responsiveness.
                withAnimation(.easeOut(duration: 0.25)) {
                    proxy.scrollTo(lastID, anchor: .bottom)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidShowNotification)) { _ in
                // Fires *after* the keyboard is fully shown — by now the ScrollView's
                // safe-area inset is definitely applied, so this re-anchor catches the
                // case where the initial scroll ran against the pre-keyboard viewport
                // (bubble was hidden until the user typed and forced a re-layout).
                guard isInputFocused, let lastID = messages.last?.id else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(lastID, anchor: .bottom)
                }
            }
        }
    }

    /// Context-aware suggested prompts — every suggestion remains available.
    private var suggestedPrompts: [CoachPrompt] {
        var values: [CoachPrompt]
        switch userProfile.goal {
        case .lose:
            values = [
                CoachPrompt(id: "forecast", title: "What's my expected weight in 30 days?", systemImage: "chart.line.uptrend.xyaxis", accent: KitchenTablePalette.tomato, rotation: -0.25),
                CoachPrompt(id: "lose-safely", title: "How do I lose weight faster safely?", systemImage: "figure.walk", accent: KitchenTablePalette.herb, rotation: 0.25),
                CoachPrompt(id: "intake-check", title: "Am I eating too much?", systemImage: "fork.knife", accent: KitchenTablePalette.tomato, rotation: -0.25),
                CoachPrompt(id: "dinner", title: "What should I eat for dinner?", systemImage: "fork.knife", accent: KitchenTablePalette.herb, rotation: 0.25),
            ]
        case .gain:
            values = [
                CoachPrompt(id: "forecast", title: "What's my expected weight in 30 days?", systemImage: "chart.line.uptrend.xyaxis", accent: KitchenTablePalette.tomato, rotation: -0.25),
                CoachPrompt(id: "gain-healthily", title: "How do I gain weight healthily?", systemImage: "figure.walk", accent: KitchenTablePalette.herb, rotation: 0.25),
                CoachPrompt(id: "intake-check", title: "Am I eating enough?", systemImage: "fork.knife", accent: KitchenTablePalette.tomato, rotation: -0.25),
                CoachPrompt(id: "protein-foods", title: "High-protein foods I can add?", systemImage: "fork.knife", accent: KitchenTablePalette.herb, rotation: 0.25),
            ]
        case .maintain:
            values = [
                CoachPrompt(id: "weight-hold", title: "Am I holding my weight?", systemImage: "chart.line.uptrend.xyaxis", accent: KitchenTablePalette.tomato, rotation: -0.25),
                CoachPrompt(id: "average-intake", title: "What's my average intake?", systemImage: "fork.knife", accent: KitchenTablePalette.herb, rotation: 0.25),
                CoachPrompt(id: "macro-suggestions", title: "Macro suggestions?", systemImage: "fork.knife", accent: KitchenTablePalette.tomato, rotation: -0.25),
                CoachPrompt(id: "trend", title: "How's my trend?", systemImage: "chart.line.uptrend.xyaxis", accent: KitchenTablePalette.herb, rotation: 0.25),
            ]
        }
        if !strengthWorkoutStore.completedSessions.isEmpty {
            values.insert(
                CoachPrompt(
                    id: "training-four-weeks",
                    title: "Analyze my last 4 weeks of training",
                    systemImage: "dumbbell.fill",
                    accent: KitchenTablePalette.cobalt,
                    rotation: -0.25
                ),
                at: 0
            )
        }
        return values
    }

    private var remainingPrompts: [CoachPrompt] {
        Array(suggestedPrompts.dropFirst(2))
    }

    private var promptChips: some View {
        Group {
            if messages.isEmpty {
                VStack(spacing: 8) {
                    ForEach(suggestedPrompts.prefix(2)) { prompt in
                        promptChip(prompt, fillsWidth: true)
                    }
                    morePromptsMenu
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 4)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(suggestedPrompts) { prompt in
                            promptChip(prompt, fillsWidth: false)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
            }
        }
    }

    @ViewBuilder
    private var morePromptsMenu: some View {
        if !remainingPrompts.isEmpty {
            Menu {
                ForEach(remainingPrompts) { prompt in
                    Button {
                        sendPrompt(prompt)
                    } label: {
                        Label {
                            Text(prompt.title)
                        } icon: {
                            Image(systemName: prompt.systemImage)
                        }
                    }
                }
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: "ellipsis.circle")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(KitchenTablePalette.cobaltDeep)
                        .accessibilityHidden(true)
                    Text("More prompts")
                        .font(.system(.footnote, design: .serif, weight: .semibold))
                    Spacer(minLength: 6)
                    Text(verbatim: remainingPrompts.count.formatted())
                        .font(.system(.caption, design: .monospaced, weight: .bold))
                        .foregroundStyle(KitchenTablePalette.mutedEspresso)
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(KitchenTablePalette.mutedEspresso)
                        .accessibilityHidden(true)
                }
                .foregroundStyle(KitchenTablePalette.espresso)
                .padding(.horizontal, 13)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .background(KitchenTablePalette.paperMuted.opacity(0.68))
                .overlay {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .stroke(KitchenTablePalette.rule, style: StrokeStyle(lineWidth: 0.8, dash: [3, 2]))
                }
            }
            .disabled(isSending)
            .accessibilityLabel("More prompts")
            .accessibilityValue("\(remainingPrompts.count) additional suggestions")
            .accessibilityHint("Shows every remaining suggested Coach question")
        }
    }

    private func promptChip(_ prompt: CoachPrompt, fillsWidth: Bool) -> some View {
        let button = Button {
            sendPrompt(prompt)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: prompt.systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(prompt.accent)
                    .frame(width: 30, height: 30)
                    .background(KitchenTablePalette.paperMuted.opacity(0.72), in: Circle())
                    .accessibilityHidden(true)

                Text(prompt.title)
                    .font(.system(.footnote, design: .serif, weight: .semibold))
                    .foregroundStyle(KitchenTablePalette.espresso)
                    .multilineTextAlignment(.leading)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(KitchenTablePalette.mutedEspresso)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .frame(minHeight: 52, alignment: .leading)
            .background(KitchenTablePalette.paperRaised)
            .overlay {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .stroke(KitchenTablePalette.rule, lineWidth: 1)
            }
            .shadow(color: KitchenTablePalette.shadow, radius: 4, x: 0, y: 2)
            .rotationEffect(.degrees(prompt.rotation))
        }
        .buttonStyle(KitchenTablePressableButtonStyle())
        .disabled(isSending)

        return button
            .frame(width: fillsWidth ? nil : 250, alignment: .leading)
            .frame(maxWidth: fillsWidth ? .infinity : nil, alignment: .leading)
    }

    private func sendPrompt(_ prompt: CoachPrompt) {
        draft = String(localized: prompt.title)
        send()
    }

    private var inputArea: some View {
        VStack(spacing: 8) {
            if let attachedImage {
                attachmentPreview(attachedImage)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            inputBar
        }
        .animation(.easeInOut(duration: 0.18), value: attachedImage == nil)
        .onChange(of: voice.submittedTranscript) { _, newValue in
            guard let text = newValue, !text.isEmpty else { return }
            draft = text
            send()
            voice.submittedTranscript = nil
        }
    }

    private func attachmentPreview(_ image: UIImage) -> some View {
        HStack(spacing: 10) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 62, height: 62)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(NeoAppColors.ink, lineWidth: NeoAppMetrics.compactRule)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text("Image attached")
                    .font(.system(.subheadline, design: .rounded, weight: .black).width(.condensed))
                    .textCase(.uppercase)
                    .foregroundStyle(NeoAppColors.ink)
                Text("Send with your Coach message")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(NeoAppColors.mutedInk)
            }

            Spacer()

            Button {
                attachedImage = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(KitchenTablePalette.onBrass)
                    .frame(width: 44, height: 44)
                    .background(NeoAppColors.brass, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .stroke(KitchenTablePalette.rule, lineWidth: NeoAppMetrics.compactRule)
                    }
            }
            .buttonStyle(KitchenTablePressableButtonStyle())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .kitchenTableSurface(
            fill: NeoAppColors.surface,
            border: KitchenTablePalette.rule,
            cornerRadius: 18,
            lineWidth: NeoAppMetrics.rule,
            shadowRadius: 5,
            shadowY: 2
        )
        .padding(.horizontal, 12)
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            // Left region: attach + text field, or the live recording indicator.
            Group {
                if voice.phase == .idle {
                    HStack(spacing: 8) {
                        attachMenu
                        TextField("Ask Coach…", text: $draft, axis: .vertical)
                            .font(.system(.body, design: .serif, weight: .regular))
                            .foregroundStyle(KitchenTablePalette.espresso)
                            .lineLimit(1...5)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 12)
                            .focused($isInputFocused)
                            .accessibilityIdentifier("coach.input")
                    }
                } else {
                    recordingIndicator
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Trailing control (kept as the stable last child).
            trailingControl
        }
        .background(KitchenTablePalette.paperRaised, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(KitchenTablePalette.strongRule, lineWidth: 1)
        }
        .shadow(color: KitchenTablePalette.shadow, radius: 5, x: 0, y: 3)
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
        .padding(.top, 4)
    }

    private var attachMenu: some View {
        NeoGlassChoiceMenu(
            title: "Add to Message",
            eyebrow: "Coach",
            items: [
                NeoGlassChoiceItem(
                    id: "coachAttachment.camera",
                    title: "Camera",
                    subtitle: "Take a new photo",
                    systemImage: "camera.fill",
                    action: openCamera
                ),
                NeoGlassChoiceItem(
                    id: "coachAttachment.library",
                    title: "Photo Library",
                    subtitle: "Choose an existing image",
                    systemImage: "photo.on.rectangle",
                    action: { showPhotoPicker = true }
                )
            ]
        ) {
            Image(systemName: attachedImage == nil ? "plus.circle.fill" : "photo.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(KitchenTablePalette.cobalt)
                .frame(width: 44, height: 44)
        }
        .disabled(isSending)
        .padding(.leading, 8)
    }

    @ViewBuilder private var trailingControl: some View {
        switch voice.phase {
        case .locked:
            HStack(spacing: 8) {
                voiceCancelButton
                voiceSendButton
            }
            .padding(.trailing, 5)
        case .transcribing:
            ProgressView()
                .frame(width: 34, height: 34)
                .padding(.trailing, 8)
        case .idle where canSend:
            sendButton
                .padding(.trailing, 5)
                .animation(.easeInOut(duration: 0.15), value: canSend)
        default: // idle-empty or holding — keep the mic mounted through the press
            micButton
                .padding(.trailing, 5)
        }
    }

    private var sendButton: some View {
        Button {
            send()
        } label: {
            Image(systemName: "arrow.up")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(canSend ? KitchenTablePalette.onStrongAccent : KitchenTablePalette.mutedEspresso)
                .frame(width: 44, height: 44)
                .background(canSend ? KitchenTablePalette.cobalt : KitchenTablePalette.paperMuted, in: Circle())
                .overlay {
                    Circle().stroke(KitchenTablePalette.rule, lineWidth: NeoAppMetrics.compactRule)
                }
        }
        .disabled(!canSend)
    }

    private var micButton: some View {
        let holding = voice.phase == .holding
        return Image(systemName: "mic.fill")
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(holding ? Color.white : NeoAppColors.cobalt)
            .frame(width: 44, height: 44)
            .background(holding ? NeoAppColors.warning : NeoAppColors.subtleSurface, in: Circle())
            .overlay {
                Circle().stroke(KitchenTablePalette.rule, lineWidth: NeoAppMetrics.compactRule)
            }
            .scaleEffect(holding ? 1.25 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: holding)
            .contentShape(Rectangle())
            .gesture(micGesture)
            .id("coachMic")
    }

    private var micGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if voice.phase == .idle {
                    isInputFocused = false
                    voicePressStart = Date()
                    voice.begin()
                }
                voice.updateDrag(value.translation.width, threshold: 90)
            }
            .onEnded { value in
                let held = voicePressStart.map { Date().timeIntervalSince($0) } ?? 0
                if value.translation.width < -90 {
                    voice.cancel()
                } else if held < 0.35 && abs(value.translation.width) < 24 {
                    voice.lock()
                } else {
                    voice.stopAndSend()
                }
                voicePressStart = nil
            }
    }

    private var voiceSendButton: some View {
        Button {
            voice.stopAndSend()
        } label: {
            Image(systemName: "arrow.up")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(NeoAppColors.onCobalt)
                .frame(width: 44, height: 44)
                .background(NeoAppColors.cobalt, in: Circle())
                .overlay {
                    Circle().stroke(KitchenTablePalette.rule, lineWidth: NeoAppMetrics.compactRule)
                }
        }
    }

    private var voiceCancelButton: some View {
        Button {
            voice.cancel()
        } label: {
            Image(systemName: "trash")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(NeoAppColors.warning)
                .frame(width: 44, height: 44)
                .background(NeoAppColors.subtleSurface, in: Circle())
                .overlay {
                    Circle().stroke(KitchenTablePalette.rule, lineWidth: NeoAppMetrics.compactRule)
                }
        }
        .buttonStyle(.plain)
    }

    private var recordingIndicator: some View {
        HStack(spacing: 8) {
            if voice.phase == .transcribing {
                ProgressView().controlSize(.small)
                Text("Transcribing…")
                    .font(.system(.callout, design: .rounded, weight: .bold))
                    .foregroundStyle(NeoAppColors.mutedInk)
            } else {
                Circle()
                    .fill(Color.red)
                    .frame(width: 9, height: 9)
                    .opacity(voicePulse ? 0.3 : 1.0)
                    .onAppear {
                        if !reduceMotion {
                            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                                voicePulse = true
                            }
                        }
                    }
                    .onDisappear { voicePulse = false }
                Text(formatVoiceElapsed(voice.elapsed))
                    .font(.system(.callout, design: .rounded, weight: .black))
                    .foregroundStyle(NeoAppColors.ink)
                    .monospacedDigit()
                Text(voiceHint)
                    .font(.system(.callout, design: .rounded, weight: .semibold))
                    .foregroundStyle(voice.cancelArmed ? NeoAppColors.warning : NeoAppColors.mutedInk)
                    .lineLimit(1)
            }
        }
        .padding(.leading, 14)
        .padding(.vertical, 12)
    }

    private var voiceHint: String {
        if voice.phase == .holding {
            return voice.cancelArmed ? "Release to cancel" : "‹ slide to cancel"
        }
        return voice.liveText.isEmpty ? "Listening…" : voice.liveText
    }

    private var canSend: Bool {
        !isSending && (!draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || attachedImage != nil)
    }

    // MARK: - Send

    private func send() {
        let typedText = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        let image = attachedImage
        guard (!typedText.isEmpty || image != nil), !isSending else { return }

        let text = typedText.isEmpty ? "Analyze this image." : typedText
        let imageDataForAI = image.flatMap {
            resizedJPEGData(from: $0, maxDimension: 1600, compressionQuality: 0.78)
        }
        let thumbnailData = image.flatMap {
            resizedJPEGData(from: $0, maxDimension: 700, compressionQuality: 0.68)
        }
        if image != nil, imageDataForAI == nil {
            errorMessage = "Failed to process the image."
            return
        }

        chatStore.append(ChatMessage(role: .user, content: text, attachmentImageData: thumbnailData))
        draft = ""
        attachedImage = nil
        errorMessage = nil
        isSending = true
        let historyForCall = chatStore.contextMessages().dropLast()  // exclude the user msg we just appended

        Task {
            defer { isSending = false }
            do {
                let reply = try await ChatService.sendMessage(
                    history: Array(historyForCall),
                    newUserMessage: text,
                    imageData: imageDataForAI,
                    profile: userProfile,
                    weights: weightStore.entries,
                    bodyFats: bodyFatStore.entries,
                    measurements: bodyMeasurementStore.entries,
                    foods: foodStore.entries,
                    fastingSessions: fastingStore.sessions,
                    heightMetric: heightUnitRaw == "cm",
                    weightMetric: weightUnitRaw == "kg",
                    workoutSessions: strengthWorkoutStore.completedSessions,
                    workoutPlans: Array(strengthWorkoutStore.dayPlans.values),
                    workoutPreferences: strengthWorkoutStore.preferences,
                    workoutAccessEnabled: true
                )
                chatStore.append(ChatMessage(role: .assistant, content: reply))
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    private func openCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            errorMessage = "Camera is not available on this device."
            return
        }
        showCamera = true
    }

    private func resizedJPEGData(from image: UIImage, maxDimension: CGFloat, compressionQuality: CGFloat) -> Data? {
        let originalSize = image.size
        let longestSide = max(originalSize.width, originalSize.height)
        guard longestSide > 0 else {
            return image.jpegData(compressionQuality: compressionQuality)
        }

        let scale = min(1, maxDimension / longestSide)
        let targetSize = CGSize(width: originalSize.width * scale, height: originalSize.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return resized.jpegData(compressionQuality: compressionQuality)
    }
}

// MARK: - Supporting views

/// Lightweight Markdown renderer for assistant chat bubbles — handles the formatting the Coach
/// actually emits: #/##/### headings, "- / * / 1." lists, ``` code fences ```, `inline code`,
/// **bold**, *italic*, and [links](url). Block layout is done here; inline styling uses
/// AttributedString's inline-only markdown so no third-party dependency is needed.
private struct MarkdownMessageText: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(parse(text)) { block in
                switch block.kind {
                case .heading(let level):
                    Text(inline(block.text))
                        .font(.system(headingStyle(level), design: .rounded, weight: .black).width(.condensed))
                case .bullet:
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("•").font(.system(.body, design: .rounded))
                        Text(inline(block.text)).font(.system(.body, design: .rounded))
                    }
                case .numbered(let number):
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(number).").font(.system(.body, design: .rounded, weight: .medium))
                        Text(inline(block.text)).font(.system(.body, design: .rounded))
                    }
                case .code:
                    Text(block.text)
                        .font(.system(.callout, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(NeoAppColors.subtleSurface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(KitchenTablePalette.rule, lineWidth: NeoAppMetrics.compactRule)
                        }
                case .paragraph:
                    Text(inline(block.text)).font(.system(.body, design: .rounded))
                }
            }
        }
    }

    private func headingStyle(_ level: Int) -> Font.TextStyle {
        switch level {
        case 1: return .title3
        case 2: return .headline
        default: return .subheadline
        }
    }

    private func inline(_ string: String) -> AttributedString {
        (try? AttributedString(markdown: string, options: .init(
            interpretedSyntax: .inlineOnlyPreservingWhitespace,
            failurePolicy: .returnPartiallyParsedIfPossible
        ))) ?? AttributedString(string)
    }

    private struct Block: Identifiable {
        enum Kind: Equatable { case heading(Int), bullet, numbered(String), code, paragraph }
        let id = UUID()
        let kind: Kind
        let text: String
    }

    private func parse(_ raw: String) -> [Block] {
        var blocks: [Block] = []
        let lines = raw.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        var index = 0
        while index < lines.count {
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("```") {
                var codeLines: [String] = []
                index += 1
                while index < lines.count, !lines[index].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    codeLines.append(lines[index])
                    index += 1
                }
                index += 1 // skip the closing fence
                blocks.append(Block(kind: .code, text: codeLines.joined(separator: "\n")))
                continue
            }

            if trimmed.isEmpty { index += 1; continue }

            if let level = headingLevel(trimmed) {
                let content = String(trimmed.drop(while: { $0 == "#" })).trimmingCharacters(in: .whitespaces)
                blocks.append(Block(kind: .heading(level), text: content))
            } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") {
                blocks.append(Block(kind: .bullet, text: String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)))
            } else if let (number, rest) = numberedItem(trimmed) {
                blocks.append(Block(kind: .numbered(number), text: rest))
            } else {
                blocks.append(Block(kind: .paragraph, text: trimmed))
            }
            index += 1
        }
        return blocks
    }

    private func headingLevel(_ string: String) -> Int? {
        let hashes = string.prefix(while: { $0 == "#" }).count
        guard hashes >= 1, hashes <= 3, string.dropFirst(hashes).first == " " else { return nil }
        return hashes
    }

    private func numberedItem(_ string: String) -> (String, String)? {
        guard let dotIndex = string.firstIndex(of: ".") else { return nil }
        let numberPart = string[string.startIndex..<dotIndex]
        guard !numberPart.isEmpty, numberPart.allSatisfy(\.isNumber),
              string[string.index(after: dotIndex)...].first == " " else { return nil }
        let rest = String(string[string.index(after: dotIndex)...]).trimmingCharacters(in: .whitespaces)
        return (String(numberPart), rest)
    }
}

private struct CoachMessageAttachmentImage: View {
    private struct LoadedImage {
        let requestKey: String
        let image: UIImage
    }

    let messageID: UUID
    let imageData: Data

    @Environment(\.displayScale) private var displayScale
    @State private var loadedImage: LoadedImage?

    private var maxPixelSize: Int {
        max(Int((196 * displayScale).rounded(.up)), 1)
    }

    private var requestKey: String {
        "\(messageID.uuidString)|\(imageData.count)|\(maxPixelSize)"
    }

    var body: some View {
        ZStack {
            KitchenTablePalette.paperMuted.opacity(0.45)

            if let loadedImage, loadedImage.requestKey == requestKey {
                Image(uiImage: loadedImage.image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(KitchenTablePalette.mutedEspresso)
            }
        }
        .task(id: requestKey) {
            loadedImage = nil
            let result = await CoachImagePipeline.shared.image(
                data: imageData,
                cacheKey: requestKey,
                maxPixelSize: maxPixelSize
            )
            guard !Task.isCancelled, let result else { return }
            loadedImage = LoadedImage(
                requestKey: requestKey,
                image: UIImage(cgImage: result.cgImage)
            )
        }
    }
}

private struct MessageBubble: View {
    let message: ChatMessage

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if !isUser {
                assistantBadge
            } else {
                Spacer(minLength: 48)
            }

            bubble

            if isUser {
                // no trailing icon
            } else {
                Spacer(minLength: 48)
            }
        }
        .padding(.horizontal)
    }

    private var assistantBadge: some View {
        ZStack {
            Capsule()
                .fill(KitchenTablePalette.cobaltDeep.opacity(0.20))
                .frame(width: 9, height: 23)
                .rotationEffect(.degrees(14))
                .offset(y: 4)
            Circle()
                .fill(KitchenTablePalette.cobalt)
                .frame(width: 20, height: 20)
                .shadow(color: KitchenTablePalette.shadow, radius: 2, x: 0, y: 1)
        }
        .padding(.top, 3)
        .accessibilityHidden(true)
    }

    private var bubble: some View {
        VStack(alignment: .leading, spacing: 9) {
            if !isUser {
                Text("Coach")
                    .textCase(.uppercase)
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(KitchenTablePalette.cobaltDeep)
            }

            if let imageData = message.attachmentImageData {
                CoachMessageAttachmentImage(
                    messageID: message.id,
                    imageData: imageData
                )
                    .frame(width: 196, height: 140)
                    .compositingGroup()
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(KitchenTablePalette.rule, lineWidth: NeoAppMetrics.compactRule)
                    )
            }

            if isUser {
                // User's own typed text — show verbatim, no markdown.
                Text(message.content)
                    .font(.system(.body, design: .serif, weight: .regular))
                    .textSelection(.enabled)
                    .foregroundStyle(KitchenTablePalette.espresso)
            } else {
                // Coach replies often use markdown — render it.
                MarkdownMessageText(text: message.content)
                    .textSelection(.enabled)
                    .foregroundStyle(KitchenTablePalette.espresso)
            }
        }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background(bubbleBackground)
            .overlay(bubbleStroke)
            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            .shadow(color: KitchenTablePalette.shadow, radius: 4, x: 0, y: 2)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var bubbleBackground: some View {
        if isUser {
            KitchenTablePalette.paperRaised
        } else {
            KitchenTablePalette.cobalt.opacity(0.14)
        }
    }

    private var bubbleStroke: some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .stroke(
                isUser ? KitchenTablePalette.tomato.opacity(0.34) : KitchenTablePalette.cobalt.opacity(0.32),
                lineWidth: 1
            )
    }
}

private struct TypingIndicator: View {
    @State private var phase = 0
    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(NeoAppColors.cobalt)
                    .frame(width: 7, height: 7)
                    .opacity(phase == i ? 1 : 0.3)
                    .scaleEffect(phase == i ? 1.15 : 1.0)
                    .animation(.easeInOut(duration: 0.35), value: phase)
            }
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { _ in
                phase = (phase + 1) % 3
            }
        }
    }
}
