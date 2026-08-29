import SwiftUI

struct AIProviderBrandIcon: View {
    let provider: AIProvider
    var size: CGFloat = 18

    var body: some View {
        ProviderBrandIcon(
            assetName: provider.logoAssetName,
            fallbackSystemImage: provider.fallbackSystemImage,
            size: size
        )
    }
}

struct SpeechProviderBrandIcon: View {
    let provider: SpeechProvider
    var size: CGFloat = 18

    var body: some View {
        ProviderBrandIcon(
            assetName: provider.logoAssetName,
            fallbackSystemImage: provider.fallbackSystemImage,
            size: size
        )
    }
}

private struct ProviderBrandIcon: View {
    let assetName: String?
    let fallbackSystemImage: String
    let size: CGFloat

    var body: some View {
        Group {
            if let assetName {
                Image(assetName)
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
            } else {
                Image(systemName: fallbackSystemImage)
                    .resizable()
                    .scaledToFit()
            }
        }
        .frame(width: size, height: size)
        .foregroundStyle(AppColors.calorie)
        .accessibilityHidden(true)
    }
}
