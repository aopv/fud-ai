import SwiftUI
import UIKit

// MARK: - Shared Kitchen Table primitives

private extension View {
    func neoHomeOutline(_ color: Color = NeoHomeColors.ink, width: CGFloat = NeoHomeMetrics.rule) -> some View {
        let shape = RoundedRectangle(cornerRadius: NeoHomeMetrics.cornerRadius, style: .continuous)
        return clipShape(shape)
            .overlay {
            shape
                .strokeBorder(color.opacity(0.32), lineWidth: width)
                .allowsHitTesting(false)
        }
    }

    func neoHomeTitleStyle(size: CGFloat) -> some View {
        font(.system(size: size, weight: .semibold, design: .serif))
    }

    func kitchenPaperObject(
        cornerRadius: CGFloat = 8,
        rotation: Double = 0,
        shadowRadius: CGFloat = 5,
        shadowY: CGFloat = 3
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return background(KitchenTablePalette.paperRaised, in: shape)
            .clipShape(shape)
            .overlay {
                Image(decorative: "KitchenPaper")
                    .resizable()
                    .scaledToFill()
                    .blendMode(.multiply)
                    .opacity(0.045)
                    .clipShape(shape)
                    .allowsHitTesting(false)
            }
            .overlay {
                shape.strokeBorder(KitchenTablePalette.rule, lineWidth: NeoHomeMetrics.compactRule)
            }
            .shadow(color: KitchenTablePalette.espresso.opacity(0.13), radius: shadowRadius, x: 0, y: shadowY)
            .rotationEffect(.degrees(rotation))
    }
}

struct NeoHomeDateHeader: View {
    @Binding var selectedDate: Date
    @State private var showDatePicker = false
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize = 34

    private var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    private var title: String {
        if isToday { return String(localized: "Today") }
        return selectedDate.formatted(.dateTime.weekday(.wide))
    }

    private var subtitle: String {
        selectedDate.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .neoHomeTitleStyle(size: titleSize)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                Text(subtitle)
                    .font(.system(.subheadline, design: .serif, weight: .regular))
                    .lineLimit(1)
            }
            .foregroundStyle(NeoHomeColors.ink)

            Spacer(minLength: 8)
            calendarButton
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 5)
        .overlay(alignment: .bottomLeading) {
            Rectangle()
                .fill(KitchenTablePalette.herb.opacity(0.78))
                .frame(width: 54, height: 2)
                .offset(x: 3, y: 2)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var calendarButton: some View {
        Button {
            showDatePicker = true
        } label: {
            Image(systemName: "calendar")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(NeoHomeColors.ink)
                .frame(width: 42, height: 42)
                .background(KitchenTablePalette.paperRaised, in: Circle())
                .overlay {
                    Circle().stroke(KitchenTablePalette.strongRule, lineWidth: NeoHomeMetrics.compactRule)
                }
                .shadow(color: KitchenTablePalette.shadow, radius: 3, x: 0, y: 2)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(KitchenTablePressableButtonStyle())
        .accessibilityLabel("Choose date")
        .datePickerPopover(isPresented: $showDatePicker, selection: $selectedDate)
    }
}

private extension View {
    func datePickerPopover(isPresented: Binding<Bool>, selection: Binding<Date>) -> some View {
        popover(isPresented: isPresented, arrowEdge: .top) {
            NeoGlassChoicePanel(
                title: "Choose Date",
                eyebrow: "Food Log",
                onClose: { isPresented.wrappedValue = false }
            ) {
                DatePicker(
                    "Date",
                    selection: selection,
                    in: ...Date.now,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .labelsHidden()
                .tint(NeoAppColors.cobalt)
                .padding(8)
                .kitchenTableSurface(
                    fill: NeoAppColors.surface.opacity(0.94),
                    border: KitchenTablePalette.rule,
                    cornerRadius: 18,
                    lineWidth: NeoAppMetrics.compactRule,
                    shadowRadius: 2,
                    shadowY: 1
                )
            }
            .presentationCompactAdaptation(.popover)
            .presentationBackground(.clear)
        }
    }
}

// MARK: - Calorie hero

struct NeoCalorieSummary: View {
    let eaten: Int
    let goal: Int
    var launchFillEpoch: Int = 0

    @State private var shownProgress = 0.0
    @State private var lastEpoch = -1
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var calorieSize = 34

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(max(Double(eaten) / Double(goal), 0), 1)
    }

    private var delta: Int {
        goal > 0 ? abs(goal - eaten) : 0
    }

    private var deltaLabel: String {
        guard goal > 0 else { return String(localized: "No goal").uppercased() }
        if eaten < goal { return String(localized: "Left").uppercased() }
        if eaten > goal { return String(localized: "Over").uppercased() }
        return String(localized: "Goal reached").uppercased()
    }

    var body: some View {
        calorieReceipt
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
        .onAppear {
            if lastEpoch != launchFillEpoch {
                playLaunchFill()
            } else {
                shownProgress = progress
            }
        }
        .onChange(of: launchFillEpoch) { _, _ in playLaunchFill() }
        .onChange(of: progress) { _, newValue in
            if reduceMotion {
                shownProgress = newValue
            } else {
                withAnimation(.snappy(duration: 0.35)) { shownProgress = newValue }
            }
        }
    }

    private var accessibilitySummary: String {
        guard goal > 0 else {
            return "\(String(localized: "Calories")) \(eaten), \(String(localized: "No goal"))"
        }
        return "\(String(localized: "Calories")) \(eaten), \(String(localized: "Target")) \(goal), \(delta) \(deltaLabel.lowercased())"
    }

    private var calorieReceipt: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    calorieSeal
                    receiptDetails
                }
            } else {
                HStack(spacing: 14) {
                    calorieSeal
                    receiptDetails
                }
            }
        }
        .foregroundStyle(NeoHomeColors.ink)
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 108, alignment: .leading)
        .kitchenPaperObject(cornerRadius: 11, rotation: -0.2, shadowRadius: 6, shadowY: 3)
        .overlay(alignment: .topTrailing) {
            Text("Today's Calories")
                .textCase(.uppercase)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .tracking(1)
                .foregroundStyle(KitchenTablePalette.tomatoDeep)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(KitchenTablePalette.tomato.opacity(0.10), in: Capsule())
                .padding(9)
                .accessibilityHidden(true)
        }
    }

    private var calorieSeal: some View {
        ZStack {
            Circle()
                .fill(KitchenTablePalette.paper)
                .shadow(color: KitchenTablePalette.espresso.opacity(0.12), radius: 3, x: 0, y: 2)
            Circle()
                .stroke(KitchenTablePalette.rule, lineWidth: 1)
            Circle()
                .trim(from: 0, to: shownProgress)
                .stroke(KitchenTablePalette.tomato, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(3)

            VStack(spacing: -2) {
                Text(eaten.formatted())
                    .font(.system(size: calorieSize, weight: .semibold, design: .serif))
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .contentTransition(.numericText())
                Text(verbatim: "kcal")
                    .font(.system(.caption2, design: .monospaced, weight: .bold))
                    .textCase(.uppercase)
            }
        }
        .frame(width: 86, height: 86)
    }

    private var receiptDetails: some View {
        VStack(alignment: .leading, spacing: 6) {
            Spacer(minLength: 6)
            HStack(alignment: .lastTextBaseline, spacing: 5) {
                Text(delta.formatted())
                    .font(.system(.title2, design: .serif, weight: .semibold))
                    .contentTransition(.numericText())
                Text(deltaLabel.lowercased())
                    .font(.system(.caption, design: .serif, weight: .regular))
                    .foregroundStyle(NeoHomeColors.mutedInk)
            }

            NeoSegmentedProgress(progress: shownProgress)

            HStack(spacing: 6) {
                Text("Goal")
                Text(verbatim: "\(goal.formatted()) kcal")
                Spacer(minLength: 4)
                Image(systemName: "scope")
                Text(verbatim: "\(Int((shownProgress * 100).rounded()))%")
            }
            .font(.system(.caption2, design: .monospaced, weight: .medium))
            .foregroundStyle(NeoHomeColors.mutedInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func playLaunchFill() {
        lastEpoch = launchFillEpoch
        if reduceMotion {
            shownProgress = progress
            return
        }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { shownProgress = 0 }
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.85, dampingFraction: 0.82)) {
                shownProgress = progress
            }
        }
    }
}

private struct NeoSegmentedProgress: View {
    let progress: Double
    private let segmentCount = 18

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<segmentCount, id: \.self) { index in
                Capsule()
                    .fill(index < Int(ceil(progress * Double(segmentCount))) ? KitchenTablePalette.tomato : NeoHomeColors.ink.opacity(0.11))
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 7)
        .accessibilityHidden(true)
    }
}

// MARK: - Nutrients and optional modules

struct NeoNutrientStat: Identifiable {
    let id: String
    let label: String
    let iconName: String
    let current: Double
    let goal: Double
    let unit: String
}

struct NeoNutrientGrid: View {
    let stats: [NeoNutrientStat]
    var launchFillEpoch: Int = 0
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var columns: [GridItem] {
        let count = dynamicTypeSize.isAccessibilitySize ? 2 : 4
        return Array(repeating: GridItem(.flexible(minimum: 54), spacing: 7), count: count)
    }

    var body: some View {
        LazyVGrid(columns: columns, alignment: .center, spacing: 7) {
            ForEach(stats) { stat in
                NeoNutrientTile(stat: stat, launchFillEpoch: launchFillEpoch)
            }
        }
        .accessibilityIdentifier("neo.home.nutrientGrid")
    }
}

private struct NeoNutrientTile: View {
    let stat: NeoNutrientStat
    let launchFillEpoch: Int
    @ScaledMetric(relativeTo: .title2) private var valueSize = 20
    @State private var shownProgress = 0.0
    @State private var lastEpoch = -1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var accent: Color {
        let key = "\(stat.id) \(stat.label)".lowercased()
        if key.contains("protein") { return KitchenTablePalette.herb }
        if key.contains("carb") { return KitchenTablePalette.brass }
        if key.contains("fat") { return KitchenTablePalette.cobalt }
        return KitchenTablePalette.tomato
    }

    private var difference: Double {
        abs(stat.goal - stat.current)
    }

    private var progress: Double {
        guard stat.goal > 0 else { return 0 }
        return min(max(stat.current / stat.goal, 0), 1)
    }

    private var statusText: String {
        guard stat.goal > 0 else { return String(localized: "No goal").uppercased() }
        if abs(stat.current - stat.goal) < 0.0001 {
            return String(localized: "Goal reached").uppercased()
        }
        let direction = stat.current > stat.goal
            ? String(localized: "Over").uppercased()
            : String(localized: "Left").uppercased()
        return "\(direction) \(MacroValueFormatter.string(difference))\(stat.unit)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 4) {
                Image(systemName: stat.iconName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(accent)
                Text(stat.label)
                    .textCase(.uppercase)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)
                Spacer(minLength: 0)
            }

            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(MacroValueFormatter.string(stat.current))
                    .font(.system(size: valueSize, weight: .semibold, design: .serif))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(stat.unit)
                    .font(.system(.caption2, design: .monospaced, weight: .medium))
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(NeoHomeColors.ink.opacity(0.12))
                    Capsule()
                        .fill(accent)
                        .frame(width: proxy.size.width * shownProgress)
                }
            }
            .frame(height: 5)
            .accessibilityHidden(true)

            Text(statusText)
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .foregroundStyle(NeoHomeColors.mutedInk)
        }
        .foregroundStyle(NeoHomeColors.ink)
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 91, alignment: .topLeading)
        .background(KitchenTablePalette.paperRaised, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(accent.opacity(0.78), lineWidth: 1)
        }
        .shadow(color: KitchenTablePalette.espresso.opacity(0.10), radius: 3, x: 0, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(stat.label), \(MacroValueFormatter.string(stat.current)) \(stat.unit), \(statusText)")
        .onAppear {
            if lastEpoch != launchFillEpoch {
                playLaunchFill()
            } else {
                shownProgress = progress
            }
        }
        .onChange(of: launchFillEpoch) { _, _ in playLaunchFill() }
        .onChange(of: progress) { _, newValue in
            if reduceMotion {
                shownProgress = newValue
            } else {
                withAnimation(.snappy(duration: 0.35)) { shownProgress = newValue }
            }
        }
    }

    private func playLaunchFill() {
        lastEpoch = launchFillEpoch
        if reduceMotion {
            shownProgress = progress
            return
        }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { shownProgress = 0 }
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.85, dampingFraction: 0.82)) {
                shownProgress = progress
            }
        }
    }
}

struct NeoWaterProgressPanel: View {
    let current: Int
    let goal: Int
    let unit: WaterUnit

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(max(Double(current) / Double(goal), 0), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Label {
                    Text("Water").textCase(.uppercase)
                } icon: {
                    Image(systemName: "drop.fill")
                }
                    .font(.system(.headline, design: .default, weight: .black))
                    .fontWidth(.condensed)
                Spacer()
                Text("\(unit.displayValue(forMilliliters: current)) / \(unit.formatted(milliliters: goal))")
                    .font(.system(.caption, design: .default, weight: .black))
                    .fontWidth(.condensed)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(NeoHomeColors.ink.opacity(0.12))
                    Capsule()
                        .fill(NeoHomeColors.cobalt)
                        .frame(width: proxy.size.width * progress)
                }
            }
            .frame(height: 10)
        }
        .foregroundStyle(NeoHomeColors.ink)
        .padding(12)
        .kitchenTableSurface(
            fill: NeoHomeColors.surface,
            border: KitchenTablePalette.rule,
            cornerRadius: NeoHomeMetrics.cornerRadius,
            shadowRadius: 5,
            shadowY: 2
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Water, \(unit.displayValue(forMilliliters: current)) of \(unit.displayValue(forMilliliters: goal)) \(unit.accessibilityName)")
    }
}

struct NeoHomeDetailsButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text("View More")
                    .font(.system(.footnote, design: .serif, weight: .semibold))
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(.footnote, weight: .semibold))
            }
            .foregroundStyle(NeoHomeColors.ink)
            .padding(.horizontal, 11)
            .frame(minHeight: 40)
            .kitchenPaperObject(cornerRadius: 7, rotation: 0.15, shadowRadius: 3, shadowY: 2)
        }
        .buttonStyle(KitchenTablePressableButtonStyle())
        .accessibilityIdentifier("neo.home.viewNutrition")
    }
}

struct NeoFramedModule<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(LocalizedStringKey(title))
                    .textCase(.uppercase)
                    .font(.system(.title3, design: .default, weight: .black))
                    .fontWidth(.condensed)
                Spacer()
            }
            .foregroundStyle(.black)
            .padding(.horizontal, 12)
            .frame(minHeight: 48)
            .background(NeoHomeColors.acidYellow)

            content
                .foregroundStyle(NeoHomeColors.ink)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(NeoHomeColors.surface)
                .overlay(alignment: .top) {
                    Rectangle().fill(NeoHomeColors.ink).frame(height: NeoHomeMetrics.compactRule)
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: NeoHomeMetrics.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: NeoHomeMetrics.cornerRadius, style: .continuous)
                .stroke(KitchenTablePalette.rule, lineWidth: NeoHomeMetrics.rule)
        }
        .shadow(color: KitchenTablePalette.shadow, radius: 6, x: 0, y: 3)
    }
}

struct NeoHomeSectionBanner: View {
    let title: String
    let iconName: String

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: iconName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(KitchenTablePalette.onStrongAccent)
                .frame(width: 29, height: 29)
                .background(NeoHomeColors.tomato, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            Text(LocalizedStringKey(title))
                .textCase(.uppercase)
                .font(.system(.subheadline, design: .monospaced, weight: .bold))
                .tracking(0.45)
            Spacer()
        }
        .foregroundStyle(NeoHomeColors.ink)
        .padding(.horizontal, 10)
        .frame(minHeight: 43)
        .kitchenPaperObject(cornerRadius: 7, rotation: -0.25, shadowRadius: 4, shadowY: 2)
    }
}

struct NeoActiveFastingRow: View {
    let session: FastingSession

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let elapsed = session.duration(at: context.date)
            let progress = min(1, elapsed / TimeInterval(session.goalMinutes * 60))

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "timer")
                        .font(.system(.title2, weight: .black))
                        .foregroundStyle(NeoHomeColors.cobalt)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Fast in progress")
                            .font(.system(.headline, design: .default, weight: .black))
                            .fontWidth(.condensed)
                        Text("Started \(session.startedAt.formatted(date: .omitted, time: .shortened))")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(NeoHomeColors.mutedInk)
                    }
                    Spacer(minLength: 4)
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(FastingDurationFormatter.compact(seconds: elapsed))
                            .font(.system(.headline, design: .monospaced, weight: .black))
                            .foregroundStyle(NeoHomeColors.cobalt)
                        Text("\(FastingDurationFormatter.goal(minutes: session.goalMinutes)) goal")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(NeoHomeColors.mutedInk)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.black))
                }

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(NeoHomeColors.ink.opacity(0.12))
                        Capsule()
                            .fill(NeoHomeColors.cobalt)
                            .frame(width: proxy.size.width * progress)
                    }
                }
                .frame(height: 8)
            }
            .accessibilityElement(children: .combine)
        }
    }
}

struct NeoCompletedFastingRow: View {
    let session: FastingSession

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "timer.circle.fill")
                .font(.system(.title2, weight: .black))
                .foregroundStyle(NeoHomeColors.cobalt)
            VStack(alignment: .leading, spacing: 3) {
                Text("\(FastingDurationFormatter.compact(seconds: session.duration())) fast")
                    .font(.system(.headline, design: .default, weight: .black))
                    .fontWidth(.condensed)
                if let endedAt = session.endedAt {
                    Text("\(session.startedAt.formatted(date: .omitted, time: .shortened)) – \(endedAt.formatted(date: .omitted, time: .shortened))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(NeoHomeColors.mutedInk)
                }
            }
            Spacer(minLength: 4)
            Text("\(FastingDurationFormatter.goal(minutes: session.goalMinutes)) goal")
                .font(.caption.weight(.bold))
                .foregroundStyle(NeoHomeColors.mutedInk)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.black))
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Meal receipt

struct NeoMealHeader: View {
    let title: String
    let iconName: String
    let totalCalories: Int
    let totalProtein: Double
    let totalCarbs: Double
    let totalFat: Double
    let showsSort: Bool
    @Binding var sortOrderRaw: String
    let onShare: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    titleLabel
                    HStack(spacing: 10) {
                        sortControl
                        shareControl
                        Spacer(minLength: 4)
                        totals
                    }
                }
            } else {
                HStack(spacing: 10) {
                    titleLabel
                    sortControl
                    Spacer(minLength: 4)
                    shareControl
                    totals
                }
            }
        }
        .foregroundStyle(NeoHomeColors.ink)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .kitchenPaperObject(cornerRadius: 7, rotation: -0.35, shadowRadius: 5, shadowY: 2)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(KitchenTablePalette.brassDeep.opacity(0.38))
                .frame(height: NeoHomeMetrics.compactRule)
                .padding(.horizontal, 10)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .contain)
    }

    private var titleLabel: some View {
        HStack(spacing: 7) {
            Image(systemName: iconName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(KitchenTablePalette.tomatoDeep)
                .frame(width: 26, height: 26)
                .background(KitchenTablePalette.tomato.opacity(0.09), in: Circle())
                .overlay { Circle().stroke(KitchenTablePalette.tomato.opacity(0.50), lineWidth: 1) }
            Text(title)
                .font(.system(.title3, design: .serif, weight: .semibold))
                .italic()
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                .minimumScaleFactor(0.65)
        }
    }

    @ViewBuilder
    private var sortControl: some View {
        if showsSort {
            NeoGlassChoiceMenu(
                title: "Sort Food",
                items: FoodLogSortOrder.allCases.map { order in
                    NeoGlassChoiceItem(
                        id: "foodSort.\(order.rawValue)",
                        title: order.displayName,
                        systemImage: "arrow.up.arrow.down",
                        isSelected: order.rawValue == sortOrderRaw,
                        action: { sortOrderRaw = order.rawValue }
                    )
                }
            ) {
                Label("Sort", systemImage: "arrow.up.arrow.down")
                    .labelStyle(.iconOnly)
                    .font(.system(.caption, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .background(KitchenTablePalette.paperMuted.opacity(0.42), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(KitchenTablePalette.rule, lineWidth: NeoHomeMetrics.compactRule)
                    }
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Sort food log")
        }
    }

    private var shareControl: some View {
        Button(action: onShare) {
            Image(systemName: "square.and.arrow.up")
                .font(.system(.caption, weight: .semibold))
                .frame(width: 36, height: 36)
                .background(KitchenTablePalette.paperMuted.opacity(0.42), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(KitchenTablePalette.rule, lineWidth: NeoHomeMetrics.compactRule)
                }
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Share \(title)")
    }

    private var totals: some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(verbatim: "\(totalCalories.formatted()) kcal")
                .font(.system(.caption, design: .monospaced, weight: .bold))
            Text(verbatim: "\(Int(totalProtein.rounded()))P · \(Int(totalCarbs.rounded()))C · \(Int(totalFat.rounded()))F")
                .font(.system(size: 8, weight: .medium, design: .monospaced))
        }
        .lineLimit(1)
        .minimumScaleFactor(0.65)
        .foregroundStyle(NeoHomeColors.mutedInk)
    }
}

struct NeoFoodRow: View {
    let entry: FoodEntry
    let position: Int
    @Environment(FoodStore.self) private var foodStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var servingText: String? {
        guard let grams = entry.servingSizeGrams else { return nil }
        let formatted = grams == grams.rounded() ? "\(Int(grams))" : String(format: "%.1f", grams)
        if let selectedUnit = entry.selectedServingUnit,
           let quantity = entry.selectedServingQuantity,
           quantity > 0 {
            let option = ServingUnitOption.option(matching: selectedUnit, in: entry.servingUnitOptions)
            if !option.isGramUnit {
                let quantityText = ServingUnitEditor.formatQuantity(quantity)
                return "\(quantityText) \(option.displayUnit(for: quantity)) (~\(formatted)g)"
            }
        }
        return "\(formatted)g"
    }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        thumbnail
                        Spacer(minLength: 4)
                        calorieBadge
                    }
                    foodInfo
                }
            } else {
                HStack(alignment: .center, spacing: 10) {
                    thumbnail
                    foodInfo
                    calorieBadge
                }
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .foregroundStyle(NeoHomeColors.ink)
        .kitchenPaperObject(
            cornerRadius: 6,
            rotation: position.isMultiple(of: 2) ? 0.22 : -0.18,
            shadowRadius: 4,
            shadowY: 2
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var foodInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(entry.name)
                    .font(.system(.headline, design: .serif, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
                if foodStore.isFavorite(entry) {
                    Image(systemName: "heart.fill")
                        .font(.caption2.weight(.black))
                        .foregroundStyle(NeoHomeColors.cobalt)
                }
                Spacer(minLength: 2)
            }

            HStack(spacing: 6) {
                if let servingText {
                    Text(servingText)
                }
                Text(entry.timeString)
            }
            .font(.system(.caption, design: .default, weight: .semibold))
            .fontDesign(.serif)
            .foregroundStyle(NeoHomeColors.mutedInk)
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)

            Text(verbatim: "P \(MacroValueFormatter.withUnit(entry.protein))  ·  C \(MacroValueFormatter.withUnit(entry.carbs))  ·  F \(MacroValueFormatter.withUnit(entry.fat))")
                .font(.system(.caption2, design: .monospaced, weight: .medium))
                .foregroundStyle(NeoHomeColors.mutedInk)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var calorieBadge: some View {
        VStack(spacing: -1) {
            Text(entry.calories.formatted())
                .font(.system(.title3, design: .serif, weight: .semibold))
            Text(verbatim: "kcal")
                .textCase(.uppercase)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
        }
        .foregroundStyle(KitchenTablePalette.tomatoDeep)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(KitchenTablePalette.tomato.opacity(0.055), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .stroke(KitchenTablePalette.tomato.opacity(0.62), lineWidth: 1)
        }
        .rotationEffect(.degrees(1.2))
    }

    private var accessibilitySummary: String {
        var parts = [
            entry.name,
            "\(entry.calories) \(String(localized: "Calories").lowercased())"
        ]
        if let servingText { parts.append(servingText) }
        parts.append(entry.timeString)
        parts.append("\(String(localized: "Protein")) \(MacroValueFormatter.withUnit(entry.protein))")
        parts.append("\(String(localized: "Carbs")) \(MacroValueFormatter.withUnit(entry.carbs))")
        parts.append("\(String(localized: "Fat")) \(MacroValueFormatter.withUnit(entry.fat))")
        if foodStore.isFavorite(entry) { parts.append(String(localized: "Favorite")) }
        return parts.joined(separator: ", ")
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let imageData = entry.imageData, let image = UIImage(data: imageData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 57, height: 57)
                .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
                .padding(4)
                .background(KitchenTablePalette.paperRaised)
                .overlay {
                    Rectangle().stroke(KitchenTablePalette.rule, lineWidth: NeoHomeMetrics.compactRule)
                }
                .shadow(color: KitchenTablePalette.espresso.opacity(0.18), radius: 3, x: 0, y: 2)
                .rotationEffect(.degrees(position.isMultiple(of: 2) ? 1.1 : -1.3))
                .overlay(alignment: .bottomTrailing) {
                    if !entry.additionalImageData.isEmpty {
                        Text(verbatim: "+\(entry.additionalImageData.count)")
                            .font(.caption2.weight(.black))
                            .foregroundStyle(.white)
                            .padding(3)
                            .background(KitchenTablePalette.espresso, in: Capsule())
                    }
                }
        } else if let emoji = entry.emoji {
            Text(emoji)
                .font(.system(size: 27))
                .frame(width: 57, height: 57)
                .padding(4)
                .background(KitchenTablePalette.paperRaised)
                .overlay { Rectangle().stroke(KitchenTablePalette.rule, lineWidth: NeoHomeMetrics.compactRule) }
                .shadow(color: KitchenTablePalette.espresso.opacity(0.18), radius: 3, x: 0, y: 2)
                .rotationEffect(.degrees(position.isMultiple(of: 2) ? 1.1 : -1.3))
        } else {
            Image(systemName: "fork.knife")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(NeoHomeColors.cobalt)
                .frame(width: 57, height: 57)
                .padding(4)
                .background(KitchenTablePalette.paperRaised)
                .overlay { Rectangle().stroke(KitchenTablePalette.rule, lineWidth: NeoHomeMetrics.compactRule) }
                .shadow(color: KitchenTablePalette.espresso.opacity(0.18), radius: 3, x: 0, y: 2)
                .rotationEffect(.degrees(position.isMultiple(of: 2) ? 1.1 : -1.3))
        }
    }
}

struct NeoEmptyFoodPanel: View {
    let isToday: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "fork.knife")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(KitchenTablePalette.tomatoDeep)
                .frame(width: 38, height: 38)
                .background(KitchenTablePalette.tomato.opacity(0.08), in: Circle())
                .overlay { Circle().stroke(KitchenTablePalette.tomato.opacity(0.42), lineWidth: 1) }
            VStack(alignment: .leading, spacing: 2) {
                Text("No foods logged")
                    .font(.system(.headline, design: .serif, weight: .semibold))
                Group {
                    if isToday {
                        Text("Snap a photo — AI logs it")
                    } else {
                        Text("No foods logged on this day")
                    }
                }
                .font(.system(.caption, design: .serif))
                .foregroundStyle(NeoHomeColors.mutedInk)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(NeoHomeColors.ink)
        .frame(maxWidth: .infinity)
        .padding(12)
        .kitchenPaperObject(cornerRadius: 7, rotation: 0.25, shadowRadius: 4, shadowY: 2)
    }
}

struct NeoAddFoodLabel: View {
    @ScaledMetric(relativeTo: .headline) private var labelSize = 16

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus")
                .font(.system(size: 16, weight: .bold))
            Text("Add Food")
                .textCase(.uppercase)
                .font(.system(size: labelSize, weight: .bold, design: .monospaced))
                .tracking(0.5)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .layoutPriority(1)
            Spacer()
            Image(systemName: "viewfinder")
                .font(.system(size: 15, weight: .semibold))
        }
        .foregroundStyle(KitchenTablePalette.tomatoDeep)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, minHeight: 46)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(KitchenTablePalette.paperRaised)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(KitchenTablePalette.tomato.opacity(0.78), lineWidth: 1.25)
        }
        .shadow(color: KitchenTablePalette.espresso.opacity(0.12), radius: 5, x: 0, y: 3)
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Add Food")
        .accessibilityIdentifier("neo.home.addFood")
    }
}
