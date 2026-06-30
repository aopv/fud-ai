import SwiftUI

struct AnalyzingView: View {
    let image: UIImage?
    var message: String = "Analyzing your food..."

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 12)

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 200, maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(radius: 8)
            } else {
                Image(systemName: "text.magnifyingglass")
                    .font(.system(size: 56))
                    .foregroundStyle(AppColors.calorie)
                    .frame(maxWidth: 200, maxHeight: 200)
            }

            ProgressView()
                .controlSize(.large)
                .tint(AppColors.calorie)

            Text(message)
                .font(.headline)
                .foregroundStyle(AppColors.calorie)

            Spacer(minLength: 16)

            // Ad shown while the AI works — the user is already waiting, so it's unobtrusive.
            BannerAdView(unitID: AdsConfig.analyzingUnitID, format: .mediumRectangle)
                .frame(width: 300, height: 250)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }
}
