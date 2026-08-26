import SwiftUI

struct AnalyzingView: View {
    let image: UIImage?
    var message: String = "Analyzing your food..."

    var body: some View {
        VStack(spacing: NeoAppMetrics.sectionSpacing) {
            NeoScreenHeader(
                eyebrow: "FUD AI VISION",
                title: "Analyzing",
                subtitle: message
            )

            Spacer(minLength: 8)

            ZStack {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 250, maxHeight: 250)
                        .compositingGroup()
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                } else {
                    NeoAppColors.subtleSurface

                    Image(systemName: "text.magnifyingglass")
                        .font(.system(size: 64, weight: .black))
                        .foregroundStyle(NeoAppColors.cobalt)
                }
            }
            .frame(maxWidth: 250, minHeight: 220, maxHeight: 250)
            .background(NeoAppColors.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(KitchenTablePalette.rule, lineWidth: NeoAppMetrics.rule)
            }
            .shadow(color: KitchenTablePalette.shadow, radius: 8, x: 0, y: 4)
            .accessibilityHidden(true)

            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.large)
                    .tint(NeoAppColors.cobalt)

                Text(message)
                    .textCase(.uppercase)
                    .font(.system(.headline, design: .rounded, weight: .black))
                    .foregroundStyle(KitchenTablePalette.onBrass)
                    .multilineTextAlignment(.center)
            }
            .padding(16)
            .frame(maxWidth: 250)
            .background(NeoAppColors.brass, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(KitchenTablePalette.brassDeep, lineWidth: NeoAppMetrics.rule)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(message)
            .accessibilityValue("In progress")

            Spacer(minLength: 8)
        }
        .padding(NeoAppMetrics.screenInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(KitchenTableBackdrop())
    }
}
