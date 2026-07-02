import SwiftUI

/// Mini iPhone-Home for the wrist: the speedometer calorie gauge on top and the
/// user's 4 selected nutrients as vertical fill bars beneath, all tinted with
/// the theme gradient synced from the phone (Fud Pink by default).
struct WatchNutritionView: View {
    @EnvironmentObject private var receiver: WatchSnapshotReceiver

    private var themeGradient: [Color] {
        [
            Color(hex: receiver.snapshot.themeStartHex ?? 0xFF375F),
            Color(hex: receiver.snapshot.themeEndHex ?? 0xFF6B8A),
        ]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                WatchCalorieGauge(
                    eaten: receiver.snapshot.calories,
                    remaining: receiver.snapshot.caloriesRemaining,
                    progress: receiver.snapshot.calorieProgress,
                    gradient: themeGradient
                )

                HStack(alignment: .top, spacing: 6) {
                    ForEach(receiver.snapshot.displayedHomeNutrients) { nutrient in
                        WatchNutrientBar(nutrient: nutrient, gradient: themeGradient)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .onAppear {
            receiver.refreshFromDisk()
        }
    }
}

/// Scaled-down version of the iPhone Home CalorieGauge — dashed top-semicircle
/// track with the eaten count and remaining readout inside the dome.
private struct WatchCalorieGauge: View {
    let eaten: Int
    let remaining: Int
    let progress: Double
    let gradient: [Color]

    private let diameter: CGFloat = 132
    private let lineWidth: CGFloat = 9

    private var dashedStroke: StrokeStyle {
        StrokeStyle(lineWidth: lineWidth, lineCap: .butt, dash: [2.5, 3.8])
    }

    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0.5, to: 1.0)
                .stroke((gradient.first ?? .pink).opacity(0.15), style: dashedStroke)
                .padding(lineWidth / 2)

            Circle()
                .trim(from: 0.5, to: 0.5 + 0.5 * progress)
                .stroke(
                    LinearGradient(colors: gradient, startPoint: .leading, endPoint: .trailing),
                    style: dashedStroke
                )
                .padding(lineWidth / 2)
                .shadow(color: (gradient.first ?? .pink).opacity(0.35), radius: 4, y: 1)

            VStack(spacing: 0) {
                Text("\(eaten)")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                HStack(spacing: 3) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 9, weight: .semibold))
                    Text("\(remaining) left")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(gradient.first ?? .pink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            }
            .offset(y: -diameter * 0.16)
        }
        .frame(width: diameter, height: diameter)
        .frame(height: diameter * 0.56, alignment: .top)
        .clipped()
    }
}

/// One nutrient as a vertical fill tube, like the iPhone Home macro bars:
/// value on top, tube in the middle, name + goal beneath.
private struct WatchNutrientBar: View {
    let nutrient: WidgetNutrientValue
    let gradient: [Color]

    private let barWidth: CGFloat = 10
    private let barHeight: CGFloat = 42

    var body: some View {
        VStack(spacing: 4) {
            Text(nutrient.displayValue)
                .font(.system(size: 13, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(
                    LinearGradient(colors: gradient, startPoint: .top, endPoint: .bottom)
                )
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            ZStack(alignment: .bottom) {
                Capsule()
                    .fill((gradient.first ?? .pink).opacity(0.15))
                    .frame(width: barWidth, height: barHeight)

                if nutrient.progress > 0 {
                    Capsule()
                        .fill(LinearGradient(colors: gradient, startPoint: .bottom, endPoint: .top))
                        .frame(width: barWidth, height: max(barWidth, barHeight * nutrient.progress))
                        .shadow(color: (gradient.first ?? .pink).opacity(0.4), radius: 3)
                }
            }

            VStack(spacing: 0) {
                Text(nutrient.label)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.primary)
                Text("/\(nutrient.displayGoal)\(nutrient.unit)")
                    .font(.system(size: 8, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.55)
        }
        .frame(maxWidth: .infinity)
    }
}

extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
