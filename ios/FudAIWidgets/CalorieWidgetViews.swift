import SwiftUI
import WidgetKit

/// Match the main app's pink/red theme without importing Theme.swift
/// (which lives in the main app target).
enum WidgetPalette {
    static let calorie = Color(red: 0xFF / 255, green: 0x37 / 255, blue: 0x5F / 255)
    static let calorieLight = Color(red: 0xFF / 255, green: 0x6B / 255, blue: 0x8A / 255)
    static var calorieGradient: LinearGradient {
        LinearGradient(colors: [calorie, calorieLight], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static var background: some ShapeStyle {
        Color(.systemBackground)
    }
}

/// Top-level dispatcher — WidgetKit gives us an `Environment(\.widgetFamily)`.
struct CalorieWidgetView: View {
    let entry: CalorieEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemSmall:          SmallCalorieView(snapshot: entry.snapshot)
        case .systemMedium:         MediumCalorieView(snapshot: entry.snapshot)
        case .systemLarge:          LargeCalorieView(snapshot: entry.snapshot)
        case .accessoryCircular:    CircularCalorieView(snapshot: entry.snapshot)
        case .accessoryRectangular: RectangularCalorieView(snapshot: entry.snapshot)
        case .accessoryInline:      InlineCalorieView(snapshot: entry.snapshot)
        default:                    SmallCalorieView(snapshot: entry.snapshot)
        }
    }
}

// MARK: - Home Screen

private struct SmallCalorieView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(WidgetPalette.calorieGradient)
                Text("Today")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            ZStack {
                Circle()
                    .stroke(WidgetPalette.calorie.opacity(0.15), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: snapshot.calorieProgress)
                    .stroke(WidgetPalette.calorieGradient, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(snapshot.calories)")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    Text("/ \(snapshot.calorieGoal)")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Text("\(snapshot.caloriesRemaining) kcal left")
                .font(.system(.caption2, design: .rounded, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
}

private struct MediumCalorieView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(WidgetPalette.calorie.opacity(0.15), lineWidth: 9)
                Circle()
                    .trim(from: 0, to: snapshot.calorieProgress)
                    .stroke(WidgetPalette.calorieGradient, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(snapshot.calories)")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text("/ \(snapshot.calorieGoal)")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text("kcal")
                        .font(.system(.caption2, design: .rounded, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 92, height: 92)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(snapshot.displayedHomeNutrients) { nutrient in
                    MacroBar(nutrient: nutrient)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

private struct MacroBar: View {
    let nutrient: WidgetNutrientValue

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(nutrient.label)
                    .font(.system(.caption2, design: .rounded, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(nutrient.displayPair)
                    .font(.system(.caption2, design: .rounded, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(WidgetPalette.calorie.opacity(0.15))
                    Capsule()
                        .fill(WidgetPalette.calorieGradient)
                        .frame(width: max(4, geo.size.width * nutrient.progress))
                }
            }
            .frame(height: 6)
        }
    }
}

// MARK: - StandBy / Large

/// systemLarge — shown in StandBy mode and on the home screen large slot.
/// Uses .widgetAccentable() so the progress arc and bars tint correctly
/// in StandBy's night-mode yellow rendering.
private struct LargeCalorieView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Label("Fud AI", systemImage: "fork.knife")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .widgetAccentable()
                Spacer()
                Text(Date(), style: .date)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            // Big calorie ring
            HStack(spacing: 20) {
                ZStack {
                    Circle()
                        .stroke(WidgetPalette.calorie.opacity(0.15), lineWidth: 16)
                    Circle()
                        .trim(from: 0, to: snapshot.calorieProgress)
                        .stroke(WidgetPalette.calorieGradient, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .widgetAccentable()
                    VStack(spacing: 2) {
                        Text("\(snapshot.calories)")
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                        Text("/ \(snapshot.calorieGoal) kcal")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 130, height: 130)

                VStack(alignment: .leading, spacing: 4) {
                    Text(snapshot.caloriesRemaining > 0
                         ? "\(snapshot.caloriesRemaining) kcal left"
                         : "Goal reached!")
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                        .foregroundStyle(WidgetPalette.calorie)
                        .widgetAccentable()

                    Text("today")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            // Macro bars
            VStack(spacing: 10) {
                ForEach(snapshot.displayedHomeNutrients) { nutrient in
                    MacroBar(nutrient: nutrient)
                }
            }

            Spacer()
        }
        .padding()
    }
}

// MARK: - Lock Screen

/// Above-the-clock circular — compact value-first display for quick scanning.
private struct CircularCalorieView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        AccessoryCircularMetricView(
            iconName: "flame.fill",
            value: "\(snapshot.calories)",
            label: "kcal"
        )
    }
}

private struct RectangularCalorieView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        AccessoryMetricList {
            AccessoryMetricRow(
                iconName: "flame.fill",
                label: "Calories",
                value: "\(snapshot.calories) / \(snapshot.calorieGoal)"
            )

            ForEach(snapshot.displayedHomeNutrients) { nutrient in
                AccessoryMetricRow(
                    iconName: nutrient.lockScreenIconName,
                    label: nutrient.label,
                    value: nutrient.displayPair
                )
            }
        }
    }
}

private struct InlineCalorieView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        // Inline widgets get exactly one line of text; iOS ignores colors.
        Text("\(snapshot.calories) / \(snapshot.calorieGoal) kcal · \(snapshot.caloriesRemaining) left")
    }
}

struct AccessoryMetricList<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

struct AccessoryMetricRow: View {
    let iconName: String
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: iconName)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 15)
                .widgetAccentable()

            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer(minLength: 4)

            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .widgetAccentable()
        }
    }
}

struct AccessoryCircularMetricView: View {
    let iconName: String
    let value: String
    let label: String

    private var valueFontSize: CGFloat {
        value.count <= 3 ? 20 : 17
    }

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()

            VStack(spacing: 0) {
                Image(systemName: iconName)
                    .font(.system(size: 10, weight: .semibold))
                    .frame(height: 12)

                Text(value)
                    .font(.system(size: valueFontSize, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)

                Text(label)
                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 3)
        }
        .widgetAccentable()
    }
}
