import Foundation

/// Output format for a food-diary export.
enum DiaryExportFormat: String, CaseIterable, Identifiable {
    case json, markdown, csv
    var id: String { rawValue }
    var label: String {
        switch self {
        case .json: return "JSON"
        case .markdown: return "Markdown"
        case .csv: return "CSV"
        }
    }
    var fileExtension: String {
        switch self {
        case .json: return "json"
        case .markdown: return "md"
        case .csv: return "csv"
        }
    }
}

/// Date-range presets for an export.
enum DiaryExportRange: String, CaseIterable, Identifiable {
    case today, thisWeek, thisMonth, allTime, custom
    var id: String { rawValue }
    var label: String {
        switch self {
        case .today: return "Today"
        case .thisWeek: return "This week"
        case .thisMonth: return "This month"
        case .allTime: return "All time"
        case .custom: return "Custom"
        }
    }
}

/// Builds a shareable food-diary file (JSON / Markdown / CSV) from the local log.
/// Pure logic — no UI. Everything comes from the already-loaded FoodStore + profile.
enum DiaryExporter {

    // MARK: - Public entry point

    /// Returns (filename, data) for the given inclusive day range, or nil if there is
    /// nothing logged in that range.
    static func build(
        from startDay: Date,
        to endDay: Date,
        format: DiaryExportFormat,
        foodStore: FoodStore,
        profile: UserProfile
    ) -> (filename: String, data: Data)? {
        let cal = Calendar.current
        let start = cal.startOfDay(for: min(startDay, endDay))
        let end = cal.startOfDay(for: max(startDay, endDay))

        var days: [DayBundle] = []
        var day = start
        while day <= end {
            let entries = foodStore.entries(for: day)
            if !entries.isEmpty {
                days.append(DayBundle(date: day, groups: foodStore.entriesByMeal(for: day)))
            }
            guard let next = cal.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        guard !days.isEmpty else { return nil }

        let targets = Targets(
            calories: profile.effectiveCalories,
            protein: Double(profile.effectiveProtein),
            carbs: Double(profile.effectiveCarbs),
            fat: Double(profile.effectiveFat)
        )

        let text: String
        switch format {
        case .json: text = json(days, start: start, end: end, targets: targets)
        case .markdown: text = markdown(days, start: start, end: end, targets: targets)
        case .csv: text = csv(days)
        }

        let name = "Fud-Food-Diary-\(dayFmt.string(from: start))_to_\(dayFmt.string(from: end)).\(format.fileExtension)"
        return (name, Data(text.utf8))
    }

    // MARK: - Range resolution

    /// Resolves a preset (or custom bounds) into an inclusive (startDay, endDay).
    static func resolve(_ range: DiaryExportRange, customStart: Date, customEnd: Date, foodStore: FoodStore) -> (Date, Date) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        switch range {
        case .today:
            return (today, today)
        case .thisWeek:
            let start = cal.dateInterval(of: .weekOfYear, for: today)?.start ?? today
            return (start, today)
        case .thisMonth:
            let start = cal.dateInterval(of: .month, for: today)?.start ?? today
            return (start, today)
        case .allTime:
            let earliest = foodStore.entries.map(\.timestamp).min().map { cal.startOfDay(for: $0) } ?? today
            return (earliest, today)
        case .custom:
            return (cal.startOfDay(for: customStart), cal.startOfDay(for: customEnd))
        }
    }

    // MARK: - Internal shapes

    private struct DayBundle { let date: Date; let groups: [FoodLogMealGroup] }
    private struct Targets { let calories: Int; let protein: Double; let carbs: Double; let fat: Double }

    private static func totals(_ groups: [FoodLogMealGroup]) -> (cal: Int, p: Double, c: Double, f: Double) {
        var cal = 0; var p = 0.0; var c = 0.0; var f = 0.0
        for g in groups { for e in g.entries { cal += e.calories; p += e.protein; c += e.carbs; f += e.fat } }
        return (cal, p, c, f)
    }

    static func sourceLabel(_ source: FoodSource) -> String {
        source == .manual ? "manually_edited" : "ai_estimated"
    }

    private nonisolated static func r1(_ x: Double) -> Double { (x * 10).rounded() / 10 }

    private static let dayFmt: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"; return f
    }()
    private static let timeFmt: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "HH:mm"; return f
    }()

    // MARK: - JSON

    private static func json(_ days: [DayBundle], start: Date, end: Date, targets: Targets) -> String {
        struct Macro: Encodable { let calories: Int; let protein_g: Double; let carbs_g: Double; let fat_g: Double }
        struct Item: Encodable {
            let name: String; let quantity_g: Double?; let calories: Int
            let protein_g: Double; let carbs_g: Double; let fat_g: Double
            let time: String; let source: String; let note: String?
        }
        struct Meal: Encodable { let type: String; let items: [Item] }
        struct Day: Encodable { let date: String; let totals: Macro; let targets: Macro; let remaining: Macro; let meals: [Meal] }
        struct Meta: Encodable { struct Range: Encodable { let start: String; let end: String }
            let app: String; let format_version: String; let date_range: Range }
        struct Doc: Encodable { let export: Meta; let days: [Day] }

        let dayDocs: [Day] = days.map { bundle in
            let t = totals(bundle.groups)
            let meals: [Meal] = bundle.groups.map { g in
                Meal(type: g.meal.rawValue, items: g.entries.map { e in
                    Item(name: e.name, quantity_g: e.servingSizeGrams.map(r1), calories: e.calories,
                         protein_g: r1(e.protein), carbs_g: r1(e.carbs), fat_g: r1(e.fat),
                         time: timeFmt.string(from: e.timestamp), source: sourceLabel(e.source),
                         note: (e.customNote?.isEmpty == false) ? e.customNote : nil)
                })
            }
            return Day(
                date: dayFmt.string(from: bundle.date),
                totals: Macro(calories: t.cal, protein_g: r1(t.p), carbs_g: r1(t.c), fat_g: r1(t.f)),
                targets: Macro(calories: targets.calories, protein_g: targets.protein, carbs_g: targets.carbs, fat_g: targets.fat),
                remaining: Macro(calories: max(0, targets.calories - t.cal),
                                 protein_g: r1(max(0, targets.protein - t.p)),
                                 carbs_g: r1(max(0, targets.carbs - t.c)),
                                 fat_g: r1(max(0, targets.fat - t.f))),
                meals: meals
            )
        }
        let doc = Doc(export: Meta(app: "Fud AI", format_version: "1.0",
                                   date_range: Meta.Range(start: dayFmt.string(from: start), end: dayFmt.string(from: end))),
                      days: dayDocs)
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        return (try? enc.encode(doc)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
    }

    // MARK: - Markdown

    private static func markdown(_ days: [DayBundle], start: Date, end: Date, targets: Targets) -> String {
        var s = "# Food diary export\n"
        s += "Date range: \(dayFmt.string(from: start)) to \(dayFmt.string(from: end))\n"
        s += "Generated by Fud AI\n"
        for bundle in days {
            let t = totals(bundle.groups)
            s += "\n## \(dayFmt.string(from: bundle.date))\n"
            s += "Totals:\n"
            s += "- Calories: \(t.cal) / \(targets.calories) kcal\n"
            s += "- Protein: \(r1(t.p)) / \(Int(targets.protein)) g\n"
            s += "- Carbs: \(r1(t.c)) / \(Int(targets.carbs)) g\n"
            s += "- Fat: \(r1(t.f)) / \(Int(targets.fat)) g\n"
            for g in bundle.groups {
                s += "### \(g.meal.displayName)\n"
                s += "| Time | Food | Weight | Calories | Protein | Carbs | Fat | Source |\n"
                s += "|---|---|---:|---:|---:|---:|---:|---|\n"
                for e in g.entries {
                    let weight = e.servingSizeGrams.map { "\(Int($0)) g" } ?? "-"
                    let food = e.name.replacingOccurrences(of: "|", with: "/")
                    let cells: [String] = [
                        timeFmt.string(from: e.timestamp), food, weight,
                        String(e.calories), "\(r1(e.protein)) g", "\(r1(e.carbs)) g",
                        "\(r1(e.fat)) g", sourceLabel(e.source)
                    ]
                    s += "| " + cells.joined(separator: " | ") + " |\n"
                }
            }
        }
        return s
    }

    // MARK: - CSV

    private static func csv(_ days: [DayBundle]) -> String {
        var s = "date,meal,time,food,weight_g,calories,protein_g,carbs_g,fat_g,source,note\n"
        for bundle in days {
            let date = dayFmt.string(from: bundle.date)
            for g in bundle.groups {
                for e in g.entries {
                    let cols: [String] = [
                        date, g.meal.rawValue, timeFmt.string(from: e.timestamp), e.name,
                        e.servingSizeGrams.map { String(Int($0)) } ?? "",
                        String(e.calories), String(r1(e.protein)), String(r1(e.carbs)), String(r1(e.fat)),
                        sourceLabel(e.source), e.customNote ?? ""
                    ]
                    s += cols.map(csvEscape).joined(separator: ",") + "\n"
                }
            }
        }
        return s
    }

    private nonisolated static func csvEscape(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return field
    }
}
