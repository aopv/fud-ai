import SwiftUI

struct AnalyzingView: View {
    let image: UIImage?
    var message: String = String(localized: "Analyzing with AI…")

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                KitchenTableBackdrop()

                VStack(spacing: 18) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Review Food")
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .tracking(0.8)
                            .foregroundStyle(KitchenTablePalette.tomato)

                        Spacer()

                        Text("AI analysis")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .tracking(1.1)
                            .foregroundStyle(KitchenTablePalette.mutedEspresso)
                    }

                    ZStack(alignment: .bottom) {
                        mealPreview
                            .frame(
                                width: min(proxy.size.width - 32, 390),
                                height: min(proxy.size.width - 32, 390)
                            )
                            .padding(.bottom, 88)

                        analysisReceipt
                            .frame(maxWidth: min(proxy.size.width - 58, 344))
                    }
                    .frame(maxHeight: .infinity)

                    Text("Analyzing with AI…")
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(KitchenTablePalette.mutedEspresso)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(message)
        .accessibilityValue("Analyzing")
    }

    @ViewBuilder
    private var mealPreview: some View {
        ZStack {
            Circle()
                .fill(KitchenTablePalette.paperMuted)

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipShape(Circle())
                    .padding(9)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "fork.knife.circle")
                        .font(.system(size: 72, weight: .light))
                        .foregroundStyle(KitchenTablePalette.cobalt)
                    Text("Analyzing with AI…")
                        .font(.system(.callout, design: .serif, weight: .semibold))
                        .foregroundStyle(KitchenTablePalette.mutedEspresso)
                }
            }
        }
        .overlay {
            Circle()
                .stroke(KitchenTablePalette.strongRule, lineWidth: 1)
        }
        .overlay {
            Circle()
                .stroke(KitchenTablePalette.paperRaised, lineWidth: 7)
                .padding(8)
        }
        .shadow(color: KitchenTablePalette.shadow, radius: 12, x: 0, y: 6)
        .accessibilityHidden(true)
    }

    private var analysisReceipt: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .firstTextBaseline) {
                Text("AI analysis")
                    .textCase(.uppercase)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(1.4)

                Spacer()

                Text("Analyzing")
                    .textCase(.uppercase)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(KitchenTablePalette.tomato)
            }

            Rectangle()
                .fill(KitchenTablePalette.rule)
                .frame(height: 1)

            HStack(spacing: 12) {
                ProgressView()
                    .controlSize(.regular)
                    .tint(KitchenTablePalette.cobalt)

                Text(message)
                    .font(.system(.title3, design: .serif, weight: .semibold))
                    .foregroundStyle(KitchenTablePalette.espresso)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 7) {
                Circle()
                    .fill(KitchenTablePalette.herb)
                    .frame(width: 7, height: 7)
                Text("Analyzing with AI…")
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(KitchenTablePalette.mutedEspresso)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(KitchenTablePalette.paperRaised)
        .overlay {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .stroke(KitchenTablePalette.rule, lineWidth: 1)
        }
        .shadow(color: KitchenTablePalette.shadow, radius: 8, x: 0, y: 5)
        .rotationEffect(.degrees(-0.45))
    }
}
