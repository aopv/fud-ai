import SwiftUI
import UIKit

// MARK: - Shared Neo-Brutalist primitives

private extension View {
    func neoHomeOutline(_ color: Color = NeoHomeColors.ink, width: CGFloat = NeoHomeMetrics.rule) -> some View {
        overlay {
            Rectangle()
                .strokeBorder(color, lineWidth: width)
                .allowsHitTesting(false)
        }
    }

    func neoHomeTitleStyle(size: CGFloat) -> some View {
        font(.system(size: size, weight: .black, design: .default))
            .fontWidth(.condensed)
    }
}

struct NeoHomeDateHeader: View {
    @Binding var selectedDate: Date
    @State private var showDatePicker = false
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize = 50

    private var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    private var title: String {
        if isToday { return String(localized: "Today").uppercased() }
        return selectedDate.formatted(.dateTime.weekday(.wide)).uppercased()
    }

    private var subtitle: String {
        selectedDate.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .neoHomeTitleStyle(size: titleSize)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                Text(subtitle)
                    .font(.system(.headline, design: .default, weight: .bold))
                    .fontWidth(.condensed)
                    .lineLimit(1)
            }
            .foregroundStyle(NeoHomeColors.ink)

            Spacer(minLength: 8)
            calendarButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(NeoHomeColors.surface)
        .neoHomeOutline()
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var calendarButton: some View {
        if #available(iOS 26.0, *) {
            Button {
                showDatePicker = true
            } label: {
                Image(systemName: "calendar")
                    .font(.system(size: 20, weight: .bold))
                    .frame(width: 46, height: 46)
            }
            .buttonStyle(.glass)
            .tint(NeoHomeColors.ink)
            .accessibilityLabel("Choose date")
            .datePickerPopover(isPresented: $showDatePicker, selection: $selectedDate)
        } else {
            Button {
                showDatePicker = true
            } label: {
                Image(systemName: "calendar")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(NeoHomeColors.ink)
                    .frame(width: 46, height: 46)
                    .background(.ultraThinMaterial)
                    .neoHomeOutline(width: NeoHomeMetrics.compactRule)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Choose date")
            .datePickerPopover(isPresented: $showDatePicker, selection: $selectedDate)
        }
    }
}

private extension View {
    func datePickerPopover(isPresented: Binding<Bool>, selection: Binding<Date>) -> some View {
        popover(isPresented: isPresented, arrowEdge: .top) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Choose Date")
                    .font(.headline.weight(.black))
                    .fontWidth(.condensed)
                DatePicker(
                    "Date",
                    selection: selection,
                    in: ...Date.now,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .labelsHidden()
            }
            .padding(16)
            .frame(idealWidth: 330)
            .presentationCompactAdaptation(.popover)
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
    @ScaledMetric(relativeTo: .largeTitle) private var calorieSize = 70
    @ScaledMetric(relativeTo: .title) private var targetSize = 31

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
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 10) {
                    caloriePanel
                    targetPanel
                }
            } else {
                HStack(alignment: .top, spacing: 10) {
                    caloriePanel
                        .frame(maxWidth: .infinity)
                    targetPanel
                        .frame(width: 112)
                }
            }
        }
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
            withAnimation(.snappy(duration: 0.35)) { shownProgress = newValue }
        }
    }

    private var accessibilitySummary: String {
        guard goal > 0 else {
            return "\(String(localized: "Calories")) \(eaten), \(String(localized: "No goal"))"
        }
        return "\(String(localized: "Calories")) \(eaten), \(String(localized: "Target")) \(goal), \(delta) \(deltaLabel.lowercased())"
    }

    private var caloriePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Calories")
                .textCase(.uppercase)
                .font(.system(.subheadline, design: .default, weight: .black))
                .fontWidth(.condensed)
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(.black)

            HStack(alignment: .lastTextBaseline, spacing: 7) {
                Text(eaten.formatted())
                    .font(.system(size: calorieSize, weight: .black, design: .default))
                    .fontWidth(.condensed)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .contentTransition(.numericText())
                Text("kcal")
                    .font(.system(.headline, design: .default, weight: .black))
                    .fontWidth(.condensed)
            }
            .foregroundStyle(.white)

            VStack(spacing: 0) {
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text(delta.formatted())
                        .font(.system(.title2, design: .default, weight: .black))
                        .fontWidth(.condensed)
                    Text(deltaLabel)
                        .font(.system(.subheadline, design: .default, weight: .black))
                        .fontWidth(.condensed)
                    Spacer(minLength: 0)
                }
                .foregroundStyle(NeoHomeColors.ink)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(NeoHomeColors.surface)

                NeoSegmentedProgress(progress: shownProgress)
                    .padding(8)
                    .background(NeoHomeColors.surface)
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(NeoHomeColors.ink)
                            .frame(height: NeoHomeMetrics.compactRule)
                    }
            }
            .neoHomeOutline(NeoHomeColors.ink, width: NeoHomeMetrics.compactRule)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 238, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [NeoHomeColors.cobalt, NeoHomeColors.cobaltDeep],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .neoHomeOutline()
    }

    private var targetPanel: some View {
        VStack(spacing: 10) {
            Text("Target")
                .textCase(.uppercase)
                .font(.system(.caption, design: .default, weight: .black))
                .fontWidth(.condensed)
                .foregroundStyle(NeoHomeColors.paperWhite)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(.black)

            Image(systemName: "scope")
                .font(.system(size: 56, weight: .black))
                .foregroundStyle(NeoHomeColors.cobalt)
                .symbolRenderingMode(.monochrome)

            Spacer(minLength: 0)

            Text(goal.formatted())
                .font(.system(size: targetSize, weight: .black, design: .default))
                .fontWidth(.condensed)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .foregroundStyle(NeoHomeColors.ink)
            Text("GOAL\nkcal")
                .multilineTextAlignment(.center)
                .font(.system(.caption, design: .default, weight: .black))
                .fontWidth(.condensed)
                .foregroundStyle(NeoHomeColors.ink)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 238)
        .background(NeoHomeColors.surface)
        .neoHomeOutline()
    }

    private func playLaunchFill() {
        lastEpoch = launchFillEpoch
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
    private let segmentCount = 22

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<segmentCount, id: \.self) { index in
                Rectangle()
                    .fill(index < Int(ceil(progress * Double(segmentCount))) ? NeoHomeColors.ink : NeoHomeColors.ink.opacity(0.18))
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 20)
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
        return Array(repeating: GridItem(.flexible(minimum: 54), spacing: 0), count: count)
    }

    var body: some View {
        LazyVGrid(columns: columns, alignment: .center, spacing: 0) {
            ForEach(stats) { stat in
                NeoNutrientTile(stat: stat, launchFillEpoch: launchFillEpoch)
            }
        }
        .background(NeoHomeColors.surface)
        .neoHomeOutline()
        .accessibilityIdentifier("neo.home.nutrientGrid")
    }
}

private struct NeoNutrientTile: View {
    let stat: NeoNutrientStat
    let launchFillEpoch: Int
    @ScaledMetric(relativeTo: .title2) private var valueSize = 27
    @State private var shownProgress = 0.0
    @State private var lastEpoch = -1

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
        VStack(spacing: 8) {
            Text(stat.label.uppercased())
                .font(.system(.caption, design: .default, weight: .black))
                .fontWidth(.condensed)
                .lineLimit(1)
                .minimumScaleFactor(0.65)

            Image(systemName: stat.iconName)
                .font(.system(size: 27, weight: .black))
                .foregroundStyle(NeoHomeColors.cobalt)
                .frame(height: 32)

            HStack(alignment: .lastTextBaseline, spacing: 1) {
                Text(MacroValueFormatter.string(stat.current))
                    .font(.system(size: valueSize, weight: .black, design: .default))
                    .fontWidth(.condensed)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(stat.unit)
                    .font(.system(.caption, design: .default, weight: .black))
                    .fontWidth(.condensed)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Rectangle().fill(NeoHomeColors.ink.opacity(0.14))
                    Rectangle()
                        .fill(NeoHomeColors.cobalt)
                        .frame(width: proxy.size.width * shownProgress)
                }
            }
            .frame(height: 5)
            .neoHomeOutline(NeoHomeColors.ink, width: NeoHomeMetrics.compactRule)
            .accessibilityHidden(true)

            Text(statusText)
                .font(.system(.caption2, design: .default, weight: .black))
                .fontWidth(.condensed)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .foregroundStyle(NeoHomeColors.onCobalt)
                .padding(.horizontal, 5)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity)
                .background(NeoHomeColors.cobalt)
                .neoHomeOutline(NeoHomeColors.ink, width: NeoHomeMetrics.compactRule)
        }
        .foregroundStyle(NeoHomeColors.ink)
        .padding(.horizontal, 6)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 158)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(NeoHomeColors.ink)
                .frame(width: NeoHomeMetrics.compactRule)
        }
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
            withAnimation(.snappy(duration: 0.35)) { shownProgress = newValue }
        }
    }

    private func playLaunchFill() {
        lastEpoch = launchFillEpoch
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
                    Rectangle().fill(NeoHomeColors.ink.opacity(0.16))
                    Rectangle()
                        .fill(NeoHomeColors.cobalt)
                        .frame(width: proxy.size.width * progress)
                }
            }
            .frame(height: 10)
            .neoHomeOutline(NeoHomeColors.ink, width: NeoHomeMetrics.compactRule)
        }
        .foregroundStyle(NeoHomeColors.ink)
        .padding(12)
        .background(NeoHomeColors.surface)
        .neoHomeOutline()
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
                    .textCase(.uppercase)
                    .font(.system(.subheadline, design: .default, weight: .black))
                    .fontWidth(.condensed)
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(.subheadline, weight: .black))
            }
            .foregroundStyle(NeoHomeColors.ink)
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(NeoHomeColors.surface)
            .neoHomeOutline()
        }
        .buttonStyle(.plain)
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
        .neoHomeOutline()
    }
}

struct NeoHomeSectionBanner: View {
    let title: String
    let iconName: String

    var body: some View {
        Label {
            Text(LocalizedStringKey(title)).textCase(.uppercase)
        } icon: {
            Image(systemName: iconName)
        }
            .font(.system(.title2, design: .default, weight: .black))
            .fontWidth(.condensed)
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .frame(minHeight: 50)
            .background(NeoHomeColors.acidYellow)
            .neoHomeOutline(.black)
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
                        Rectangle().fill(NeoHomeColors.ink.opacity(0.14))
                        Rectangle()
                            .fill(NeoHomeColors.cobalt)
                            .frame(width: proxy.size.width * progress)
                    }
                }
                .frame(height: 8)
                .neoHomeOutline(width: NeoHomeMetrics.compactRule)
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
        .foregroundStyle(.black)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(NeoHomeColors.acidYellow)
        .neoHomeOutline(.black)
        .accessibilityElement(children: .contain)
    }

    private var titleLabel: some View {
        Label(title.uppercased(), systemImage: iconName)
            .font(.system(.title2, design: .default, weight: .black))
            .fontWidth(.condensed)
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
            .minimumScaleFactor(0.6)
    }

    @ViewBuilder
    private var sortControl: some View {
        if showsSort {
            Menu {
                Picker("Food Log Order", selection: $sortOrderRaw) {
                    ForEach(FoodLogSortOrder.allCases) { order in
                        Text(order.displayName).tag(order.rawValue)
                    }
                }
            } label: {
                Label("Sort", systemImage: "arrow.up.arrow.down")
                    .labelStyle(.iconOnly)
                    .font(.system(.subheadline, weight: .black))
                    .frame(width: 44, height: 44)
                    .neoHomeOutline(.black, width: NeoHomeMetrics.compactRule)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Sort food log")
        }
    }

    private var shareControl: some View {
        Button(action: onShare) {
            Image(systemName: "square.and.arrow.up")
                .font(.system(.subheadline, weight: .black))
                .frame(width: 44, height: 44)
                .neoHomeOutline(.black, width: NeoHomeMetrics.compactRule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Share \(title)")
    }

    private var totals: some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text("\(totalCalories.formatted()) KCAL")
                .font(.system(.subheadline, design: .default, weight: .black))
                .fontWidth(.condensed)
            Text("\(Int(totalProtein.rounded()))P · \(Int(totalCarbs.rounded()))C · \(Int(totalFat.rounded()))F")
                .font(.system(.caption2, design: .default, weight: .bold))
                .fontWidth(.condensed)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.65)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .neoHomeOutline(.black, width: NeoHomeMetrics.compactRule)
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
                        positionBadge
                        thumbnail
                        Spacer(minLength: 4)
                        calorieBadge
                    }
                    foodInfo
                }
            } else {
                HStack(alignment: .center, spacing: 10) {
                    positionBadge
                    thumbnail
                    foodInfo
                    calorieBadge
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .foregroundStyle(NeoHomeColors.ink)
        .background(NeoHomeColors.surface)
        .neoHomeOutline(width: NeoHomeMetrics.compactRule)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var positionBadge: some View {
        Text(String(format: "%02d", position))
            .font(.system(.headline, design: .monospaced, weight: .black))
            .foregroundStyle(NeoHomeColors.paperWhite)
            .frame(width: 38, height: 38)
            .background(.black)
    }

    private var foodInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(entry.name.uppercased())
                    .font(.system(.headline, design: .default, weight: .black))
                    .fontWidth(.condensed)
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
            .fontWidth(.condensed)
            .foregroundStyle(NeoHomeColors.mutedInk)
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)

            Text("P \(MacroValueFormatter.withUnit(entry.protein))  ·  C \(MacroValueFormatter.withUnit(entry.carbs))  ·  F \(MacroValueFormatter.withUnit(entry.fat))")
                .font(.system(.caption2, design: .default, weight: .bold))
                .fontWidth(.condensed)
                .foregroundStyle(NeoHomeColors.mutedInk)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var calorieBadge: some View {
        VStack(spacing: 0) {
            Text(entry.calories.formatted())
                .font(.system(.title3, design: .default, weight: .black))
                .fontWidth(.condensed)
            Text("KCAL")
                .font(.system(.caption2, design: .default, weight: .black))
                .fontWidth(.condensed)
        }
        .foregroundStyle(NeoHomeColors.ink)
        .padding(.horizontal, 7)
        .padding(.vertical, 7)
        .neoHomeOutline(width: NeoHomeMetrics.compactRule)
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
                .frame(width: 52, height: 52)
                .clipped()
                .neoHomeOutline(width: NeoHomeMetrics.compactRule)
                .overlay(alignment: .bottomTrailing) {
                    if !entry.additionalImageData.isEmpty {
                        Text("+\(entry.additionalImageData.count)")
                            .font(.caption2.weight(.black))
                            .foregroundStyle(.white)
                            .padding(3)
                            .background(.black)
                    }
                }
        } else if let emoji = entry.emoji {
            Text(emoji)
                .font(.system(size: 27))
                .frame(width: 52, height: 52)
                .background(NeoHomeColors.surface)
                .neoHomeOutline(width: NeoHomeMetrics.compactRule)
        } else {
            Image(systemName: "fork.knife")
                .font(.system(size: 20, weight: .black))
                .foregroundStyle(NeoHomeColors.cobalt)
                .frame(width: 52, height: 52)
                .background(NeoHomeColors.surface)
                .neoHomeOutline(width: NeoHomeMetrics.compactRule)
        }
    }
}

struct NeoEmptyFoodPanel: View {
    let isToday: Bool

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "fork.knife")
                .font(.system(size: 28, weight: .black))
                .foregroundStyle(NeoHomeColors.cobalt)
            Text("No foods logged")
                .textCase(.uppercase)
                .font(.system(.headline, design: .default, weight: .black))
                .fontWidth(.condensed)
        }
        .foregroundStyle(NeoHomeColors.ink)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(NeoHomeColors.surface)
        .neoHomeOutline()
    }
}

struct NeoAddFoodLabel: View {
    @ScaledMetric(relativeTo: .title2) private var labelSize = 28

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus")
                .font(.system(size: 28, weight: .black))
            Text("Add Food")
                .textCase(.uppercase)
                .font(.system(size: labelSize, weight: .black, design: .default))
                .fontWidth(.condensed)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .layoutPriority(1)
            Spacer()
            Image(systemName: "viewfinder")
                .font(.system(size: 21, weight: .black))
                .frame(width: 44, height: 44)
                .background(.white.opacity(0.42))
                .neoHomeOutline(.black, width: NeoHomeMetrics.compactRule)
        }
        .foregroundStyle(.black)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: 62)
        .background(NeoHomeColors.acidYellow)
        .neoHomeOutline(.black)
        .shadow(color: .black.opacity(0.85), radius: 0, x: 4, y: 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Add Food")
        .accessibilityIdentifier("neo.home.addFood")
    }
}
