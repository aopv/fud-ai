import SwiftUI
import HealthKit
import StoreKit

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @Environment(NotificationManager.self) private var notificationManager
    @Environment(FoodStore.self) private var foodStore
    @Environment(WeightStore.self) private var weightStore
    @Environment(HealthKitManager.self) private var healthKitManager

    @State private var step = 0
    @State private var gender: Gender = .male
    @State private var birthday: Date = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
    @AppStorage("heightUnit") private var heightUnitRaw = "ftin"
    @AppStorage("weightUnit") private var weightUnitRaw = "lbs"
    @AppStorage("aiAnalysisConsentGiven") private var aiConsentGiven = false
    @AppStorage("acceptedTermsAndPrivacy") private var acceptedTermsAndPrivacy = false
    // Segmented Imperial | Metric control state. Seeded from the split unit prefs
    // (Metric only when both are metric) and writes BOTH prefs coherently onChange.
    @State private var isMetric = UserDefaults.standard.string(forKey: "heightUnit") == "cm"
        && UserDefaults.standard.string(forKey: "weightUnit") == "kg"
    @State private var heightFeet = 5
    @State private var heightInches = 9
    @State private var heightCm = 175
    // Weights are split into whole + tenth so the SwiftUI wheel picker can stay
    // Int-tagged (fractional tags don't pair cleanly with Picker) while users
    // still get 0.1-precision selection. Combine via `Double(whole) + Double(tenth) / 10.0`.
    @State private var weightLbsWhole = 154
    @State private var weightLbsTenth = 0
    @State private var weightKgWhole = 70
    @State private var weightKgTenth = 0
    @State private var activityLevel: ActivityLevel = .moderate
    @State private var goal: WeightGoal = .maintain
    @State private var targetWeightLbsWhole = 154
    @State private var targetWeightLbsTenth = 0
    @State private var targetWeightKgWhole = 70
    @State private var targetWeightKgTenth = 0
    @State private var goalSpeed = 1
    @State private var knowsBodyFat = false
    @State private var bodyFatPercentage = 20
    /// Optional target body-fat % (whole number, 3–60). Nil means "skip" — the
    /// user opted out, or hasn't entered a current body fat (the goal field
    /// only appears when knowsBodyFat is true).
    @State private var goalBodyFatPercentInt: Int? = nil
    @State private var editedCalories: Int?
    @State private var editedProtein: Int?
    @State private var editedFat: Int?
    @State private var editedCarbs: Int?
    @State private var editingField: EditableField?
    @State private var showCalculationSources = false
    @State private var hasAcceptedTerms = false
    // BYOK setup captured in onboarding (step 11) so AI is ready for the plan calc.
    @State private var byokProvider: AIProvider = AIProviderSettings.selectedProvider
    @State private var byokModel: String = AIProviderSettings.selectedModel
    @State private var byokApiKey: String = AIProviderSettings.currentAPIKey ?? ""
    @State private var byokBaseURL: String = AIProviderSettings.customBaseURL(for: AIProviderSettings.selectedProvider) ?? ""
    @State private var showByokKey = false
    /// AI-computed targets from the Building Plan step; seeds the Plan Ready screen.
    @State private var aiGoal: GeminiService.GoalCalculation?

    private enum EditableField: String, Identifiable {
        case calories, protein, fat, carbs
        var id: String { rawValue }
    }

    private let totalSteps = 14 // 0-13

    /// Combine the whole + tenth wheel selections into a single Double.
    private func combine(_ whole: Int, _ tenth: Int) -> Double { Double(whole) + Double(tenth) / 10.0 }

    private var weightKg: Double { combine(weightKgWhole, weightKgTenth) }
    private var weightLbs: Double { combine(weightLbsWhole, weightLbsTenth) }
    private var targetWeightKg: Double { combine(targetWeightKgWhole, targetWeightKgTenth) }
    private var targetWeightLbs: Double { combine(targetWeightLbsWhole, targetWeightLbsTenth) }

    private var isHeightMetric: Bool { heightUnitRaw == "cm" }
    private var isWeightMetric: Bool { weightUnitRaw == "kg" }

    private var profile: UserProfile {
        let cm: Double = isHeightMetric
            ? Double(heightCm)
            : Double(heightFeet) * 30.48 + Double(heightInches) * 2.54
        let kg: Double = isWeightMetric ? weightKg : weightLbs * 0.453592
        let targetKg: Double? = goal == .maintain ? nil : (isWeightMetric ? targetWeightKg : targetWeightLbs * 0.453592)
        return UserProfile(
            gender: gender,
            birthday: birthday,
            heightCm: cm,
            weightKg: kg,
            activityLevel: activityLevel,
            goal: goal,
            bodyFatPercentage: knowsBodyFat ? Double(bodyFatPercentage) / 100.0 : nil,
            goalBodyFatPercentage: knowsBodyFat ? goalBodyFatPercentInt.map { Double($0) / 100.0 } : nil,
            weeklyChangeKg: goal == .maintain ? nil : weeklyChangeKg,
            goalWeightKg: targetKg
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            if step > 0 && step < totalSteps - 1 {
                HStack(spacing: 10) {
                    Button {
                        withAnimation(.snappy) { step -= 1 }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(NeoAppColors.onCobalt)
                            .frame(width: 44, height: 44)
                            .background(NeoAppColors.cobalt)
                            .overlay {
                                Rectangle()
                                    .stroke(NeoAppColors.ink, lineWidth: NeoAppMetrics.rule)
                            }
                    }
                    .buttonStyle(.plain)
                    .neoInteractiveSurface(cornerRadius: NeoAppMetrics.cornerRadius)
                    .accessibilityLabel("Back")
                    .accessibilityIdentifier("onboarding.back")

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("PROFILE SETUP")
                            Spacer(minLength: 8)
                            Text("\(step) / \(totalSteps - 1)")
                        }
                        .font(.system(size: 10, weight: .black, design: .rounded).width(.condensed))
                        .foregroundStyle(NeoAppColors.ink)

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(NeoAppColors.subtleSurface)
                                Rectangle()
                                    .fill(NeoAppColors.acid)
                                    .frame(width: geo.size.width * CGFloat(step) / CGFloat(totalSteps - 1))
                                    .animation(.snappy, value: step)
                            }
                            .overlay {
                                Rectangle()
                                    .stroke(NeoAppColors.ink, lineWidth: NeoAppMetrics.compactRule)
                            }
                        }
                        .frame(height: 8)
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 44)
                    .background(NeoAppColors.surface)
                    .overlay {
                        Rectangle()
                            .stroke(NeoAppColors.ink, lineWidth: NeoAppMetrics.rule)
                    }
                }
                .padding(.horizontal, NeoAppMetrics.screenInset)
                .padding(.top, 12)
                .padding(.bottom, 8)
            }

            ZStack {
                switch step {
                case 0: welcomeStep
                case 1: genderStep
                case 2: birthdayStep
                case 3: heightWeightStep
                case 4: bodyFatStep
                case 5: activityStep
                case 6: goalStep
                case 7: desiredWeightStep
                case 8: goalSpeedStep
                case 9: notificationsStep
                case 10: appleHealthStep
                case 11: aiProviderStep
                case 12: buildingPlanStep
                case 13: planReadyStep
                default: EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
            .animation(.snappy, value: step)
        }
        .neoScreen()
        .accessibilityIdentifier("onboarding.flow")
    }

    // MARK: - Continue Button

    private func continueButton(_ title: String = "Continue", action: @escaping () -> Void = {}) -> some View {
        Button {
            action()
            withAnimation(.snappy) { step += 1 }
        } label: {
            Label(title.uppercased(), systemImage: "arrow.right")
                .font(.system(.body, design: .rounded, weight: .black).width(.condensed))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(NeoOnboardingPrimaryButtonStyle())
        .accessibilityIdentifier("onboarding.continue")
        .padding(.horizontal, NeoAppMetrics.screenInset)
        .padding(.bottom, 36)
    }

    // MARK: - 0: Welcome

    private var welcomeStep: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 0) {
                NeoSectionBanner(title: "FÜD AI", detail: "NUTRITION OS", style: .cobalt)

                VStack(spacing: 18) {
                    Image("onboardingLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 104, height: 104)
                        .padding(10)
                        .background(NeoAppColors.acid)
                        .overlay {
                            Rectangle()
                                .stroke(NeoAppColors.ink, lineWidth: NeoAppMetrics.rule)
                        }

                    VStack(spacing: 2) {
                        Text("EAT SMART.")
                        Text("LIVE BETTER.")
                            .foregroundStyle(NeoAppColors.cobalt)
                    }
                    .font(.system(size: 34, weight: .black, design: .rounded).width(.condensed))
                    .multilineTextAlignment(.center)

                    Text("Just snap, track, and thrive.\nYour nutrition, simplified.")
                        .font(.system(.callout, design: .rounded, weight: .bold))
                        .foregroundStyle(NeoAppColors.mutedInk)
                        .multilineTextAlignment(.center)

                    VStack(alignment: .leading, spacing: 0) {
                        welcomeFeatureRow(icon: "camera.fill", text: "Snap a photo — AI logs it")
                        welcomeFeatureRow(icon: "bubble.left.and.bubble.right.fill", text: "Coach that knows your data")
                        welcomeFeatureRow(icon: "dumbbell.fill", text: "870+ exercise library")
                        welcomeFeatureRow(icon: "applewatch", text: "Widgets & Apple Watch")
                    }
                    .overlay {
                        Rectangle()
                            .stroke(NeoAppColors.ink, lineWidth: NeoAppMetrics.rule)
                    }
                }
                .padding(18)
                .background(NeoAppColors.surface)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(NeoAppColors.ink)
                        .frame(height: NeoAppMetrics.rule)
                }
            }
            .padding(.horizontal, NeoAppMetrics.screenInset)
            Spacer()

            Button {
                withAnimation(.snappy) { step += 1 }
            } label: {
                Label("GET STARTED", systemImage: "bolt.fill")
                    .font(.system(.headline, design: .rounded, weight: .black).width(.condensed))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(NeoOnboardingPrimaryButtonStyle())
            .accessibilityIdentifier("onboarding.getStarted")
            .padding(.horizontal, NeoAppMetrics.screenInset)
            .padding(.bottom, 36)
        }
    }

    // MARK: - 1: Gender

    private var genderStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            stepHeader(title: "What's your gender?", subtitle: "This helps us calculate your metabolism")
            Spacer()
            VStack(spacing: 12) {
                ForEach(Gender.allCases, id: \.self) { g in
                    selectionCard(icon: g.icon, title: g.displayName, isSelected: gender == g) {
                        withAnimation(.spring(response: 0.3)) { gender = g }
                    }
                }
            }
            .padding(.horizontal, NeoAppMetrics.screenInset)
            Spacer()
            continueButton()
        }
    }

    // MARK: - 2: Birthday

    private var birthdayStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            stepHeader(title: "When's your birthday?", subtitle: "Used to calculate your daily needs")
            Spacer()
            NeoOutlinedPanel(padding: 0) {
                DatePicker("Birthday", selection: $birthday, in: ...Date(), displayedComponents: .date)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .tint(NeoAppColors.cobalt)
            }
            .padding(.horizontal, NeoAppMetrics.screenInset)
            Spacer()
            continueButton()
        }
    }

    // MARK: - 3: Height & Weight

    private var heightWeightStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            stepHeader(title: "Height & Weight", subtitle: "We'll keep this private")
            Picker("Unit", selection: $isMetric) {
                Text("Imperial").tag(false)
                Text("Metric").tag(true)
            }
            .pickerStyle(.segmented)
            .tint(NeoAppColors.cobalt)
            .padding(10)
            .neoPanel()
            .padding(.horizontal, NeoAppMetrics.screenInset)
            .padding(.top, 12)
            .onChange(of: isMetric) { _, newValue in
                heightUnitRaw = newValue ? "cm" : "ftin"
                weightUnitRaw = newValue ? "kg" : "lbs"
            }
            Spacer()
            // Stack height + weight as two rows so the weight picker (whole +
            // "." + tenth + unit = 4 sub-cells) gets the full screen width
            // instead of competing with feet/inches for one-third of it. The
            // 3-column imperial layout used to render the lbs whole-number
            // wheel as "..." because there wasn't enough width for 3-digit
            // values like 152 alongside the decimal column.
            // Each wheel reads its own split unit pref, so mixed configurations
            // (e.g. ft/in + kg) render correctly when re-entering onboarding.
            NeoOutlinedPanel {
                VStack(spacing: 8) {
                    if isHeightMetric {
                        VStack(spacing: 4) {
                            Text("HEIGHT")
                                .font(.system(.caption, design: .rounded, weight: .black).width(.condensed))
                                .foregroundStyle(NeoAppColors.cobalt)
                            Picker("cm", selection: $heightCm) {
                                ForEach(100...250, id: \.self) { cm in Text("\(cm) cm").tag(cm) }
                            }.pickerStyle(.wheel).frame(height: 130)
                        }
                    } else {
                        HStack(spacing: 8) {
                            VStack(spacing: 4) {
                                Text("FEET")
                                    .font(.system(.caption, design: .rounded, weight: .black).width(.condensed))
                                    .foregroundStyle(NeoAppColors.cobalt)
                                Picker("ft", selection: $heightFeet) {
                                    ForEach(3...8, id: \.self) { ft in Text("\(ft) ft").tag(ft) }
                                }.pickerStyle(.wheel).frame(height: 130)
                            }
                            VStack(spacing: 4) {
                                Text("INCHES")
                                    .font(.system(.caption, design: .rounded, weight: .black).width(.condensed))
                                    .foregroundStyle(NeoAppColors.cobalt)
                                Picker("in", selection: $heightInches) {
                                    ForEach(0...11, id: \.self) { inch in Text("\(inch) in").tag(inch) }
                                }.pickerStyle(.wheel).frame(height: 130)
                            }
                        }
                    }
                    Rectangle()
                        .fill(NeoAppColors.ink)
                        .frame(height: NeoAppMetrics.compactRule)
                    VStack(spacing: 4) {
                        Text(LocalizedDisplayText.text("WEIGHT"))
                            .font(.system(.caption, design: .rounded, weight: .black).width(.condensed))
                            .foregroundStyle(NeoAppColors.cobalt)
                        if isWeightMetric {
                            decimalWeightWheel(whole: $weightKgWhole, tenth: $weightKgTenth, range: 30...250, unit: "kg")
                                .frame(height: 130)
                        } else {
                            decimalWeightWheel(whole: $weightLbsWhole, tenth: $weightLbsTenth, range: 60...500, unit: "lbs")
                                .frame(height: 130)
                        }
                    }
                }
            }
            .padding(.horizontal, NeoAppMetrics.screenInset)
            Spacer()
            continueButton()
        }
    }

    // MARK: - 4: Body Fat

    private var bodyFatStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            stepHeader(title: "Do you know your\nbody fat %?", subtitle: "Helps us calculate your metabolism more accurately")
            Spacer()
            VStack(spacing: 12) {
                selectionCard(icon: "checkmark.square", title: "Yes", isSelected: knowsBodyFat) {
                    withAnimation(.spring(response: 0.3)) { knowsBodyFat = true }
                }
                selectionCard(icon: "xmark.square", title: "No", isSelected: !knowsBodyFat) {
                    withAnimation(.spring(response: 0.3)) { knowsBodyFat = false }
                }
            }
            .padding(.horizontal, NeoAppMetrics.screenInset)
            if knowsBodyFat {
                ScrollView {
                    VStack(spacing: 16) {
                        NeoOutlinedPanel {
                            VStack(spacing: 4) {
                                Text("CURRENT BODY FAT")
                                    .font(.system(.subheadline, design: .rounded, weight: .black).width(.condensed))
                                    .foregroundStyle(NeoAppColors.cobalt)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Picker("Body Fat %", selection: $bodyFatPercentage) {
                                    ForEach(3...60, id: \.self) { pct in Text("\(pct)%").tag(pct) }
                                }
                                .pickerStyle(.wheel)
                                .frame(height: 130)
                                Text("COMMON RANGES: MEN 10–25% • WOMEN 18–35%")
                                    .font(.system(.caption, design: .rounded, weight: .bold).width(.condensed))
                                    .foregroundStyle(NeoAppColors.mutedInk)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.horizontal, NeoAppMetrics.screenInset)

                        NeoOutlinedPanel {
                            VStack(spacing: 4) {
                                HStack {
                                    Text("GOAL (OPTIONAL)")
                                        .font(.system(.subheadline, design: .rounded, weight: .black).width(.condensed))
                                        .foregroundStyle(NeoAppColors.cobalt)
                                    Spacer()
                                    Toggle("", isOn: Binding(
                                        get: { goalBodyFatPercentInt != nil },
                                        set: { isOn in
                                            // Default the goal to the current value
                                            // when toggled on — gives the user a sane
                                            // starting point to scroll up/down from.
                                            goalBodyFatPercentInt = isOn ? bodyFatPercentage : nil
                                        }
                                    ))
                                    .labelsHidden()
                                    .tint(NeoAppColors.cobalt)
                                }

                                if let _ = goalBodyFatPercentInt {
                                    Picker("Goal Body Fat %", selection: Binding(
                                        get: { goalBodyFatPercentInt ?? bodyFatPercentage },
                                        set: { goalBodyFatPercentInt = $0 }
                                    )) {
                                        ForEach(3...60, id: \.self) { pct in Text("\(pct)%").tag(pct) }
                                    }
                                    .pickerStyle(.wheel)
                                    .frame(height: 110)
                                } else {
                                    Text("You can set this later in Settings.")
                                        .font(.system(.caption, design: .rounded, weight: .bold))
                                        .foregroundStyle(NeoAppColors.mutedInk)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.top, 4)
                                }
                            }
                        }
                        .padding(.horizontal, NeoAppMetrics.screenInset)
                    }
                    .padding(.vertical, 8)
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "function")
                        .font(.system(size: 28, weight: .black))
                        .foregroundStyle(NeoAppColors.cobalt)
                    Text("No worries! We'll use a standard formula\nbased on your height, weight, and age.")
                        .font(.system(.callout, design: .rounded, weight: .bold))
                        .foregroundStyle(NeoAppColors.mutedInk)
                        .multilineTextAlignment(.center)
                }
                .padding(18)
                .frame(maxWidth: .infinity)
                .neoPanel()
                .padding(.horizontal, NeoAppMetrics.screenInset)
                .padding(.top, 24)
            }
            Spacer()
            continueButton()
        }
    }

    // MARK: - 5: Activity Level

    private var activityStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            stepHeader(
                title: "How active are you?",
                subtitle: LocalizedDisplayText.text(
                    "Choose based on your average week, including work and exercise.",
                    polish: "Wybierz na podstawie typowego tygodnia, uwzględniając pracę i ćwiczenia."
                )
            )
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(ActivityLevel.allCases, id: \.self) { level in
                        selectionCard(icon: level.icon, title: level.displayName, subtitle: level.subtitle, isSelected: activityLevel == level) {
                            withAnimation(.spring(response: 0.3)) { activityLevel = level }
                        }
                    }
                }
                .padding(.horizontal, NeoAppMetrics.screenInset)
                .padding(.vertical, 16)
            }
            continueButton()
        }
    }

    // MARK: - 6: Goal

    private var goalStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            stepHeader(title: "What's your goal?", subtitle: "You can change this anytime")
            Spacer()
            VStack(spacing: 12) {
                ForEach(WeightGoal.allCases, id: \.self) { g in
                    selectionCard(icon: g.icon, title: g.displayName, isSelected: goal == g) {
                        withAnimation(.spring(response: 0.3)) { goal = g }
                    }
                }
            }
            .padding(.horizontal, NeoAppMetrics.screenInset)
            Spacer()
            continueButton {
                // Seed the desired-weight wheels from the current weight + a
                // direction-appropriate offset. Whole-number offsets (5/10) are
                // fine — the user can fine-tune the tenth wheel in the next step.
                let lbsDelta = goal == .lose ? -10 : (goal == .gain ? 10 : 0)
                let kgDelta  = goal == .lose ? -5  : (goal == .gain ? 5  : 0)
                let newLbsWhole = max(60, weightLbsWhole + lbsDelta)
                let newKgWhole  = max(30, weightKgWhole + kgDelta)
                targetWeightLbsWhole = newLbsWhole
                targetWeightLbsTenth = weightLbsTenth
                targetWeightKgWhole  = newKgWhole
                targetWeightKgTenth  = weightKgTenth
            }
        }
    }

    // MARK: - 7: Desired Weight

    private var weightUnit: String { isWeightMetric ? "kg" : "lbs" }

    private var weightDiffKg: Double {
        let currentKg = isWeightMetric ? weightKg : weightLbs * 0.453592
        let targetKg = isWeightMetric ? targetWeightKg : targetWeightLbs * 0.453592
        return abs(targetKg - currentKg)
    }

    private var desiredWeightStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            stepHeader(title: "What's your\ndesired weight?", subtitle: goal.displayName)
            Spacer()
            if isWeightMetric {
                NeoOutlinedPanel {
                    decimalWeightWheel(whole: $targetWeightKgWhole, tenth: $targetWeightKgTenth, range: 30...250, unit: "kg")
                        .frame(height: 150)
                }
                .padding(.horizontal, NeoAppMetrics.screenInset)
            } else {
                NeoOutlinedPanel {
                    decimalWeightWheel(whole: $targetWeightLbsWhole, tenth: $targetWeightLbsTenth, range: 60...500, unit: "lbs")
                        .frame(height: 150)
                }
                .padding(.horizontal, NeoAppMetrics.screenInset)
            }
            Spacer()
            continueButton()
        }
    }

    /// Reusable iOS-26-style two-wheel decimal picker for body weight (whole +
    /// tenth + unit suffix). Keeps the wheel selections Int-tagged — Picker
    /// doesn't pair cleanly with Double tags — and the parent computes the
    /// combined Double via `combine(_:_:)`.
    private func decimalWeightWheel(whole: Binding<Int>, tenth: Binding<Int>, range: ClosedRange<Int>, unit: String) -> some View {
        HStack(spacing: 0) {
            Picker("whole", selection: whole) {
                ForEach(range, id: \.self) { n in Text("\(n)").tag(n) }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .clipped()

            Text(".")
                .font(.system(size: 24, weight: .black, design: .rounded))
                .offset(y: -1)
                .foregroundStyle(NeoAppColors.cobalt)

            Picker("tenth", selection: tenth) {
                ForEach(0...9, id: \.self) { n in Text("\(n)").tag(n) }
            }
            .pickerStyle(.wheel)
            .frame(width: 56)
            .clipped()

            Text(unit)
                .font(.system(.caption, design: .rounded, weight: .black).width(.condensed))
                .foregroundStyle(NeoAppColors.mutedInk)
                .padding(.leading, 4)
        }
    }

    // MARK: - 8: Goal Speed

    private var weeklyChangeKg: Double {
        switch goalSpeed { case 0: 0.25; case 2: 1.0; default: 0.5 }
    }

    private var estimatedDays: Int {
        guard weightDiffKg > 0 else { return 0 }
        return Int(weightDiffKg / weeklyChangeKg * 7)
    }

    private var goalSpeedStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            stepHeader(
                title: goal == .maintain ? "Your pace" : "How fast do you want\nto reach your goal?",
                subtitle: goal == .maintain ? "We'll set a balanced plan" : "\(goal == .lose ? "Weight loss" : "Weight gain") speed per week"
            )
            if goal == .maintain {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 48, weight: .black))
                        .foregroundStyle(NeoAppColors.cobalt)
                    Text("BALANCED PACE SET")
                        .font(.system(.title3, design: .rounded, weight: .black).width(.condensed))
                    Text("We'll keep your calories steady\nto maintain your current weight.")
                        .font(.system(.callout, design: .rounded, weight: .bold))
                        .foregroundStyle(NeoAppColors.mutedInk)
                        .multilineTextAlignment(.center)
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .neoPanel()
                .padding(.horizontal, NeoAppMetrics.screenInset)
                Spacer()
            } else {
                Spacer()
                VStack(spacing: 24) {
                    VStack(spacing: 4) {
                        Text("\(WeightDisplayFormatter.weeklyChangeValue(kilograms: weeklyChangeKg, useMetric: isWeightMetric)) \(weightUnit)")
                            .font(.system(size: 40, weight: .black, design: .rounded).width(.condensed))
                            .foregroundStyle(NeoAppColors.cobalt)
                            .contentTransition(.numericText()).animation(.snappy, value: goalSpeed)
                        Text("PER WEEK")
                            .font(.system(.callout, design: .rounded, weight: .black).width(.condensed))
                            .foregroundStyle(NeoAppColors.mutedInk)
                    }
                    HStack(spacing: 0) {
                        VStack(spacing: 6) {
                            Image(systemName: "tortoise.fill").font(.system(size: 24))
                                .foregroundStyle(goalSpeed == 0 ? NeoAppColors.cobalt : NeoAppColors.mutedInk.opacity(0.4))
                            Text("SLOW").font(.system(.caption, design: .rounded, weight: .black).width(.condensed))
                                .foregroundStyle(goalSpeed == 0 ? NeoAppColors.cobalt : NeoAppColors.mutedInk)
                        }.frame(maxWidth: .infinity)
                        VStack(spacing: 6) {
                            Image(systemName: "hare.fill").font(.system(size: 24))
                                .foregroundStyle(goalSpeed == 1 ? NeoAppColors.cobalt : NeoAppColors.mutedInk.opacity(0.4))
                            Text("RECOMMENDED").font(.system(.caption, design: .rounded, weight: .black).width(.condensed))
                                .foregroundStyle(goalSpeed == 1 ? NeoAppColors.cobalt : NeoAppColors.mutedInk)
                        }.frame(maxWidth: .infinity)
                        VStack(spacing: 6) {
                            Image(systemName: "bolt.fill").font(.system(size: 24))
                                .foregroundStyle(goalSpeed == 2 ? NeoAppColors.cobalt : NeoAppColors.mutedInk.opacity(0.4))
                            Text("FAST").font(.system(.caption, design: .rounded, weight: .black).width(.condensed))
                                .foregroundStyle(goalSpeed == 2 ? NeoAppColors.cobalt : NeoAppColors.mutedInk)
                        }.frame(maxWidth: .infinity)
                    }
                    .padding(12)
                    .neoPanel()
                    .padding(.horizontal, NeoAppMetrics.screenInset)
                    Slider(value: Binding(
                        get: { Double(goalSpeed) },
                        set: { goalSpeed = Int($0.rounded()) }
                    ), in: 0...2, step: 1)
                    .tint(NeoAppColors.cobalt)
                    .padding(.horizontal, 40)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 0) {
                            Text("You'll reach your goal in ")
                                .font(.system(.subheadline, design: .rounded, weight: .bold))
                            Text("\(estimatedDays) days")
                                .font(.system(.subheadline, design: .rounded, weight: .black))
                                .foregroundStyle(NeoAppColors.cobalt)
                        }
                        Text(goalSpeed == 1 ? "The most balanced pace, motivating and sustainable."
                             : goalSpeed == 0 ? "Gentle and sustainable. Great for long-term habits."
                             : "Aggressive but doable. Requires strong discipline.")
                            .font(.system(.caption, design: .rounded, weight: .bold))
                            .foregroundStyle(NeoAppColors.mutedInk)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .neoPanel()
                    .padding(.horizontal, NeoAppMetrics.screenInset)
                }
                Spacer()
            }
            continueButton { profile.save() }
        }
    }

    // MARK: - 9: Notifications

    @AppStorage("notificationsEnabled") private var notificationsEnabled = false

    private var notificationsStep: some View {
        VStack(spacing: 0) {
            stepHeader(title: "Meal reminders", subtitle: "Choose whether Füd AI can keep your logging routine on track")
            Spacer()

            VStack(spacing: 18) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 42, weight: .black))
                    .foregroundStyle(NeoAppColors.onCobalt)
                    .frame(width: 88, height: 88)
                    .background(NeoAppColors.cobalt)
                    .overlay {
                        Rectangle()
                            .stroke(NeoAppColors.ink, lineWidth: NeoAppMetrics.rule)
                    }

                Text("BE REMINDED TO\nLOG MEALS")
                    .font(.system(size: 28, weight: .black, design: .rounded).width(.condensed))
                    .foregroundStyle(NeoAppColors.ink)
                    .multilineTextAlignment(.center)

                Text("Get gentle reminders at meal times\nso you never forget to track.")
                    .font(.system(.callout, design: .rounded, weight: .bold))
                    .foregroundStyle(NeoAppColors.mutedInk)
                    .multilineTextAlignment(.center)

                VStack(spacing: 0) {
                    NeoSectionBanner(title: "NOTIFICATIONS", detail: "OPTIONAL", style: .cobalt)
                    Text("FÜD AI WOULD LIKE TO SEND YOU NOTIFICATIONS")
                        .font(.system(.subheadline, design: .rounded, weight: .black).width(.condensed))
                        .foregroundStyle(NeoAppColors.ink)
                        .multilineTextAlignment(.center)
                        .padding(14)
                        .frame(maxWidth: .infinity)
                        .background(NeoAppColors.surface)
                    Rectangle()
                        .fill(NeoAppColors.ink)
                        .frame(height: NeoAppMetrics.compactRule)
                    HStack(spacing: 0) {
                        Button {
                            notificationsEnabled = false
                            withAnimation(.snappy) { step += 1 }
                        } label: {
                            Text("DON'T ALLOW")
                                .font(.system(.subheadline, design: .rounded, weight: .black).width(.condensed))
                                .foregroundStyle(NeoAppColors.ink)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(NeoAppColors.surface)
                        }
                        .buttonStyle(.plain)
                        Rectangle()
                            .fill(NeoAppColors.ink)
                            .frame(width: NeoAppMetrics.compactRule, height: 48)
                        Button {
                            Task {
                                let granted = await notificationManager.requestAuthorization()
                                notificationsEnabled = granted
                                if granted {
                                    notificationManager.scheduleMealReminders(
                                        breakfastEnabled: true, breakfastHour: 8, breakfastMinute: 0,
                                        lunchEnabled: true, lunchHour: 12, lunchMinute: 0,
                                        dinnerEnabled: true, dinnerHour: 19, dinnerMinute: 0
                                    )
                                }
                                withAnimation(.snappy) { step += 1 }
                            }
                        } label: {
                            Text("ALLOW")
                                .font(.system(.subheadline, design: .rounded, weight: .black).width(.condensed))
                                .foregroundStyle(Color.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(NeoAppColors.acid)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .overlay {
                    Rectangle()
                        .stroke(NeoAppColors.ink, lineWidth: NeoAppMetrics.rule)
                }
                .padding(.horizontal, NeoAppMetrics.screenInset)
            }

            Spacer()

            Button {
                notificationsEnabled = false
                withAnimation(.snappy) { step += 1 }
            } label: {
                Text("SKIP FOR NOW")
                    .font(.system(.body, design: .rounded, weight: .black).width(.condensed))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(NeoOnboardingSecondaryButtonStyle())
            .padding(.horizontal, NeoAppMetrics.screenInset)
            .padding(.bottom, 36)
        }
    }

    // MARK: - 10: Apple Health

    private var appleHealthStep: some View {
        VStack(spacing: 0) {
            stepHeader(title: "Apple Health", subtitle: "Keep body measurements and nutrition in sync")
            Spacer()

            VStack(spacing: 20) {
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 48, weight: .black))
                    .foregroundStyle(NeoAppColors.onCobalt)
                    .frame(width: 104, height: 104)
                    .background(NeoAppColors.cobalt)
                    .overlay {
                        Rectangle()
                            .stroke(NeoAppColors.ink, lineWidth: NeoAppMetrics.rule)
                    }

                VStack(spacing: 8) {
                    Text("CONNECT TO\nAPPLE HEALTH")
                        .font(.system(size: 28, weight: .black, design: .rounded).width(.condensed))
                        .foregroundStyle(NeoAppColors.ink)
                        .multilineTextAlignment(.center)

                    Text("Keep your nutrition and body\nmeasurements in sync automatically.")
                        .font(.system(.callout, design: .rounded, weight: .bold))
                        .foregroundStyle(NeoAppColors.mutedInk)
                        .multilineTextAlignment(.center)
                }

                // Feature list
                VStack(alignment: .leading, spacing: 12) {
                    healthFeatureRow(icon: "fork.knife", label: "Nutrition Data")
                    healthFeatureRow(icon: "scalemass.fill", label: "Weight Sync")
                    healthFeatureRow(icon: "figure.stand", label: "Body Measurements")
                }
                .padding(.horizontal, NeoAppMetrics.screenInset)
            }

            Spacer()

            VStack(spacing: 12) {
                Button {
                    Task {
                        let authorized = await healthKitManager.requestAuthorization()
                        if authorized {
                            UserDefaults.standard.set(true, forKey: "healthKitEnabled")

                            // Write current profile data to Health
                            let p = profile
                            healthKitManager.writeWeight(kg: p.weightKg, date: .now)
                            healthKitManager.writeHeight(cm: p.heightCm)
                            if let bf = p.bodyFatPercentage {
                                healthKitManager.writeBodyFat(fraction: bf)
                            }

                            // Read Health data back into profile
                            let measurements = await healthKitManager.fetchLatestBodyMeasurements()
                            if let dob = measurements.dob {
                                birthday = dob
                            }
                            if let sex = measurements.sex {
                                switch sex {
                                case .male: gender = .male
                                case .female: gender = .female
                                default: break
                                }
                            }
                        }
                        withAnimation(.snappy) { step += 1 }
                    }
                } label: {
                    Label("CONNECT & CONTINUE", systemImage: "heart.fill")
                        .font(.system(.body, design: .rounded, weight: .black).width(.condensed))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(NeoOnboardingPrimaryButtonStyle())
                .accessibilityIdentifier("onboarding.health.continue")
                .padding(.horizontal, NeoAppMetrics.screenInset)
                .padding(.bottom, 20)
            }
        }
    }

    // MARK: - 11: AI Provider Setup

    private var aiProviderStep: some View {
        VStack(spacing: 0) {
            stepHeader(title: "Set up your AI", subtitle: "Connect the provider you trust with your own key")

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 42, weight: .black))
                        .foregroundStyle(Color.black)
                        .frame(width: 96, height: 96)
                        .background(NeoAppColors.acid)
                        .overlay {
                            Rectangle()
                                .stroke(NeoAppColors.ink, lineWidth: NeoAppMetrics.rule)
                        }

                    VStack(spacing: 8) {
                        Text("BRING YOUR OWN AI")
                            .font(.system(size: 28, weight: .black, design: .rounded).width(.condensed))
                            .foregroundStyle(NeoAppColors.ink)
                            .multilineTextAlignment(.center)

                        Text("Add your own AI provider key — Gemini, OpenAI, Groq, and more are supported. The app stays free.")
                            .font(.system(.callout, design: .rounded, weight: .bold))
                            .foregroundStyle(NeoAppColors.mutedInk)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, NeoAppMetrics.screenInset)
                    }

                    byokConfigSection
                        .padding(.horizontal, NeoAppMetrics.screenInset)

                    VStack(spacing: 0) {
                        NeoSectionBanner(title: "DATA & PRIVACY", detail: "READ THIS", style: .cobalt)
                        VStack(alignment: .leading, spacing: 12) {
                            aiNoticeRow(
                                icon: "photo.fill",
                                title: "AI analysis",
                                text: "Food photos, voice transcripts, and typed meals are sent directly to your selected AI provider."
                            )
                            aiNoticeRow(
                                icon: "lock.shield.fill",
                                title: "Local data",
                                text: "Your food log, weight history, body-fat history, and BYOK API keys stay on this device."
                            )
                        }
                        .padding(14)
                        .background(NeoAppColors.surface)
                    }
                    .overlay {
                        Rectangle()
                            .stroke(NeoAppColors.ink, lineWidth: NeoAppMetrics.rule)
                    }
                    .padding(.horizontal, NeoAppMetrics.screenInset)

                    VStack(alignment: .leading, spacing: 14) {
                        Button {
                            hasAcceptedTerms.toggle()
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: hasAcceptedTerms ? "checkmark.square.fill" : "square")
                                    .font(.system(size: 22, weight: .black))
                                    .foregroundStyle(hasAcceptedTerms ? Color.black : NeoAppColors.mutedInk)
                                    .frame(width: 26, height: 26)

                                Text("I accept the Terms of Service and Privacy Policy, including AI provider data sharing described above.")
                                    .font(.system(.footnote, design: .rounded, weight: .bold))
                                    .foregroundStyle(hasAcceptedTerms ? Color.black : NeoAppColors.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(hasAcceptedTerms ? NeoAppColors.acid : NeoAppColors.surface)
                            .overlay {
                                Rectangle()
                                    .stroke(NeoAppColors.ink, lineWidth: NeoAppMetrics.rule)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(hasAcceptedTerms ? .isSelected : [])

                        HStack(spacing: 6) {
                            Link("Privacy Policy", destination: URL(string: "https://fud-ai.app/privacy.html")!)
                            Text("and")
                                .foregroundStyle(NeoAppColors.mutedInk)
                            Link("Terms of Service", destination: URL(string: "https://fud-ai.app/terms.html")!)
                        }
                        .font(.system(.footnote, design: .rounded, weight: .black))
                        .foregroundStyle(NeoAppColors.cobalt)
                        .frame(maxWidth: .infinity)
                    }
                    .padding(14)
                    .neoPanel()
                    .padding(.horizontal, NeoAppMetrics.screenInset)
                }
                .padding(.top, 16)
                .padding(.bottom, 20)
            }

            Button {
                completeAIChoiceAndAdvance()
            } label: {
                Label("ACCEPT & CONTINUE", systemImage: "lock.shield.fill")
                    .font(.system(.body, design: .rounded, weight: .black).width(.condensed))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(NeoOnboardingPrimaryButtonStyle())
            .disabled(!canAdvanceAI)
            .opacity(canAdvanceAI ? 1 : 0.45)
            .accessibilityIdentifier("onboarding.ai.accept")
            .padding(.horizontal, NeoAppMetrics.screenInset)
            .padding(.bottom, 36)
        }
    }

    /// Step 11 can advance when terms are accepted AND a usable AI provider is set up:
    /// a model + key (+ base URL for custom endpoints).
    private var canAdvanceAI: Bool {
        guard hasAcceptedTerms else { return false }
        let modelOK = !byokModel.trimmingCharacters(in: .whitespaces).isEmpty
        let keyOK = !byokProvider.requiresAPIKey || !byokApiKey.trimmingCharacters(in: .whitespaces).isEmpty
        let urlOK = !byokProvider.requiresCustomEndpoint || !byokBaseURL.trimmingCharacters(in: .whitespaces).isEmpty
        return modelOK && keyOK && urlOK
    }

    @ViewBuilder
    private var byokConfigSection: some View {
        VStack(spacing: 0) {
            NeoSectionBanner(title: "AI CONNECTION", detail: "BYOK", style: .acid)

            VStack(alignment: .leading, spacing: 14) {
                // Provider
                HStack {
                    Label { Text("Provider") } icon: {
                        Image(systemName: "cpu").foregroundStyle(NeoAppColors.cobalt)
                    }
                    Spacer()
                    Picker("", selection: $byokProvider) {
                        ForEach(AIProvider.allCases) { provider in
                            Text(provider.rawValue).tag(provider)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .tint(NeoAppColors.cobalt)
                    .onChange(of: byokProvider) { _, newProvider in
                        AIProviderSettings.selectedProvider = newProvider
                        byokModel = newProvider.defaultModel
                        AIProviderSettings.selectedModel = newProvider.defaultModel
                        byokApiKey = AIProviderSettings.apiKey(for: newProvider) ?? ""
                        byokBaseURL = AIProviderSettings.customBaseURL(for: newProvider) ?? ""
                    }
                }

                Divider()
                    .overlay(NeoAppColors.ink)

                // Model
                HStack {
                    Label { Text("Model") } icon: {
                        Image(systemName: "brain").foregroundStyle(NeoAppColors.cobalt)
                    }
                    Spacer()
                    if byokProvider.supportsCustomModelName {
                        TextField("e.g. gpt-4o-mini", text: $byokModel)
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .onChange(of: byokModel) { _, m in AIProviderSettings.selectedModel = m }
                        if !byokProvider.models.isEmpty {
                            Menu {
                                ForEach(byokProvider.models, id: \.self) { model in
                                    Button(model) { byokModel = model; AIProviderSettings.selectedModel = model }
                                }
                            } label: {
                                Image(systemName: "list.bullet.square").foregroundStyle(NeoAppColors.cobalt)
                            }
                        }
                    } else {
                        Picker("", selection: $byokModel) {
                            ForEach(byokProvider.models, id: \.self) { model in Text(model).tag(model) }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .tint(NeoAppColors.cobalt)
                        .onChange(of: byokModel) { _, m in AIProviderSettings.selectedModel = m }
                    }
                }

                // API Key
                if byokProvider.requiresAPIKey {
                    Divider()
                        .overlay(NeoAppColors.ink)
                    HStack {
                        Label { Text("API Key") } icon: {
                            Image(systemName: "key.fill").foregroundStyle(NeoAppColors.cobalt)
                        }
                        Spacer()
                        Group {
                            if showByokKey {
                                TextField(byokProvider.apiKeyPlaceholder, text: $byokApiKey)
                            } else {
                                SecureField(byokProvider.apiKeyPlaceholder, text: $byokApiKey)
                            }
                        }
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onChange(of: byokApiKey) { _, k in
                            let t = k.trimmingCharacters(in: .whitespacesAndNewlines)
                            AIProviderSettings.setAPIKey(t.isEmpty ? nil : t, for: byokProvider)
                        }
                        Button { showByokKey.toggle() } label: {
                            Image(systemName: showByokKey ? "eye.fill" : "eye.slash.fill")
                                .foregroundStyle(NeoAppColors.cobalt).font(.system(size: 14, weight: .bold))
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Base / Server URL
                if byokProvider == .ollama || byokProvider.requiresCustomEndpoint {
                    Divider()
                        .overlay(NeoAppColors.ink)
                    HStack {
                        Label { Text(byokProvider.requiresCustomEndpoint ? "Base URL" : "Server URL") } icon: {
                            Image(systemName: "link").foregroundStyle(NeoAppColors.cobalt)
                        }
                        Spacer()
                        TextField(
                            byokProvider.requiresCustomEndpoint ? "https://your-endpoint.com/v1" : byokProvider.baseURL,
                            text: $byokBaseURL
                        )
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .onChange(of: byokBaseURL) { _, u in
                            let t = u.trimmingCharacters(in: .whitespacesAndNewlines)
                            AIProviderSettings.setCustomBaseURL(t.isEmpty ? nil : t, for: byokProvider)
                        }
                    }
                }
            }
            .font(.system(.subheadline, design: .rounded, weight: .bold))
            .padding(14)
            .background(NeoAppColors.surface)
        }
        .overlay {
            Rectangle()
                .stroke(NeoAppColors.ink, lineWidth: NeoAppMetrics.rule)
        }
    }

    private func completeAIChoiceAndAdvance() {
        aiConsentGiven = true
        acceptedTermsAndPrivacy = true
        withAnimation(.snappy) { step += 1 }
    }

    private func aiNoticeRow(icon: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(NeoAppColors.onCobalt)
                .frame(width: 32, height: 32)
                .background(NeoAppColors.cobalt)
                .overlay {
                    Rectangle()
                        .stroke(NeoAppColors.ink, lineWidth: NeoAppMetrics.compactRule)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(LocalizedDisplayText.text(title))
                    .textCase(.uppercase)
                    .font(.system(.subheadline, design: .rounded, weight: .black).width(.condensed))
                Text(LocalizedDisplayText.text(text))
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(NeoAppColors.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func aiSetupRow(number: String, text: String) -> some View {
        HStack(spacing: 12) {
            Text(number)
                .font(.system(.caption, design: .rounded, weight: .black))
                .foregroundStyle(NeoAppColors.onCobalt)
                .frame(width: 26, height: 26)
                .background(NeoAppColors.cobalt)
                .overlay {
                    Rectangle()
                        .stroke(NeoAppColors.ink, lineWidth: NeoAppMetrics.compactRule)
                }
            Text(text)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(NeoAppColors.ink)
            Spacer(minLength: 0)
        }
    }

    // MARK: - 12: Building Plan

    private var buildingPlanStep: some View {
        BuildingPlanStepView(profile: profile, heightMetric: isHeightMetric, weightMetric: isWeightMetric) { result in
            aiGoal = result
            withAnimation(.snappy) { step += 1 }
        }
    }

    // MARK: - 13: Plan Ready

    private var planCalories: Int { editedCalories ?? profile.dailyCalories }
    private var planProtein: Int { editedProtein ?? profile.proteinGoal }
    private var planFat: Int { editedFat ?? profile.fatGoal }
    private var planCarbs: Int { editedCarbs ?? profile.carbsGoal }

    private func initPlanValues() {
        guard editedCalories == nil && editedProtein == nil && editedFat == nil && editedCarbs == nil else { return }
        if let g = aiGoal {
            // AI-computed plan (carbs derived as the residual to stay consistent with calories).
            editedCalories = g.calories
            editedProtein = g.protein
            editedFat = g.fat
            editedCarbs = max(0, (g.calories - g.protein * 4 - g.fat * 9) / 4)
        } else {
            editedCalories = profile.dailyCalories
            editedProtein = profile.proteinGoal
            editedFat = profile.fatGoal
            editedCarbs = profile.carbsGoal
        }
    }

    private var planReadyStep: some View {
        VStack(spacing: 0) {
            stepHeader(title: "Your Plan", subtitle: "Tap any value to adjust")

            ScrollView {
                VStack(spacing: 20) {
                    // Adaptive Goals is on by default for new installs — say so up front.
                    NeoOutlinedPanel(fill: NeoAppColors.cobalt) {
                        HStack(spacing: 10) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 18, weight: .black))
                                .foregroundStyle(NeoAppColors.acid)
                            Text("Your plan auto-adjusts weekly as you log — turn off Adaptive Goals in Settings to keep it fixed.")
                                .font(.system(.footnote, design: .rounded, weight: .bold))
                                .foregroundStyle(NeoAppColors.onCobalt)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.horizontal, NeoAppMetrics.screenInset)

                    // Calorie display - tappable
                    Button {
                        withAnimation(.snappy) {
                            editingField = editingField == .calories ? nil : .calories
                        }
                    } label: {
                        VStack(spacing: 0) {
                            NeoSectionBanner(
                                title: "DAILY CALORIES",
                                detail: editingField == .calories ? "EDITING" : "TAP TO EDIT",
                                style: editingField == .calories ? .acid : .cobalt
                            )
                            VStack(spacing: 4) {
                                Text("\(planCalories)")
                                    .font(.system(size: 64, weight: .black, design: .rounded).width(.condensed))
                                    .foregroundStyle(editingField == .calories ? Color.black : NeoAppColors.cobalt)
                                    .contentTransition(.numericText())
                                    .animation(.snappy, value: planCalories)
                                HStack(spacing: 6) {
                                    Text("KCAL / DAY")
                                        .font(.system(.callout, design: .rounded, weight: .black).width(.condensed))
                                        .foregroundStyle(editingField == .calories ? Color.black.opacity(0.72) : NeoAppColors.mutedInk)
                                    Image(systemName: editingField == .calories ? "checkmark.square.fill" : "pencil")
                                        .font(.system(size: 14, weight: .black))
                                        .foregroundStyle(editingField == .calories ? Color.black : NeoAppColors.cobalt)
                                }
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity)
                            .background(editingField == .calories ? NeoAppColors.acid : NeoAppColors.surface)
                        }
                        .overlay {
                            Rectangle()
                                .stroke(NeoAppColors.ink, lineWidth: NeoAppMetrics.rule)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, NeoAppMetrics.screenInset)
                    .accessibilityLabel("Daily calorie target")
                    .accessibilityValue("\(planCalories) calories")
                    .accessibilityAddTraits(editingField == .calories ? .isSelected : [])

                    if editingField == .calories {
                        Picker(LocalizedDisplayText.text("Calories"), selection: Binding(
                            get: { planCalories },
                            set: { newCal in
                                editedCalories = newCal
                                editedCarbs = max(0, (newCal - planProtein * 4 - planFat * 9) / 4)
                                markPlanEdited()
                            }
                        )) {
                            ForEach(Array(stride(from: 800, through: 5000, by: 10)), id: \.self) { cal in
                                Text("\(cal) cal").tag(cal)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 150)
                        .padding(10)
                        .neoPanel()
                        .padding(.horizontal, NeoAppMetrics.screenInset)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // Macro cards - tappable
                    HStack(spacing: 12) {
                        editableMacroCard(label: "Protein", value: planProtein, unit: "g", gradientColors: [NeoAppColors.cobalt], field: .protein)
                        editableMacroCard(label: "Carbs", value: planCarbs, unit: "g", gradientColors: [NeoAppColors.cobalt], field: .carbs)
                        editableMacroCard(label: "Fat", value: planFat, unit: "g", gradientColors: [NeoAppColors.cobalt], field: .fat)
                    }
                    .padding(.horizontal, NeoAppMetrics.screenInset)

                    if editingField == .protein {
                        Picker(LocalizedDisplayText.text("Protein"), selection: Binding(
                            get: { planProtein },
                            set: { newProtein in
                                editedProtein = newProtein
                                editedCarbs = max(0, (planCalories - newProtein * 4 - planFat * 9) / 4)
                                markPlanEdited()
                            }
                        )) {
                            ForEach(20...300, id: \.self) { g in Text("\(g) g").tag(g) }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 150)
                        .padding(10)
                        .neoPanel()
                        .padding(.horizontal, NeoAppMetrics.screenInset)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    if editingField == .carbs {
                        Picker(LocalizedDisplayText.text("Carbs"), selection: Binding(
                            get: { planCarbs },
                            set: { newCarbs in
                                editedCarbs = newCarbs
                                editedCalories = newCarbs * 4 + planProtein * 4 + planFat * 9
                                markPlanEdited()
                            }
                        )) {
                            ForEach(0...500, id: \.self) { g in Text("\(g) g").tag(g) }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 150)
                        .padding(10)
                        .neoPanel()
                        .padding(.horizontal, NeoAppMetrics.screenInset)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    if editingField == .fat {
                        Picker(LocalizedDisplayText.text("Fat"), selection: Binding(
                            get: { planFat },
                            set: { newFat in
                                editedFat = newFat
                                editedCarbs = max(0, (planCalories - planProtein * 4 - newFat * 9) / 4)
                                markPlanEdited()
                            }
                        )) {
                            ForEach(10...200, id: \.self) { g in Text("\(g) g").tag(g) }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 150)
                        .padding(10)
                        .neoPanel()
                        .padding(.horizontal, NeoAppMetrics.screenInset)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    if planCalories < 1200 {
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Color.black)
                                .frame(width: 36, height: 36)
                                .background(NeoAppColors.warning)
                                .overlay {
                                    Rectangle()
                                        .stroke(NeoAppColors.ink, lineWidth: NeoAppMetrics.compactRule)
                                }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("PLEASE CONSULT WITH A DOCTOR")
                                    .font(.system(.subheadline, design: .rounded, weight: .black).width(.condensed))
                                Text("The minimum recommendation is 1,200 calories per day.")
                                    .font(.system(.caption, design: .rounded, weight: .bold))
                                    .foregroundStyle(NeoAppColors.mutedInk)
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .neoPanel(fill: NeoAppColors.warning.opacity(0.12))
                        .padding(.horizontal, NeoAppMetrics.screenInset)
                    }
                    // Citations link (Apple Guideline 1.4.1 — medical info needs sources)
                    Button {
                        showCalculationSources = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "book.fill")
                                .font(.system(size: 11))
                            Text("HOW IS THIS CALCULATED?")
                                .font(.system(.footnote, design: .rounded, weight: .black).width(.condensed))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(NeoOnboardingSecondaryButtonStyle())
                    .padding(.top, 8)
                    .padding(.horizontal, NeoAppMetrics.screenInset)
                }
                .padding(.top, 16)
                .padding(.bottom, 100)
            }

            // Final step — save the plan and enter the app directly (the old
            // post-plan rating screen was removed; onboarding rating pressure
            // is App Review rejection bait).
            Button {
                var editedProfile = profile
                editedProfile.customCalories = editedCalories
                editedProfile.customProtein = editedProtein
                editedProfile.customFat = editedFat
                editedProfile.customCarbs = editedCarbs
                editedProfile.autoBalanceMacro = .carbs
                editedProfile.save()
                hasCompletedOnboarding = true
            } label: {
                Label("LET'S GET STARTED", systemImage: "bolt.fill")
                    .font(.system(.body, design: .rounded, weight: .black).width(.condensed))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(NeoOnboardingPrimaryButtonStyle())
            .accessibilityIdentifier("onboarding.complete")
            .padding(.horizontal, NeoAppMetrics.screenInset)
            .padding(.bottom, 36)
        }
        .onAppear { initPlanValues() }
        .sheet(isPresented: $showCalculationSources) {
            CalculationMethodsView()
        }
    }

    private func editableMacroCard(label: String, value: Int, unit: String, gradientColors: [Color], field: EditableField) -> some View {
        let accent = gradientColors.first ?? NeoAppColors.cobalt

        return Button {
            withAnimation(.snappy) {
                editingField = editingField == field ? nil : field
            }
        } label: {
            VStack(spacing: 6) {
                Text(LocalizedDisplayText.text(label))
                    .textCase(.uppercase)
                    .font(.system(.caption, design: .rounded, weight: .black).width(.condensed))
                    .foregroundStyle(editingField == field ? Color.black : NeoAppColors.mutedInk)
                HStack(spacing: 2) {
                    Text("\(value)")
                        .font(.system(.title2, design: .rounded, weight: .black).width(.condensed))
                        .foregroundStyle(editingField == field ? Color.black : accent)
                        .contentTransition(.numericText())
                        .animation(.snappy, value: value)
                    Text(unit)
                        .font(.system(.caption, design: .rounded, weight: .black))
                        .foregroundStyle(editingField == field ? Color.black.opacity(0.72) : NeoAppColors.mutedInk)
                }
                Image(systemName: editingField == field ? "checkmark.square.fill" : "pencil")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(editingField == field ? Color.black : NeoAppColors.cobalt)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(editingField == field ? NeoAppColors.acid : NeoAppColors.surface)
            .overlay(
                Rectangle()
                    .stroke(NeoAppColors.ink, lineWidth: NeoAppMetrics.rule)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(LocalizedDisplayText.text(label))
        .accessibilityValue("\(value) \(unit)")
        .accessibilityAddTraits(editingField == field ? .isSelected : [])
    }

    private func stepHeader(title: String, subtitle: String) -> some View {
        VStack(spacing: 0) {
            NeoSectionBanner(
                title: "PROFILE SETUP",
                detail: "STEP \(step) OF \(totalSteps - 1)",
                style: .cobalt
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .textCase(.uppercase)
                    .font(.system(size: 29, weight: .black, design: .rounded).width(.condensed))
                    .foregroundStyle(NeoAppColors.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(.callout, design: .rounded, weight: .bold))
                        .foregroundStyle(NeoAppColors.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(NeoAppColors.surface)
            .overlay {
                Rectangle()
                    .stroke(NeoAppColors.ink, lineWidth: NeoAppMetrics.rule)
            }
        }
        .padding(.horizontal, NeoAppMetrics.screenInset)
        .padding(.top, 12)
    }

    private func selectionCard(icon: String, title: String, subtitle: String? = nil, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(isSelected ? Color.black : NeoAppColors.onCobalt)
                    .frame(width: 42, height: 42)
                    .background(isSelected ? NeoAppColors.acid : NeoAppColors.cobalt)
                    .overlay {
                        Rectangle()
                            .stroke(NeoAppColors.ink, lineWidth: NeoAppMetrics.compactRule)
                    }
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .textCase(.uppercase)
                        .font(.system(.body, design: .rounded, weight: .black).width(.condensed))
                        .foregroundStyle(isSelected ? NeoAppColors.onCobalt : NeoAppColors.ink)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(.caption, design: .rounded, weight: .bold))
                            .foregroundStyle(isSelected ? NeoAppColors.onCobalt.opacity(0.82) : NeoAppColors.mutedInk)
                    }
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(isSelected ? NeoAppColors.acid : NeoAppColors.mutedInk)
            }
            .padding(12)
            .background(isSelected ? NeoAppColors.cobalt : NeoAppColors.surface)
            .overlay {
                Rectangle()
                    .stroke(NeoAppColors.ink, lineWidth: isSelected ? 3 : NeoAppMetrics.rule)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func healthFeatureRow(icon: String, label: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(NeoAppColors.onCobalt)
                .frame(width: 38, height: 38)
                .background(NeoAppColors.cobalt)
                .overlay {
                    Rectangle()
                        .stroke(NeoAppColors.ink, lineWidth: NeoAppMetrics.compactRule)
                }
            Text(LocalizedDisplayText.text(label))
                .textCase(.uppercase)
                .font(.system(.body, design: .rounded, weight: .black).width(.condensed))
                .foregroundStyle(NeoAppColors.ink)
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(NeoAppColors.surface)
        .overlay {
            Rectangle()
                .stroke(NeoAppColors.ink, lineWidth: NeoAppMetrics.rule)
        }
    }

    /// The user hand-tuned their plan — remembered so Adaptive Goals is NOT enabled
    /// by default at completion (its weekly run would overwrite these numbers).
    private func markPlanEdited() {
        UserDefaults.standard.set(true, forKey: "onboardingPlanEdited")
    }

    private func welcomeFeatureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(NeoAppColors.onCobalt)
                .frame(width: 34, height: 34)
                .background(NeoAppColors.cobalt)
                .overlay {
                    Rectangle()
                        .stroke(NeoAppColors.ink, lineWidth: NeoAppMetrics.compactRule)
                }
            Text(LocalizedDisplayText.text(text))
                .font(.system(.subheadline, design: .rounded, weight: .black))
                .foregroundStyle(NeoAppColors.ink)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 50)
        .background(NeoAppColors.surface)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(NeoAppColors.ink)
                .frame(height: NeoAppMetrics.compactRule)
        }
    }
}

// MARK: - Building Plan Step (enhanced with percentage + checklist)

struct BuildingPlanStepView: View {
    let profile: UserProfile
    let heightMetric: Bool
    let weightMetric: Bool
    let onComplete: (GeminiService.GoalCalculation?) -> Void

    @State private var progress: Double = 0
    @State private var percent = 0
    @State private var checkItem = 0
    @State private var aiResult: GeminiService.GoalCalculation?
    @State private var aiDone = false
    @State private var animationDone = false

    private let items = [
        ("Calories", "flame.fill"),
        ("Carbs", "leaf.fill"),
        ("Protein", "fish.fill"),
        ("Fats", "drop.fill"),
        ("Health Score", "heart.fill")
    ]

    var body: some View {
        VStack(spacing: 22) {
            NeoSectionBanner(title: "BUILDING YOUR PLAN", detail: "AI + FORMULAS", style: .cobalt)
                .padding(.horizontal, NeoAppMetrics.screenInset)
                .padding(.top, 12)

            Spacer()

            NeoOutlinedPanel(fill: NeoAppColors.surface, padding: 18) {
                VStack(spacing: 8) {
                    Text("\(percent)%")
                        .font(.system(size: 60, weight: .black, design: .rounded).width(.condensed))
                        .foregroundStyle(NeoAppColors.cobalt)
                        .contentTransition(.numericText())
                        .animation(.easeInOut(duration: 0.3), value: percent)

                    Text("WE'RE SETTING EVERYTHING\nUP FOR YOU")
                        .font(.system(size: 22, weight: .black, design: .rounded).width(.condensed))
                        .foregroundStyle(NeoAppColors.ink)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, NeoAppMetrics.screenInset)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(NeoAppColors.subtleSurface)
                    Rectangle()
                        .fill(NeoAppColors.acid)
                        .frame(width: geo.size.width * progress)
                        .animation(.easeInOut(duration: 0.4), value: progress)
                }
                .overlay {
                    Rectangle()
                        .stroke(NeoAppColors.ink, lineWidth: NeoAppMetrics.rule)
                }
            }
            .frame(height: 16)
            .padding(.horizontal, NeoAppMetrics.screenInset)

            Text("FINALIZING RESULTS…")
                .font(.system(.subheadline, design: .rounded, weight: .black).width(.condensed))
                .foregroundStyle(NeoAppColors.mutedInk)

            // Checklist
            VStack(spacing: 0) {
                NeoSectionBanner(title: "DAILY TARGETS", detail: "5 CHECKS", style: .acid)
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(0..<items.count, id: \.self) { index in
                        HStack(spacing: 10) {
                            Image(systemName: items[index].1)
                                .font(.system(size: 14, weight: .black))
                                .foregroundStyle(NeoAppColors.onCobalt)
                                .frame(width: 30, height: 30)
                                .background(NeoAppColors.cobalt)
                                .overlay {
                                    Rectangle()
                                        .stroke(NeoAppColors.ink, lineWidth: NeoAppMetrics.compactRule)
                                }
                            Text(items[index].0.uppercased())
                                .font(.system(.body, design: .rounded, weight: .black).width(.condensed))
                            Spacer()
                            if index < checkItem {
                                Image(systemName: "checkmark.square.fill")
                                    .font(.system(size: 20, weight: .black))
                                    .foregroundStyle(NeoAppColors.cobalt)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .padding(.horizontal, 12)
                        .frame(minHeight: 48)
                        .background(NeoAppColors.surface)
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(NeoAppColors.ink.opacity(0.38))
                                .frame(height: NeoAppMetrics.compactRule)
                        }
                        .animation(.spring(response: 0.4), value: checkItem)
                    }
                }
            }
            .overlay {
                Rectangle()
                    .stroke(NeoAppColors.ink, lineWidth: NeoAppMetrics.rule)
            }
            .padding(.horizontal, NeoAppMetrics.screenInset)

            Spacer()
        }
        .neoScreen()
        .accessibilityIdentifier("onboarding.buildingPlan")
        .onAppear {
            startAnimation()
            startAICalc()
        }
    }

    private func startAnimation() {
        // 5 items over ~4 seconds
        for i in 0..<5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.7) {
                withAnimation { checkItem = i + 1 }
                percent = [20, 40, 60, 80, 100][i]
                progress = Double(i + 1) / 5.0
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            animationDone = true
            finishIfReady()
        }
    }

    private func startAICalc() {
        Task {
            // New user → no logs yet, so forecast is nil; AI computes from profile + formulas.
            let result = try? await GeminiService.calculateGoals(profile: profile, forecast: nil, heightMetric: heightMetric, weightMetric: weightMetric)
            await MainActor.run {
                aiResult = result
                aiDone = true
                finishIfReady()
            }
        }
    }

    /// Advance only once BOTH the animation and the AI call have finished, so the plan reflects
    /// the AI targets (or the formula fallback when the call returns nil).
    private func finishIfReady() {
        guard animationDone, aiDone else { return }
        onComplete(aiResult)
    }
}

// MARK: - Onboarding Neo-Brutalist controls

private struct NeoOnboardingPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.black)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background {
                ZStack {
                    Rectangle()
                        .fill(Color.black)
                        .offset(
                            x: configuration.isPressed ? 0 : 3,
                            y: configuration.isPressed ? 0 : 3
                        )
                    Rectangle()
                        .fill(NeoAppColors.acid)
                }
            }
            .overlay {
                Rectangle()
                    .stroke(Color.black, lineWidth: NeoAppMetrics.rule)
            }
            .offset(
                x: configuration.isPressed ? 3 : 0,
                y: configuration.isPressed ? 3 : 0
            )
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

private struct NeoOnboardingSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(NeoAppColors.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(NeoAppColors.surface)
            .overlay {
                Rectangle()
                    .stroke(NeoAppColors.ink, lineWidth: NeoAppMetrics.rule)
            }
            .opacity(configuration.isPressed ? 0.65 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
