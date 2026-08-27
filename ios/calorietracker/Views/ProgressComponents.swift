import SwiftUI
import Charts
import ImageIO
import UIKit

// MARK: - Time Range

enum TimeRange: String, CaseIterable {
    case week = "1W"
    case month = "1M"
    case threeMonths = "3M"
    case sixMonths = "6M"
    case year = "1Y"
    case allTime = "All"

    var days: Int {
        switch self {
        case .week: 7
        case .month: 30
        case .threeMonths: 90
        case .sixMonths: 180
        case .year: 365
        case .allTime: 3650
        }
    }

    func dateRange() -> ClosedRange<Date> {
        let calendar = Calendar.current
        let end = calendar.startOfDay(for: .now).addingTimeInterval(86399)
        let start = calendar.date(byAdding: .day, value: -(days - 1), to: calendar.startOfDay(for: .now))!
        return start...end
    }
}

// MARK: - Weight Chart Section

// MARK: - Trend chart plotting helpers (shared by Weight + Body Fat charts)

/// One plotted point on a trend chart — either a raw entry or the average of
/// a date bucket when the range is too dense to draw every reading.
private struct TrendPoint: Identifiable, Equatable {
    let date: Date
    let value: Double
    var id: Date { date }
}

/// Averages a date-sorted series into equal date buckets once it outgrows
/// `maxPoints`. Hundreds of raw readings drew every dot on top of its
/// neighbours and turned the line into a solid band — ~60 bucket averages
/// keep the trend shape readable. Sparse series pass through untouched.
private func downsampled(_ points: [TrendPoint], maxPoints: Int = 60) -> [TrendPoint] {
    guard let first = points.first?.date, let last = points.last?.date else { return points }
    let calendar = Calendar.current
    let spanDays = max(1, calendar.dateComponents([.day], from: first, to: last).day ?? 1)
    let rangeLimit: Int
    switch spanDays {
    case ...45: rangeLimit = 60
    case ...100: rangeLimit = 48
    case ...200: rangeLimit = 36
    case ...400: rangeLimit = 30
    default: rangeLimit = 24
    }
    let adaptiveLimit = min(maxPoints, rangeLimit)
    guard points.count > adaptiveLimit else { return points }
    let bucketDays = max(1, Int((Double(spanDays) / Double(adaptiveLimit)).rounded(.up)))
    var buckets: [Int: (dateSum: TimeInterval, valueSum: Double, count: Int)] = [:]
    for point in points {
        let day = calendar.dateComponents([.day], from: first, to: point.date).day ?? 0
        var bucket = buckets[day / bucketDays] ?? (0, 0, 0)
        bucket.dateSum += point.date.timeIntervalSince1970
        bucket.valueSum += point.value
        bucket.count += 1
        buckets[day / bucketDays] = bucket
    }
    return buckets.keys.sorted().map { index in
        let bucket = buckets[index]!
        return TrendPoint(
            date: Date(timeIntervalSince1970: bucket.dateSum / Double(bucket.count)),
            value: bucket.valueSum / Double(bucket.count)
        )
    }
}

/// X-axis policy for the trend charts. Strides derive from the plotted DATE
/// SPAN — the old entry-count strides collapsed once users logged multiple
/// readings per day (506 entries over 2 years still picked a 60-day stride
/// and mashed the "All" labels into each other). Labels pick up the year
/// whenever a longer range crosses a calendar-year boundary, so "going back
/// into 2025" reads "Sep 2025" instead of an ambiguous "Sep 20".
private struct TrendXAxis {
    private let spanDays: Int
    private let showsYear: Bool

    init(first: Date?, last: Date?) {
        guard let first, let last else {
            spanDays = 1
            showsYear = false
            return
        }
        spanDays = max(1, Calendar.current.dateComponents([.day], from: first, to: last).day ?? 1)
        showsYear = spanDays > 150
            && !Calendar.current.isDate(first, equalTo: last, toGranularity: .year)
    }

    var strideDays: Int {
        if showsYear { return max(75, spanDays / 4) }
        if spanDays <= 8 { return 1 }
        if spanDays <= 35 { return 5 }
        if spanDays <= 100 { return 14 }
        if spanDays <= 200 { return 30 }
        return 60
    }

    var labelFormat: Date.FormatStyle {
        showsYear ? .dateTime.month(.abbreviated).year() : .dateTime.month(.abbreviated).day()
    }
}

struct WeightChartSection: View {
    let weightEntries: [WeightEntry]
    let goalWeightKg: Double?
    let currentWeightKg: Double?
    let onLogWeight: () -> Void
    @AppStorage("weightUnit") private var weightUnitRaw = "lbs"
    @State private var inspectedPoint: TrendPoint?

    private var useMetric: Bool { weightUnitRaw == "kg" }

    private func displayWeight(_ kg: Double) -> Double {
        useMetric ? kg : kg * 2.20462
    }

    private var unit: String { useMetric ? "kg" : "lbs" }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("Weight")
                    .font(.system(.title3, design: .serif, weight: .bold))
                    .foregroundStyle(NeoAppColors.ink)
                Spacer()
                Button(action: onLogWeight) {
                    Label("Log Weight", systemImage: "plus.circle.fill")
                        .font(.system(.caption, design: .monospaced, weight: .bold))
                        .textCase(.uppercase)
                        .foregroundStyle(KitchenTablePalette.tomatoDeep)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 7)
                        .background(KitchenTablePalette.paper)
                        .overlay {
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .stroke(
                                    KitchenTablePalette.tomato,
                                    style: StrokeStyle(lineWidth: 0.9, dash: [3, 2])
                                )
                        }
                }
                .buttonStyle(.plain)
            }

            if weightEntries.isEmpty {
                emptyState("Log your first weight to see trends")
            } else {
                let chartPoints = plottedPoints

                HStack(spacing: 8) {
                    if let current = currentWeightKg {
                        StatBadge(label: "Current", value: String(format: "%.1f %@", displayWeight(current), unit))
                    }
                    if let goal = goalWeightKg {
                        StatBadge(label: "Goal", value: String(format: "%.1f %@", displayWeight(goal), unit))
                    }
                    StatBadge(label: "Net Change", value: formattedWeightChange)
                    StatBadge(label: "Average", value: formattedAverageWeight)
                }

                Chart {
                    ForEach(chartPoints) { point in
                        LineMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("Weight", point.value)
                        )
                        .foregroundStyle(NeoAppColors.cobalt)
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2))

                        if chartPoints.count <= 31 {
                            PointMark(
                                x: .value("Date", point.date, unit: .day),
                                y: .value("Weight", point.value)
                            )
                            .foregroundStyle(NeoAppColors.cobalt)
                            .symbolSize(30)
                        }
                    }

                    if let goalKg = goalWeightKg {
                        RuleMark(y: .value("Goal", displayWeight(goalKg)))
                            .foregroundStyle(NeoAppColors.success.opacity(0.9))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    }

                    if let inspectedPoint {
                        RuleMark(x: .value("Selected date", inspectedPoint.date))
                            .foregroundStyle(NeoAppColors.ink.opacity(0.55))
                            .lineStyle(StrokeStyle(lineWidth: 1.25, dash: [3, 3]))

                        PointMark(
                            x: .value("Selected date", inspectedPoint.date, unit: .day),
                            y: .value("Selected weight", inspectedPoint.value)
                        )
                        .foregroundStyle(.primary)
                        .symbolSize(115)

                        PointMark(
                            x: .value("Selected date", inspectedPoint.date, unit: .day),
                            y: .value("Selected weight", inspectedPoint.value)
                        )
                        .foregroundStyle(NeoAppColors.cobalt)
                        .symbolSize(52)
                    }
                }
                .chartYScale(domain: weightYDomain)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: xAxis.strideDays)) { _ in
                        AxisGridLine().foregroundStyle(KitchenTablePalette.rule)
                        AxisValueLabel(format: xAxis.labelFormat)
                    }
                }
                .chartPlotStyle { plotArea in
                    plotArea
                        .background(KitchenTablePalette.paperMuted.opacity(0.26))
                        .background(KitchenGraphPaper())
                }
                .frame(height: 132)
                .clipped()
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        let plotFrame = proxy.plotFrame.map { geometry[$0] }

                        ZStack(alignment: .topLeading) {
                            Color.clear
                                .contentShape(Rectangle())
                                .simultaneousGesture(
                                    DragGesture(minimumDistance: 6)
                                        .onChanged { value in
                                            guard abs(value.translation.width) > abs(value.translation.height),
                                                  let plotFrame else { return }
                                            inspectWeight(
                                                at: value.location.x - plotFrame.minX,
                                                proxy: proxy,
                                                points: chartPoints
                                            )
                                        }
                                        .onEnded { _ in
                                            withAnimation(.easeOut(duration: 0.16)) {
                                                inspectedPoint = nil
                                            }
                                        }
                                )

                            if let inspectedPoint,
                               let plotFrame,
                               let pointX = proxy.position(forX: inspectedPoint.date) {
                                weightInspectorLabel(for: inspectedPoint)
                                    .fixedSize()
                                    .position(
                                        x: min(max(plotFrame.minX + pointX, plotFrame.minX + 56), plotFrame.maxX - 56),
                                        y: plotFrame.minY + 26
                                    )
                                    .transition(.opacity.combined(with: .scale(scale: 0.94)))
                            }
                        }
                    }
                }
                .animation(.snappy(duration: 0.16), value: inspectedPoint?.date)
            }
        }
        .padding(11)
        .kitchenReceiptSurface(accent: KitchenTablePalette.cobalt)
    }

    /// What actually gets drawn: every entry for short ranges, bucket
    /// averages for dense ones. Dots only render while each reading is
    /// still individually distinguishable.
    private var plottedPoints: [TrendPoint] {
        downsampled(sortedWeightEntries.map { TrendPoint(date: $0.date, value: displayWeight($0.weightKg)) })
    }

    private var xAxis: TrendXAxis {
        TrendXAxis(first: sortedWeightEntries.first?.date, last: sortedWeightEntries.last?.date)
    }

    private var weightYDomain: ClosedRange<Double> {
        var weights = weightEntries.map { displayWeight($0.weightKg) }
        if let goalKg = goalWeightKg { weights.append(displayWeight(goalKg)) }
        guard let minW = weights.min(), let maxW = weights.max() else { return 0...200 }
        let padding = max((maxW - minW) * 0.15, 2)
        return (minW - padding)...(maxW + padding)
    }

    private var sortedWeightEntries: [WeightEntry] {
        weightEntries.sorted { $0.date < $1.date }
    }

    private var netWeightChange: Double {
        guard let first = sortedWeightEntries.first,
              let last = sortedWeightEntries.last else { return 0 }
        return displayWeight(last.weightKg) - displayWeight(first.weightKg)
    }

    private var averageWeight: Double {
        let values = sortedWeightEntries.map { displayWeight($0.weightKg) }
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private var formattedWeightChange: String {
        let sign = netWeightChange > 0 ? "+" : ""
        return String(format: "%@%.1f %@", sign, netWeightChange, unit)
    }

    private var formattedAverageWeight: String {
        String(format: "%.1f %@", averageWeight, unit)
    }

    private func inspectWeight(at plotX: CGFloat, proxy: ChartProxy, points: [TrendPoint]) {
        guard let date: Date = proxy.value(atX: plotX), !points.isEmpty else { return }
        let nearest = points.min {
            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
        }
        guard let nearest, nearest != inspectedPoint else { return }

        inspectedPoint = nearest
        UISelectionFeedbackGenerator().selectionChanged()
    }

    @ViewBuilder
    private func weightInspectorLabel(for point: TrendPoint) -> some View {
        VStack(spacing: 1) {
            Text(point.date.formatted(date: .abbreviated, time: .omitted))
                .font(.system(.caption2, design: .rounded, weight: .medium))
                .foregroundStyle(Color.black.opacity(0.68))
            Text(String(format: "%.1f %@", point.value, unit))
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(Color.black)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(NeoAppColors.brass, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(KitchenTablePalette.brassDeep, lineWidth: NeoAppMetrics.compactRule)
        }
    }
}

// MARK: - Calorie Chart Section

private final class OrganizerMealImageBox: @unchecked Sendable {
    let cgImage: CGImage
    let cost: Int

    nonisolated init(cgImage: CGImage, cost: Int) {
        self.cgImage = cgImage
        self.cost = cost
    }
}

private actor OrganizerMealImagePipeline {
    static let shared = OrganizerMealImagePipeline()

    private let cache: NSCache<NSString, OrganizerMealImageBox>

    private init() {
        let cache = NSCache<NSString, OrganizerMealImageBox>()
        cache.countLimit = 84
        cache.totalCostLimit = 12 * 1_024 * 1_024
        self.cache = cache
    }

    func image(data: Data, cacheKey: String, maxPixelSize: Int) -> OrganizerMealImageBox? {
        let key = cacheKey as NSString
        if let cached = cache.object(forKey: key) {
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

        let box = OrganizerMealImageBox(
            cgImage: cgImage,
            cost: cgImage.bytesPerRow * cgImage.height
        )
        guard !Task.isCancelled else { return nil }
        cache.setObject(box, forKey: key, cost: box.cost)
        return box
    }
}

private struct OrganizerMealThumbnail: View {
    private struct LoadedImage {
        let requestKey: String
        let image: UIImage
    }

    let entryID: UUID
    let imageData: Data?
    let imageFilename: String?
    let emoji: String?
    let fallbackSystemImage: String
    let accent: Color

    @Environment(\.displayScale) private var displayScale
    @State private var loadedImage: LoadedImage?

    private var maxPixelSize: Int {
        max(Int((36 * displayScale).rounded(.up)), 1)
    }

    private var requestKey: String {
        let imageIdentity = imageFilename ?? "inline-\(imageData?.count ?? 0)"
        return "\(entryID.uuidString)|\(imageIdentity)|\(maxPixelSize)"
    }

    var body: some View {
        Group {
            if let loadedImage, loadedImage.requestKey == requestKey {
                Image(uiImage: loadedImage.image)
                    .resizable()
                    .scaledToFill()
            } else if let emoji, !emoji.isEmpty {
                Text(emoji)
                    .font(.system(size: 18))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(accent.opacity(0.08))
            } else {
                Image(systemName: fallbackSystemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(accent.opacity(0.08))
            }
        }
        .task(id: requestKey) {
            loadedImage = nil
            guard let imageData else { return }
            let result = await OrganizerMealImagePipeline.shared.image(
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

struct CalorieChartSection: View {
    let calorieGoal: Int
    let foodEntries: [FoodEntry]
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// `dailyCalories` remains in the initializer for source compatibility
    /// with the selected-range detail screen. This receipt intentionally
    /// derives every visible value from its own seven-day `foodEntries` input.
    init(
        dailyCalories _: [(date: Date, calories: Int)],
        calorieGoal: Int,
        foodEntries: [FoodEntry] = []
    ) {
        self.calorieGoal = calorieGoal
        self.foodEntries = foodEntries
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            weeklyHeader

            calorieOrganizer

            if weeklyCalorieData.isEmpty {
                Text("No food logged in this week")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(KitchenTablePalette.mutedEspresso)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .accessibilityLabel("No food logged in this week")
            } else {
                HStack(spacing: 8) {
                    Text("TREND")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .tracking(0.8)
                    KitchenReceiptRule(color: KitchenTablePalette.rule)
                }
                .foregroundStyle(KitchenTablePalette.mutedEspresso)

                Chart {
                    ForEach(weeklyCalorieData, id: \.date) { item in
                        BarMark(
                            x: .value("Date", item.date, unit: .day),
                            y: .value("Calories", item.calories)
                        )
                        .foregroundStyle(KitchenTablePalette.tomato)
                        .cornerRadius(5)
                    }

                    RuleMark(y: .value("Goal", calorieGoal))
                        .foregroundStyle(NeoAppColors.ink.opacity(0.7))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisGridLine().foregroundStyle(KitchenTablePalette.rule)
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
                .chartXScale(domain: weeklyChartDomain)
                .accessibilityLabel("Seven-day calorie trend")
                .chartPlotStyle { plotArea in
                    plotArea
                        .background(KitchenTablePalette.paperMuted.opacity(0.26))
                        .background(KitchenGraphPaper(color: KitchenTablePalette.tomato))
                }
                // Dense chart axes stop being legible when each tick scales to
                // accessibility sizes. VoiceOver still receives the chart's
                // summary while the visual ticks remain readable and distinct.
                .dynamicTypeSize(...DynamicTypeSize.large)
                .frame(height: 96)
            }
        }
        .padding(11)
        .background(KitchenTablePalette.paperMuted.opacity(0.24))
        .background(KitchenGraphPaper(color: KitchenTablePalette.brass))
        .kitchenReceiptSurface(accent: KitchenTablePalette.herb)
    }

    @ViewBuilder
    private var weeklyHeader: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                weeklyTitleBlock
                if let weeklyAverage {
                    weeklyAverageBadge(weeklyAverage)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        } else {
            HStack {
                weeklyTitleBlock
                Spacer()
                if let weeklyAverage {
                    weeklyAverageBadge(weeklyAverage)
                }
            }
        }
    }

    private var weeklyTitleBlock: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("Weekly Intake")
                .font(.system(.title3, design: .serif, weight: .bold))
                .foregroundStyle(NeoAppColors.ink)
                .fixedSize(horizontal: false, vertical: true)
            if let first = organizerDays.first?.date, let last = organizerDays.last?.date {
                Text(
                    "\(first.formatted(.dateTime.month(.abbreviated).day())) – \(last.formatted(.dateTime.month(.abbreviated).day()))",
                    comment: "Seven-day date range. The first argument is the start date and the second is the end date."
                )
                .font(
                    dynamicTypeSize.isAccessibilitySize
                        ? .system(.caption, design: .monospaced, weight: .semibold)
                        : .system(size: 9, weight: .semibold, design: .monospaced)
                )
                .foregroundStyle(KitchenTablePalette.mutedEspresso)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var weeklyAverage: Int? {
        guard !weeklyCalorieData.isEmpty else { return nil }
        return weeklyCalorieData.reduce(0) { $0 + $1.calories } / weeklyCalorieData.count
    }

    private func weeklyAverageBadge(_ average: Int) -> some View {
        Text(
            "Avg: \(average) kcal",
            comment: "Average calorie intake across logged days in the seven-day organizer."
        )
        .font(
            dynamicTypeSize.isAccessibilitySize
                ? .system(.body, design: .monospaced, weight: .bold)
                : .system(.caption, design: .monospaced, weight: .bold)
        )
        .foregroundStyle(KitchenTablePalette.tomatoDeep)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(KitchenTablePalette.paperMuted.opacity(0.55))
        .overlay {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(KitchenTablePalette.tomato.opacity(0.7), lineWidth: 0.8)
        }
    }

    private struct OrganizerDay: Identifiable {
        let date: Date
        let calories: Int?
        let mealGroups: [OrganizerMeal]

        var id: Date { date }
    }

    private struct OrganizerMeal: Identifiable {
        let mealType: MealType
        let entries: [FoodEntry]
        let representative: FoodEntry

        var id: String { mealType.rawValue }
    }

    private enum OrganizerSlotID: String, Identifiable, CaseIterable {
        case first
        case second
        case third

        var id: String { rawValue }

        var position: Int {
            switch self {
            case .first: 0
            case .second: 1
            case .third: 2
            }
        }
    }

    private struct OrganizerSlot: Identifiable {
        let id: OrganizerSlotID
        let meal: OrganizerMeal?
        let overflowCount: Int
    }

    /// Keep the organizer shaped like a complete week even when the log is
    /// sparse. Empty slots are calendar days with no entry, not fabricated
    /// nutrition data.
    private var organizerDays: [OrganizerDay] {
        let calendar = Calendar.current
        let endDate = calendar.startOfDay(for: .now)
        let startDate = calendar.date(byAdding: .day, value: -6, to: endDate) ?? endDate
        let endExclusive = calendar.date(byAdding: .day, value: 1, to: endDate) ?? endDate
        let groupedEntries = Dictionary(grouping: foodEntries.filter { entry in
            entry.timestamp >= startDate && entry.timestamp < endExclusive
        }) { entry in
            calendar.startOfDay(for: entry.timestamp)
        }
        .mapValues { entries in
            entries.sorted { $0.timestamp < $1.timestamp }
        }

        return (-6...0).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: endDate) else {
                return nil
            }
            let entries = groupedEntries[date] ?? []
            return OrganizerDay(
                date: date,
                calories: entries.isEmpty ? nil : entries.reduce(0) { $0 + $1.calories },
                mealGroups: organizerMeals(for: entries)
            )
        }
    }

    private var weeklyCalorieData: [(date: Date, calories: Int)] {
        organizerDays.compactMap { day in
            guard let calories = day.calories else { return nil }
            return (date: day.date, calories: calories)
        }
    }

    private var weeklyChartDomain: ClosedRange<Date> {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let start = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        let end = calendar.date(byAdding: .day, value: 1, to: today)?.addingTimeInterval(-1) ?? today
        return start...end
    }

    private func organizerMeals(for entries: [FoodEntry]) -> [OrganizerMeal] {
        let grouped = Dictionary(grouping: entries) { $0.mealType.rawValue }
        return MealType.allCases.compactMap { mealType in
            guard let entries = grouped[mealType.rawValue], !entries.isEmpty else { return nil }
            let sortedEntries = entries.sorted { $0.timestamp < $1.timestamp }
            let representative = sortedEntries.first(where: { $0.imageData != nil })
                ?? sortedEntries.first(where: { !($0.emoji?.isEmpty ?? true) })
                ?? sortedEntries[0]
            return OrganizerMeal(
                mealType: mealType,
                entries: sortedEntries,
                representative: representative
            )
        }
    }

    private func organizerSlots(for mealGroups: [OrganizerMeal]) -> [OrganizerSlot] {
        let visibleMeals = Array(mealGroups.prefix(3))
        let hiddenEntryCount = mealGroups.dropFirst(3).reduce(0) { partial, meal in
            partial + meal.entries.count
        }

        return OrganizerSlotID.allCases.map { slotID in
            guard visibleMeals.indices.contains(slotID.position) else {
                return OrganizerSlot(id: slotID, meal: nil, overflowCount: 0)
            }
            let meal = visibleMeals[slotID.position]
            let hiddenEntriesInMeal = max(meal.entries.count - 1, 0)
            let hiddenAfterVisibleMeals = slotID == .third ? hiddenEntryCount : 0
            return OrganizerSlot(
                id: slotID,
                meal: meal,
                overflowCount: hiddenEntriesInMeal + hiddenAfterVisibleMeals
            )
        }
    }

    private var calorieOrganizer: some View {
        VStack(spacing: 5) {
            ForEach(Array(organizerDays.enumerated()), id: \.element.id) { index, item in
                organizerDayContent(item, index: index)
                .padding(5)
                .background(KitchenTablePalette.paperRaised.opacity(0.66))
                .overlay {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(
                            index == organizerDays.count - 1 ? KitchenTablePalette.herb : KitchenTablePalette.rule,
                            lineWidth: index == organizerDays.count - 1 ? 1.1 : 0.7
                        )
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(item.date.formatted(date: .complete, time: .omitted))
                .accessibilityValue(organizerAccessibilityValue(for: item))
            }
        }
    }

    @ViewBuilder
    private func organizerDayContent(_ item: OrganizerDay, index: Int) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                        .font(.system(.headline, design: .serif, weight: .bold))
                        .foregroundStyle(index == organizerDays.count - 1 ? KitchenTablePalette.herb : KitchenTablePalette.espresso)
                        .fixedSize(horizontal: false, vertical: true)

                    if let calories = item.calories {
                        Text(verbatim: "\(calories.formatted()) kcal")
                            .font(.system(.body, design: .serif, weight: .bold))
                            .foregroundStyle(KitchenTablePalette.tomatoDeep)
                            .monospacedDigit()
                    } else {
                        Text("No calories logged")
                            .font(.system(.body, design: .serif))
                            .foregroundStyle(KitchenTablePalette.mutedEspresso)
                    }
                }

                if item.mealGroups.isEmpty {
                    Text("No foods logged")
                        .font(.system(.body, design: .serif))
                        .foregroundStyle(KitchenTablePalette.mutedEspresso)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                } else {
                    VStack(spacing: 6) {
                        ForEach(organizerSlots(for: item.mealGroups)) { slot in
                            if let meal = slot.meal {
                                organizerAccessibleMealCell(
                                    meal,
                                    position: slot.id.position,
                                    overflowCount: slot.overflowCount
                                )
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(spacing: 7) {
                VStack(spacing: 0) {
                    Text(item.date.formatted(.dateTime.weekday(.abbreviated)))
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .textCase(.uppercase)
                    Text(item.date.formatted(.dateTime.day()))
                        .font(.system(.headline, design: .serif, weight: .bold))
                }
                .foregroundStyle(index == organizerDays.count - 1 ? KitchenTablePalette.herb : KitchenTablePalette.espresso)
                .frame(width: 34)

                HStack(spacing: 4) {
                    ForEach(organizerSlots(for: item.mealGroups)) { slot in
                        if let meal = slot.meal {
                            organizerMealCell(
                                meal,
                                position: slot.id.position,
                                overflowCount: slot.overflowCount
                            )
                        } else {
                            organizerEmptyCell
                        }
                    }
                }

                Text(item.calories?.formatted() ?? "—")
                    .font(.system(.subheadline, design: .serif, weight: .bold))
                    .monospacedDigit()
                    .frame(width: 62)
                    .frame(minHeight: 34)
                    .background(KitchenTablePalette.paperRaised, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(KitchenTablePalette.rule, lineWidth: 0.8)
                    }
            }
        }
    }

    private func organizerAccessibleMealCell(
        _ meal: OrganizerMeal,
        position: Int,
        overflowCount: Int
    ) -> some View {
        let entry = meal.representative

        return HStack(spacing: 9) {
            OrganizerMealThumbnail(
                entryID: entry.id,
                imageData: entry.imageData,
                imageFilename: entry.imageFilename,
                emoji: entry.emoji,
                fallbackSystemImage: meal.mealType.icon,
                accent: mealAccent(for: meal.mealType)
            )
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))

            Text(meal.mealType.displayName)
                .font(.system(.body, design: .serif, weight: .semibold))
                .foregroundStyle(mealAccent(for: meal.mealType))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 4)

            if overflowCount > 0 {
                Text(verbatim: "+\(overflowCount.formatted())")
                    .font(.system(.body, design: .monospaced, weight: .bold))
                    .foregroundStyle(KitchenTablePalette.paperRaised)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(KitchenTablePalette.espresso)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .background(KitchenTablePalette.paperRaised)
        .overlay {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .stroke(mealAccent(for: meal.mealType).opacity(0.68), lineWidth: 0.8)
        }
        .rotationEffect(.degrees(position.isMultiple(of: 2) ? -0.25 : 0.25))
        .accessibilityHidden(true)
    }

    private func organizerMealCell(
        _ meal: OrganizerMeal,
        position: Int,
        overflowCount: Int
    ) -> some View {
        let entry = meal.representative

        return ZStack(alignment: .bottom) {
            OrganizerMealThumbnail(
                entryID: entry.id,
                imageData: entry.imageData,
                imageFilename: entry.imageFilename,
                emoji: entry.emoji,
                fallbackSystemImage: meal.mealType.icon,
                accent: mealAccent(for: meal.mealType)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Text(meal.mealType.displayName)
                .font(.system(size: 5, weight: .bold, design: .monospaced))
                .tracking(0.25)
                .foregroundStyle(mealAccent(for: meal.mealType))
                .lineLimit(1)
                .padding(.horizontal, 2)
                .padding(.vertical, 1)
                .frame(maxWidth: .infinity)
                .background(KitchenTablePalette.paperRaised.opacity(0.90))
        }
        .frame(maxWidth: .infinity, minHeight: 36, maxHeight: 36)
        .clipped()
        .background(KitchenTablePalette.paperRaised)
        .overlay {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .stroke(mealAccent(for: meal.mealType).opacity(0.68), lineWidth: 0.8)
        }
        .rotationEffect(.degrees(position.isMultiple(of: 2) ? -0.4 : 0.4))
        .overlay(alignment: .topTrailing) {
            if overflowCount > 0 {
                Text(verbatim: "+\(overflowCount.formatted())")
                    .font(.system(size: 6, weight: .bold, design: .monospaced))
                    .foregroundStyle(KitchenTablePalette.paperRaised)
                    .padding(.horizontal, 3)
                    .padding(.vertical, 2)
                    .background(KitchenTablePalette.espresso)
            }
        }
        .accessibilityHidden(true)
    }

    private var organizerEmptyCell: some View {
        Text(verbatim: "—")
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(KitchenTablePalette.mutedEspresso.opacity(0.45))
            .frame(maxWidth: .infinity, minHeight: 36, maxHeight: 36)
            .background(KitchenTablePalette.paperMuted.opacity(0.42))
            .overlay {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .stroke(KitchenTablePalette.rule.opacity(0.68), style: StrokeStyle(lineWidth: 0.7, dash: [2, 2]))
            }
            .accessibilityHidden(true)
    }

    private func mealAccent(for mealType: MealType) -> Color {
        switch mealType {
        case .breakfast: KitchenTablePalette.brassDeep
        case .lunch: KitchenTablePalette.herbDeep
        case .dinner: KitchenTablePalette.cobaltDeep
        case .snack: KitchenTablePalette.tomatoDeep
        case .other: KitchenTablePalette.espresso
        }
    }

    private func organizerAccessibilityValue(for day: OrganizerDay) -> String {
        guard let calories = day.calories else { return String(localized: "No calories logged") }
        guard !day.mealGroups.isEmpty else { return String(localized: "\(calories) calories") }
        let groups = day.mealGroups.map { meal in
            String(localized: "\(meal.mealType.displayName): \(meal.entries.count) entries")
        }
        .formatted()
        return String(localized: "\(calories) calories. Meal groups: \(groups)")
    }

}

// MARK: - Macro Averages Section

struct MacroAveragesSection: View {
    let avgProtein: Double
    let avgCarbs: Double
    let avgFat: Double
    let proteinGoal: Int
    let carbsGoal: Int
    let fatGoal: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Macro Averages")
                .font(.system(.title3, design: .serif, weight: .bold))
                .foregroundStyle(NeoAppColors.ink)

            MacroProgressRow(label: "Protein", current: avgProtein, goal: proteinGoal, color: AppColors.protein, gradientColors: AppColors.proteinGradient)
            MacroProgressRow(label: "Carbs", current: avgCarbs, goal: carbsGoal, color: AppColors.carbs, gradientColors: AppColors.carbsGradient)
            MacroProgressRow(label: "Fat", current: avgFat, goal: fatGoal, color: AppColors.fat, gradientColors: AppColors.fatGradient)
        }
        .padding(11)
        .kitchenReceiptSurface(accent: KitchenTablePalette.herb)
    }
}

struct MacroProgressRow: View {
    let label: String
    let current: Double
    let goal: Int
    let color: Color
    let gradientColors: [Color]

    private var progress: Double {
        goal > 0 ? min(current / Double(goal), 1.0) : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(LocalizedDisplayText.text(label))
                    .font(.system(.caption, design: .monospaced, weight: .bold))
                    .textCase(.uppercase)
                    .foregroundStyle(NeoAppColors.ink)
                Spacer()
                Text("\(MacroValueFormatter.withUnit(current)) / \(goal)g")
                    .font(.system(.caption, design: .monospaced, weight: .semibold))
                    .foregroundStyle(NeoAppColors.mutedInk)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(NeoAppColors.subtleSurface)

                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(LinearGradient(colors: gradientColors, startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(4, geo.size.width * progress))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .stroke(NeoAppColors.ink.opacity(0.24), lineWidth: NeoAppMetrics.compactRule)
                }
            }
            .frame(height: 8)
        }
    }
}

// MARK: - Stats Section

struct StatsSection: View {
    let streak: Int
    let daysOnTarget: Int
    let totalEntries: Int
    let bestStreak: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Streaks & Stats")
                .font(.system(.title3, design: .serif, weight: .bold))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatTile(icon: "flame.fill", label: "Current Streak", value: "\(streak) days", color: AppColors.calorie)
                StatTile(icon: "trophy.fill", label: "Best Streak", value: "\(bestStreak) days", color: AppColors.carbs)
                StatTile(icon: "target", label: "Days on Target", value: "\(daysOnTarget)", color: AppColors.protein)
                StatTile(icon: "fork.knife", label: "Total Entries", value: "\(totalEntries)", color: AppColors.fat)
            }
        }
        .padding(14)
        .kitchenReceiptSurface(accent: KitchenTablePalette.brass)
    }
}

struct StatTile: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))

            Text(LocalizedDisplayText.text(label))
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(NeoAppColors.subtleSurface.opacity(0.55), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .stroke(color.opacity(0.48), style: StrokeStyle(lineWidth: 0.8, dash: [3, 2]))
        }
    }
}

struct StatBadge: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.subheadline, design: .serif, weight: .bold))
                .foregroundStyle(NeoAppColors.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(LocalizedDisplayText.text(label))
                .font(.system(.caption2, design: .monospaced, weight: .bold))
                .textCase(.uppercase)
                .foregroundStyle(NeoAppColors.mutedInk)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .background(NeoAppColors.subtleSurface.opacity(0.45), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(
                    KitchenTablePalette.rule,
                    style: StrokeStyle(lineWidth: NeoAppMetrics.compactRule, dash: [3, 2])
                )
        }
    }
}

// MARK: - Log Weight Sheet

struct LogWeightSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("weightUnit") private var weightUnitRaw = "lbs"
    let currentWeightKg: Double
    let onSave: (Double) -> Void

    @State private var wholeNumber: Int
    @State private var decimal: Int

    init(currentWeightKg: Double, onSave: @escaping (Double) -> Void) {
        self.currentWeightKg = currentWeightKg
        self.onSave = onSave
        // Respect @AppStorage at the time the sheet is created.
        let metric = UserDefaults.standard.string(forKey: "weightUnit") == "kg"
        let displayValue = metric ? currentWeightKg : currentWeightKg * 2.20462
        let whole = Int(displayValue)
        let dec = min(9, max(0, Int((displayValue - Double(whole)) * 10 + 0.5)))
        _wholeNumber = State(initialValue: whole)
        _decimal = State(initialValue: dec)
    }

    private var useMetric: Bool { weightUnitRaw == "kg" }

    private var selectedValue: Double {
        Double(wholeNumber) + Double(decimal) / 10.0
    }

    private var selectedKg: Double {
        useMetric ? selectedValue : selectedValue / 2.20462
    }

    private var unit: String { useMetric ? "kg" : "lbs" }
    private var wholeRange: ClosedRange<Int> { useMetric ? 20...250 : 50...500 }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Log Weight")
                    .font(.system(.title2, design: .rounded, weight: .black).width(.condensed))
                    .textCase(.uppercase)
                    .foregroundStyle(NeoAppColors.ink)

                Picker("Unit", selection: $weightUnitRaw) {
                    Text("kg").tag("kg")
                    Text("lbs").tag("lbs")
                }
                .pickerStyle(.segmented)
                .tint(NeoAppColors.cobalt)
                .padding(.horizontal, 24)
                .onChange(of: weightUnitRaw) { _, newValue in
                    // Convert the currently selected value so toggling mid-edit keeps it,
                    // clamped into the destination wheel's rows (20...250 kg / 50...500 lbs)
                    // so the selection never lands on a tag the wheel doesn't offer.
                    let value = Double(wholeNumber) + Double(decimal) / 10.0
                    let converted = newValue == "kg" ? value / 2.20462 : value * 2.20462
                    let bounds = newValue == "kg" ? 20.0...250.0 : 50.0...500.0
                    let clamped = min(bounds.upperBound, max(bounds.lowerBound, converted))
                    let whole = Int(clamped)
                    wholeNumber = whole
                    decimal = min(9, max(0, Int((clamped - Double(whole)) * 10 + 0.5)))
                }

                // Scroll wheel pickers
                HStack(spacing: 0) {
                    Picker("Whole", selection: $wholeNumber) {
                        ForEach(wholeRange, id: \.self) { num in
                            Text("\(num)").tag(num)
                                .font(.system(.title2, design: .rounded, weight: .medium))
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 100)
                    .clipped()

                    Text(".")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .offset(y: -1)

                    Picker("Decimal", selection: $decimal) {
                        ForEach(0...9, id: \.self) { num in
                            Text("\(num)").tag(num)
                                .font(.system(.title2, design: .rounded, weight: .medium))
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 70)
                    .clipped()

                    Text(unit)
                        .font(.system(.title3, design: .rounded))
                        .foregroundStyle(NeoAppColors.mutedInk)
                        .padding(.leading, 4)
                }

                Button {
                    onSave(selectedKg)
                    dismiss()
                } label: {
                    Text("Save")
                        .font(.system(.headline, design: .rounded, weight: .black).width(.condensed))
                        .textCase(.uppercase)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(NeoAppColors.cobalt)
                        .foregroundStyle(NeoAppColors.onCobalt)
                        .overlay {
                            Rectangle().stroke(NeoAppColors.ink, lineWidth: NeoAppMetrics.rule)
                        }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)

                Spacer()
            }
            .padding(.top, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(NeoAppColors.canvas)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(NeoAppColors.cobalt)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Weight History Link (tap to open full list)

struct WeightHistoryLink: View {
    let totalCount: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "list.bullet.rectangle")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(NeoAppColors.onCobalt)
                    .frame(width: 28, height: 28)
                    .background(NeoAppColors.cobalt, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(NeoAppColors.cobaltDeep, lineWidth: NeoAppMetrics.compactRule)
                    }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Weight History")
                        .font(.system(.body, design: .serif, weight: .bold))
                        .foregroundStyle(NeoAppColors.ink)
                    Text("\(totalCount) \(totalCount == 1 ? "entry" : "entries") · tap to view or delete")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(NeoAppColors.mutedInk)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(NeoAppColors.cobalt)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .kitchenReceiptSurface(accent: KitchenTablePalette.cobalt)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - All Weight History (full-screen sheet)

struct AllWeightHistoryView: View {
    let entries: [WeightEntry]
    let useMetric: Bool
    let onDelete: (WeightEntry) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var pendingDeletion: WeightEntry?
    // Local mirror so the list updates immediately after deletion without needing the parent to re-bind.
    @State private var visibleEntries: [WeightEntry] = []

    var body: some View {
        NavigationStack {
            List {
                ForEach(visibleEntries) { entry in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(displayWeight(entry.weightKg, useMetric: useMetric))
                                .font(.system(.body, design: .rounded, weight: .black).width(.condensed))
                                .foregroundStyle(NeoAppColors.ink)
                            Text(weightHistoryFormatter.string(from: entry.date))
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(NeoAppColors.mutedInk)
                        }
                        Spacer()
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            pendingDeletion = entry
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .neoListRow()
                }
            }
            .listStyle(.plain)
            .neoScreen()
            .navigationTitle("Weight History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(NeoAppColors.surface, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(NeoAppColors.cobalt)
                }
            }
        }
        .onAppear { visibleEntries = entries }
        .alert("Delete Weight Entry", isPresented: Binding(
            get: { pendingDeletion != nil },
            set: { if !$0 { pendingDeletion = nil } }
        )) {
            Button("Cancel", role: .cancel) { pendingDeletion = nil }
            Button("Delete", role: .destructive) {
                if let entry = pendingDeletion {
                    visibleEntries.removeAll { $0.id == entry.id }
                    onDelete(entry)
                }
                pendingDeletion = nil
            }
        } message: {
            if let entry = pendingDeletion {
                Text("Remove \(weightHistoryFormatter.string(from: entry.date))'s entry of \(displayWeight(entry.weightKg, useMetric: useMetric))? This also deletes the matching sample from Apple Health.")
            }
        }
    }
}

private let weightHistoryFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .medium
    f.timeStyle = .none
    return f
}()

private func displayWeight(_ kg: Double, useMetric: Bool) -> String {
    if useMetric {
        return String(format: "%.1f kg", kg)
    }
    let lbs = kg * 2.20462
    return String(format: "%.1f lb", lbs)
}

// MARK: - Body Fat History (link + full list, mirroring Weight History)

struct BodyFatHistoryLink: View {
    let totalCount: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "list.bullet.rectangle")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.black)
                    .frame(width: 28, height: 28)
                    .background(NeoAppColors.acid, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(KitchenTablePalette.brassDeep, lineWidth: NeoAppMetrics.compactRule)
                    }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Body Fat History")
                        .font(.system(.body, design: .serif, weight: .bold))
                        .foregroundStyle(NeoAppColors.ink)
                    Text("\(totalCount) \(totalCount == 1 ? "entry" : "entries") · tap to view or delete")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(NeoAppColors.mutedInk)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(NeoAppColors.cobalt)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .kitchenReceiptSurface(accent: KitchenTablePalette.brass)
        }
        .buttonStyle(.plain)
    }
}

struct AllBodyFatHistoryView: View {
    let entries: [BodyFatEntry]
    let onDelete: (BodyFatEntry) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var pendingDeletion: BodyFatEntry?
    // Local mirror so the list updates immediately after deletion without needing the parent to re-bind.
    @State private var visibleEntries: [BodyFatEntry] = []

    var body: some View {
        NavigationStack {
            List {
                ForEach(visibleEntries) { entry in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(displayBodyFat(entry.bodyFatFraction))
                                .font(.system(.body, design: .rounded, weight: .black).width(.condensed))
                                .foregroundStyle(NeoAppColors.ink)
                            Text(weightHistoryFormatter.string(from: entry.date))
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(NeoAppColors.mutedInk)
                        }
                        Spacer()
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            pendingDeletion = entry
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .neoListRow()
                }
            }
            .listStyle(.plain)
            .neoScreen()
            .navigationTitle("Body Fat History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(NeoAppColors.surface, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(NeoAppColors.cobalt)
                }
            }
        }
        .onAppear { visibleEntries = entries }
        .alert("Delete Body Fat Entry", isPresented: Binding(
            get: { pendingDeletion != nil },
            set: { if !$0 { pendingDeletion = nil } }
        )) {
            Button("Cancel", role: .cancel) { pendingDeletion = nil }
            Button("Delete", role: .destructive) {
                if let entry = pendingDeletion {
                    visibleEntries.removeAll { $0.id == entry.id }
                    onDelete(entry)
                }
                pendingDeletion = nil
            }
        } message: {
            if let entry = pendingDeletion {
                Text("Remove \(weightHistoryFormatter.string(from: entry.date))'s entry of \(displayBodyFat(entry.bodyFatFraction))? This also deletes the matching sample from Apple Health.")
            }
        }
    }
}

private func displayBodyFat(_ fraction: Double) -> String {
    String(format: "%.1f%%", fraction * 100)
}

// MARK: - Body Metrics Section (Weight / Body Fat toggle)

enum BodyMetric: String, CaseIterable, Identifiable {
    case weight, bodyFat
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .weight: LocalizedDisplayText.text("Weight", polish: "Waga")
        case .bodyFat: LocalizedDisplayText.text("Body Fat", polish: "Tkanka tłuszczowa")
        }
    }
}

/// Single card with a segmented Weight / Body Fat toggle at the top and the
/// matching chart below — replaces the two stacked cards. The toggle is only
/// rendered when both metrics are available; users without body-fat data see
/// the bare WeightChartSection (no toggle, identical to the v3.1 layout) so
/// nothing changes for users who never opted into body-fat tracking.
struct BodyMetricsSection: View {
    let weightEntries: [WeightEntry]
    let goalWeightKg: Double?
    let currentWeightKg: Double?
    let onLogWeight: () -> Void

    let bodyFatEntries: [BodyFatEntry]
    let goalBodyFatFraction: Double?
    let currentBodyFatFraction: Double?
    let onLogBodyFat: () -> Void

    /// True when the user has opted into body-fat tracking — drives whether
    /// the segmented toggle renders at all.
    let bodyFatAvailable: Bool

    @State private var metric: BodyMetric = .weight

    var body: some View {
        VStack(spacing: 12) {
            if bodyFatAvailable {
                Picker("Metric", selection: $metric.animation(.snappy)) {
                    ForEach(BodyMetric.allCases) { m in
                        Text(m.displayName).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .tint(NeoAppColors.cobalt)
            }

            // Render the active metric. Both children carry their own card
            // background, so the parent VStack just stacks them naturally.
            switch metric {
            case .weight:
                WeightChartSection(
                    weightEntries: weightEntries,
                    goalWeightKg: goalWeightKg,
                    currentWeightKg: currentWeightKg,
                    onLogWeight: onLogWeight
                )
                // Swipe right to flip to Body Fat (only when available).
                .gesture(
                    bodyFatAvailable
                        ? DragGesture(minimumDistance: 30)
                            .onEnded { value in
                                if value.translation.width < -50 {
                                    withAnimation(.snappy) { metric = .bodyFat }
                                }
                            }
                        : nil
                )
            case .bodyFat:
                BodyFatChartSection(
                    entries: bodyFatEntries,
                    goalBodyFatFraction: goalBodyFatFraction,
                    currentBodyFatFraction: currentBodyFatFraction,
                    onLogBodyFat: onLogBodyFat
                )
                // Swipe left to flip back to Weight.
                .gesture(
                    DragGesture(minimumDistance: 30)
                        .onEnded { value in
                            if value.translation.width > 50 {
                                withAnimation(.snappy) { metric = .weight }
                            }
                        }
                )
            }
        }
    }
}

// MARK: - Body Fat Chart Section

/// Visual twin of WeightChartSection for body-fat % readings. Goal line is
/// drawn as a dashed RuleMark in green if `goalBodyFatFraction` is set. The
/// goal value is purely visual — it never enters BMR / TDEE / macro math.
struct BodyFatChartSection: View {
    let entries: [BodyFatEntry]
    let goalBodyFatFraction: Double?
    let currentBodyFatFraction: Double?
    let onLogBodyFat: () -> Void

    private func displayPercent(_ fraction: Double) -> Double {
        fraction * 100
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Body Fat")
                    .font(.system(.title3, design: .serif, weight: .bold))
                    .foregroundStyle(NeoAppColors.ink)
                Spacer()
                Button(action: onLogBodyFat) {
                    Label("Log Body Fat", systemImage: "plus.circle.fill")
                        .font(.system(.caption, design: .monospaced, weight: .bold))
                        .textCase(.uppercase)
                        .foregroundStyle(KitchenTablePalette.tomatoDeep)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 7)
                        .background(KitchenTablePalette.paper)
                        .overlay {
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .stroke(
                                    KitchenTablePalette.tomato,
                                    style: StrokeStyle(lineWidth: 0.9, dash: [3, 2])
                                )
                        }
                }
                .buttonStyle(.plain)
            }

            if entries.isEmpty {
                emptyState("Log your first body fat % to see trends")
            } else {
                HStack(spacing: 8) {
                    if let current = currentBodyFatFraction {
                        StatBadge(label: "Current", value: String(format: "%.1f%%", displayPercent(current)))
                    }
                    if let goal = goalBodyFatFraction {
                        StatBadge(label: "Goal", value: String(format: "%.1f%%", displayPercent(goal)))
                    }
                    StatBadge(label: "Net Change", value: formattedBodyFatChange)
                    StatBadge(label: "Average", value: formattedAverageBodyFat)
                }

                Chart {
                    ForEach(plottedPoints) { point in
                        LineMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("Body Fat", point.value)
                        )
                        .foregroundStyle(NeoAppColors.cobalt)
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2))

                        if showsPointMarks {
                            PointMark(
                                x: .value("Date", point.date, unit: .day),
                                y: .value("Body Fat", point.value)
                            )
                            .foregroundStyle(NeoAppColors.cobalt)
                            .symbolSize(30)
                        }
                    }

                    if let goalFraction = goalBodyFatFraction {
                        RuleMark(y: .value("Goal", displayPercent(goalFraction)))
                            .foregroundStyle(NeoAppColors.success.opacity(0.9))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    }
                }
                .chartYScale(domain: bodyFatYDomain)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: xAxis.strideDays)) { _ in
                        AxisGridLine().foregroundStyle(KitchenTablePalette.rule)
                        AxisValueLabel(format: xAxis.labelFormat)
                    }
                }
                .chartPlotStyle { plotArea in
                    plotArea
                        .background(KitchenTablePalette.paperMuted.opacity(0.26))
                        .background(KitchenGraphPaper())
                }
                .frame(height: 158)
                .clipped()
            }
        }
        .padding(14)
        .kitchenReceiptSurface(accent: KitchenTablePalette.cobalt)
    }

    /// Same plotting policy as WeightChartSection — raw entries for short
    /// ranges, bucket averages once the series gets dense, dots only while
    /// each reading is distinguishable.
    private var plottedPoints: [TrendPoint] {
        downsampled(sortedEntries.map { TrendPoint(date: $0.date, value: displayPercent($0.bodyFatFraction)) })
    }

    private var showsPointMarks: Bool { plottedPoints.count <= 31 }

    private var xAxis: TrendXAxis {
        TrendXAxis(first: sortedEntries.first?.date, last: sortedEntries.last?.date)
    }

    private var bodyFatYDomain: ClosedRange<Double> {
        var values = entries.map { displayPercent($0.bodyFatFraction) }
        if let goal = goalBodyFatFraction { values.append(displayPercent(goal)) }
        guard let minV = values.min(), let maxV = values.max() else { return 0...60 }
        let padding = max((maxV - minV) * 0.15, 1)
        return max(0, minV - padding)...(maxV + padding)
    }

    private var sortedEntries: [BodyFatEntry] {
        entries.sorted { $0.date < $1.date }
    }

    private var netBodyFatChange: Double {
        guard let first = sortedEntries.first,
              let last = sortedEntries.last else { return 0 }
        return displayPercent(last.bodyFatFraction) - displayPercent(first.bodyFatFraction)
    }

    private var averageBodyFat: Double {
        let values = sortedEntries.map { displayPercent($0.bodyFatFraction) }
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private var formattedBodyFatChange: String {
        let sign = netBodyFatChange > 0 ? "+" : ""
        return String(format: "%@%.1f%%", sign, netBodyFatChange)
    }

    private var formattedAverageBodyFat: String {
        String(format: "%.1f%%", averageBodyFat)
    }
}

// MARK: - Log Body Fat Sheet

/// Single-wheel picker for body-fat %. Whole-number precision (matches
/// BodyFatPickerSheet in Settings) — body-fat measurements rarely justify
/// 0.1% resolution given the noise of calipers / smart scales.
struct LogBodyFatSheet: View {
    @Environment(\.dismiss) private var dismiss
    let currentFraction: Double
    let onSave: (Double) -> Void

    @State private var percentage: Int

    init(currentFraction: Double, onSave: @escaping (Double) -> Void) {
        self.currentFraction = currentFraction
        self.onSave = onSave
        _percentage = State(initialValue: Int(currentFraction * 100))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Log Body Fat")
                    .font(.system(.title2, design: .rounded, weight: .black).width(.condensed))
                    .textCase(.uppercase)
                    .foregroundStyle(NeoAppColors.ink)

                HStack(spacing: 0) {
                    Picker("Percentage", selection: $percentage) {
                        ForEach(3...60, id: \.self) { n in
                            Text("\(n)").tag(n)
                                .font(.system(.title2, design: .rounded, weight: .medium))
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 100)
                    .clipped()

                    Text("%")
                        .font(.system(.title3, design: .rounded))
                        .foregroundStyle(NeoAppColors.mutedInk)
                        .padding(.leading, 4)
                }

                Button {
                    onSave(Double(percentage) / 100.0)
                    dismiss()
                } label: {
                    Text("Save")
                        .font(.system(.headline, design: .rounded, weight: .black).width(.condensed))
                        .textCase(.uppercase)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(NeoAppColors.cobalt)
                        .foregroundStyle(NeoAppColors.onCobalt)
                        .overlay {
                            Rectangle().stroke(NeoAppColors.ink, lineWidth: NeoAppMetrics.rule)
                        }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)

                Spacer()
            }
            .padding(.top, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(NeoAppColors.canvas)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(NeoAppColors.cobalt)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Helpers

private func emptyState(_ message: String) -> some View {
    VStack(spacing: 8) {
        Image(systemName: "chart.line.uptrend.xyaxis")
            .font(.system(size: 18, weight: .medium))
            .foregroundStyle(KitchenTablePalette.cobalt)
        Text(message)
            .font(.system(.subheadline, design: .serif, weight: .semibold))
            .foregroundStyle(NeoAppColors.mutedInk)
    }
    .frame(maxWidth: .infinity, minHeight: 76)
    .background(KitchenGraphPaper())
    .overlay {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .stroke(
                KitchenTablePalette.rule,
                style: StrokeStyle(lineWidth: NeoAppMetrics.compactRule, dash: [3, 2])
            )
    }
}

// MARK: - Body Measurements

/// cm → display string in the user's unit ("92.0 cm" / "36.2 in").
private func displayLength(_ cm: Double, useMetric: Bool) -> String {
    useMetric ? String(format: "%.1f cm", cm) : String(format: "%.1f in", cm / 2.54)
}

/// The logged sites in display order, skipping any that weren't entered.
private func measurementSites(_ m: BodyMeasurement) -> [(label: String, cm: Double)] {
    var rows: [(String, Double)] = []
    func add(_ label: String, _ value: Double?) { if let value { rows.append((label, value)) } }
    add("Neck", m.neckCm)
    add("Waist", m.waistCm)
    add("Hips", m.hipsCm)
    add("Chest", m.chestCm)
    add("Upper arm", m.upperArmCm)
    add("Thigh", m.thighCm)
    add("Calf", m.calfCm)
    add("Wrist", m.wristCm)
    return rows
}

/// The four derived metrics that can be computed from `m` + the profile, skipping any that can't.
private func derivedMetricChips(_ m: BodyMeasurement, gender: Gender, heightCm: Double) -> [(label: String, value: String)] {
    var chips: [(String, String)] = []
    if let whr = m.waistToHipRatio {
        chips.append(("Waist-to-hip", String(format: "%.2f", whr)))
    }
    if let whtr = m.waistToHeightRatio(heightCm: heightCm) {
        chips.append(("Waist-to-height", String(format: "%.2f", whtr)))
    }
    if let bf = m.usNavyBodyFatPercent(gender: gender, heightCm: heightCm) {
        chips.append(("Body fat (Navy)", String(format: "%.0f%%", bf)))
    }
    if let frame = m.wristFrame(gender: gender, heightCm: heightCm) {
        chips.append(("Frame", frame.label))
    }
    return chips
}

/// Settings → Personal Info detail screen. Mirrors the Other Nutrients screen: a tappable row per
/// body part that opens a wheel picker to set its value, plus the AI-derived metrics and history.
/// Lives in Settings (not Progress) so it sits with the other body inputs.
struct BodyMeasurementsDetailView: View {
    @Environment(BodyMeasurementStore.self) private var store
    @AppStorage("heightUnit") private var heightUnitRaw = "ftin"
    let gender: Gender
    let heightCm: Double

    private var useMetric: Bool { heightUnitRaw == "cm" }

    @State private var editingSite: BodyMeasurement.Site?
    @State private var showHistory = false

    private var latest: BodyMeasurement? { store.latestEntry }
    private var unit: String { useMetric ? "cm" : "in" }

    private func displayValue(_ site: BodyMeasurement.Site) -> String {
        guard let cm = latest?.value(for: site) else { return "Not set" }
        return useMetric ? String(format: "%.0f cm", cm) : String(format: "%.0f in", cm / 2.54)
    }

    var body: some View {
        List {
            Section {
                ForEach(BodyMeasurement.Site.allCases) { site in
                    Button {
                        editingSite = site
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "ruler")
                                .foregroundStyle(NeoAppColors.cobalt)
                                .frame(width: 22)
                            Text(site.label)
                                .font(.system(.body, design: .rounded, weight: .bold))
                                .foregroundStyle(NeoAppColors.ink)
                            Spacer()
                            Text(displayValue(site))
                                .foregroundStyle(NeoAppColors.mutedInk)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(NeoAppColors.cobalt)
                        }
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("Measurements")
            } footer: {
                Text("Optional. Fud AI turns these into waist-to-hip, waist-to-height, body-fat %, and frame size, and reads them when it recalculates your goals and in Coach.")
            }
            .neoListRow()

            if let latest {
                let chips = derivedMetricChips(latest, gender: gender, heightCm: heightCm)
                if !chips.isEmpty {
                    Section("Derived") {
                        ForEach(chips, id: \.label) { chip in
                            HStack {
                                Text(chip.label)
                                Spacer()
                                Text(chip.value)
                                    .foregroundStyle(NeoAppColors.cobalt)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                    .neoListRow()
                }
            }

            if store.entries.count > 1 {
                Section {
                    Button {
                        showHistory = true
                    } label: {
                        HStack {
                            Text("Measurement History")
                                .font(.system(.body, design: .rounded, weight: .bold))
                                .foregroundStyle(NeoAppColors.ink)
                            Spacer()
                            Text("\(store.entries.count)")
                                .foregroundStyle(NeoAppColors.mutedInk)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(NeoAppColors.cobalt)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .neoListRow()
            }
        }
        .listStyle(.plain)
        .neoScreen()
        .navigationTitle("Body Measurements")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(NeoAppColors.surface, for: .navigationBar)
        .sheet(item: $editingSite) { site in
            MeasurementEditSheet(
                site: site,
                currentCm: latest?.value(for: site),
                onSave: { cm in store.setValue(site, cm: cm) },
                onClear: { store.setValue(site, cm: nil) }
            )
        }
        .sheet(isPresented: $showHistory) {
            AllBodyMeasurementsHistoryView(
                entries: store.sortedEntries,
                gender: gender,
                heightCm: heightCm,
                useMetric: useMetric,
                onDelete: { entry in store.deleteEntry(entry) }
            )
        }
    }
}

/// Editor for one measurement site. The cm|in switcher persists the shared
/// length standard (same pref as the Height editor), and — matching the
/// height/weight editors — flipping it converts the value currently on the
/// wheel (clamped into the destination wheel's rows) instead of re-seeding.
private struct MeasurementEditSheet: View {
    let site: BodyMeasurement.Site
    let hasCurrent: Bool
    let onSave: (Double) -> Void
    let onClear: () -> Void

    @AppStorage("heightUnit") private var heightUnitRaw = "ftin"
    @State private var displayValue: Int

    init(
        site: BodyMeasurement.Site,
        currentCm: Double?,
        onSave: @escaping (Double) -> Void,
        onClear: @escaping () -> Void
    ) {
        self.site = site
        self.hasCurrent = currentCm != nil
        self.onSave = onSave
        self.onClear = onClear
        let metric = UserDefaults.standard.string(forKey: "heightUnit") == "cm"
        let seed = currentCm.map { metric ? Int($0.rounded()) : Int(($0 / 2.54).rounded()) } ?? (metric ? 80 : 32)
        _displayValue = State(initialValue: seed)
    }

    private var useMetric: Bool { heightUnitRaw == "cm" }

    // Converts in the binding's setter so the new unit and the converted value
    // land in the same update — the re-keyed wheel below then seeds correctly.
    private var unitSelection: Binding<String> {
        Binding(
            get: { heightUnitRaw },
            set: { newValue in
                guard newValue != heightUnitRaw else { return }
                if newValue == "cm" {
                    displayValue = min(250, max(10, Int((Double(displayValue) * 2.54).rounded())))
                } else {
                    displayValue = min(100, max(4, Int((Double(displayValue) / 2.54).rounded())))
                }
                heightUnitRaw = newValue
            }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Unit", selection: unitSelection) {
                Text("cm").tag("cm")
                Text("in").tag("ftin")
            }
            .pickerStyle(.segmented)
            .tint(NeoAppColors.cobalt)
            .padding(.horizontal, 24)
            .padding(.top, 20)

            NutritionPickerSheet(
                label: site.label,
                unit: useMetric ? "cm" : "in",
                currentValue: displayValue,
                range: useMetric ? 10...250 : 4...100,
                step: 1,
                onSave: { value in onSave(useMetric ? Double(value) : Double(value) * 2.54) },
                onResetToAuto: hasCurrent ? onClear : nil,
                resetLabel: "Clear",
                onValueChange: { displayValue = $0 }
            )
            // Re-key so a unit flip rebuilds the wheel seeded with the value
            // converted above (its selection state is set once, in init).
            .id(heightUnitRaw)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(NeoAppColors.canvas)
    }
}

/// Full history with swipe-to-delete, mirroring AllWeightHistoryView.
struct AllBodyMeasurementsHistoryView: View {
    let entries: [BodyMeasurement]
    let gender: Gender
    let heightCm: Double
    let useMetric: Bool
    let onDelete: (BodyMeasurement) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var pendingDeletion: BodyMeasurement?
    @State private var visibleEntries: [BodyMeasurement] = []

    var body: some View {
        NavigationStack {
            List {
                ForEach(visibleEntries) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(weightHistoryFormatter.string(from: entry.date))
                            .font(.system(.subheadline, design: .rounded, weight: .black).width(.condensed))
                            .foregroundStyle(NeoAppColors.ink)
                        Text(summary(entry))
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(NeoAppColors.mutedInk)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            pendingDeletion = entry
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .neoListRow()
                }
            }
            .listStyle(.plain)
            .neoScreen()
            .navigationTitle("Measurement History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(NeoAppColors.surface, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(NeoAppColors.cobalt)
                }
            }
        }
        .onAppear { visibleEntries = entries }
        .alert("Delete Measurement", isPresented: Binding(
            get: { pendingDeletion != nil },
            set: { if !$0 { pendingDeletion = nil } }
        )) {
            Button("Cancel", role: .cancel) { pendingDeletion = nil }
            Button("Delete", role: .destructive) {
                if let entry = pendingDeletion {
                    visibleEntries.removeAll { $0.id == entry.id }
                    onDelete(entry)
                }
                pendingDeletion = nil
            }
        } message: {
            if let entry = pendingDeletion {
                Text("Remove \(weightHistoryFormatter.string(from: entry.date))'s measurements?")
            }
        }
    }

    private func summary(_ m: BodyMeasurement) -> String {
        let sites = measurementSites(m).map { "\($0.label) \(displayLength($0.cm, useMetric: useMetric))" }
        if let bf = m.usNavyBodyFatPercent(gender: gender, heightCm: heightCm) {
            return (sites + [String(format: "BF %.0f%%", bf)]).joined(separator: " · ")
        }
        return sites.joined(separator: " · ")
    }
}
