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
                        .clipShape(Rectangle())
                } else {
                    NeoAppColors.subtleSurface

                    Image(systemName: "text.magnifyingglass")
                        .font(.system(size: 64, weight: .black))
                        .foregroundStyle(NeoAppColors.cobalt)
                }
            }
            .frame(maxWidth: 250, minHeight: 220, maxHeight: 250)
            .background(NeoAppColors.surface)
            .overlay {
                Rectangle()
                    .stroke(NeoAppColors.ink, lineWidth: NeoAppMetrics.rule)
            }
            .accessibilityHidden(true)

            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.large)
                    .tint(NeoAppColors.cobalt)

                Text(message)
                    .textCase(.uppercase)
                    .font(.system(.headline, design: .rounded, weight: .black))
                    .foregroundStyle(NeoAppColors.ink)
                    .multilineTextAlignment(.center)
            }
            .padding(16)
            .frame(maxWidth: 250)
            .background(NeoAppColors.acid)
            .overlay {
                Rectangle()
                    .stroke(NeoAppColors.ink, lineWidth: NeoAppMetrics.rule)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(message)
            .accessibilityValue("In progress")

            Spacer(minLength: 8)
        }
        .padding(NeoAppMetrics.screenInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(NeoAppColors.canvas.ignoresSafeArea())
    }
}
