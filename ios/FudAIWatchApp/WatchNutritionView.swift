import SwiftUI

struct WatchNutritionView: View {
    @EnvironmentObject private var receiver: WatchSnapshotReceiver

    var body: some View {
        NavigationStack {
            VStack(spacing: 9) {
                CalorieSummary(snapshot: receiver.snapshot)

                HStack(spacing: 5) {
                    NutrientCompactCard(
                        title: "Protein",
                        value: receiver.snapshot.protein,
                        goal: receiver.snapshot.proteinGoal,
                        unit: "g",
                        progress: receiver.snapshot.proteinProgress,
                        color: .blue
                    )
                    NutrientCompactCard(
                        title: "Carbs",
                        value: receiver.snapshot.carbs,
                        goal: receiver.snapshot.carbsGoal,
                        unit: "g",
                        progress: receiver.snapshot.carbsProgress,
                        color: .green
                    )
                    NutrientCompactCard(
                        title: "Fat",
                        value: receiver.snapshot.fat,
                        goal: receiver.snapshot.fatGoal,
                        unit: "g",
                        progress: receiver.snapshot.fatProgress,
                        color: .orange
                    )
                }

                NavigationLink(destination: WatchVoiceInputView()) {
                    Label("Log Food", systemImage: "mic.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(.red, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .navigationTitle("Fud AI")
            .onAppear {
                receiver.refreshFromDisk()
            }
        }
    }
}

private struct CalorieSummary: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            ProgressRing(
                progress: snapshot.calorieProgress,
                color: .red,
                lineWidth: 6
            ) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.red)
            }
            .frame(width: 43, height: 43)

            VStack(alignment: .leading, spacing: 1) {
                Text("Today")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(snapshot.calories)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Text("/ \(snapshot.calorieGoal)")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                Text("\(snapshot.caloriesRemaining) kcal left")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct NutrientCompactCard: View {
    let title: String
    let value: Double
    let goal: Int
    let unit: String
    let progress: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            VStack(alignment: .leading, spacing: 0) {
                Text("\(Self.format(value))\(unit)")
                    .font(.system(size: 14, weight: .bold, design: .rounded).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("/ \(goal)\(unit)")
                    .font(.system(size: 9, weight: .medium, design: .rounded).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(color.opacity(0.18))
                    Capsule()
                        .fill(color)
                        .frame(width: max(4, geometry.size.width * progress))
                }
            }
            .frame(height: 5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    private static func format(_ value: Double) -> String {
        if abs(value.rounded() - value) < 0.0001 {
            return "\(Int(value.rounded()))"
        }
        return String(format: "%.1f", value)
    }
}

private struct ProgressRing<Content: View>: View {
    let progress: Double
    let color: Color
    let lineWidth: CGFloat
    private let content: () -> Content

    init(
        progress: Double,
        color: Color,
        lineWidth: CGFloat,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.progress = progress
        self.color = color
        self.lineWidth = lineWidth
        self.content = content
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.18), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            content()
        }
    }
}
