import SwiftUI
import UIKit

struct AnimatedExerciseVisual: View {
    var muscleGroup: MuscleGroup? = nil
    var assetName: String?
    var exerciseID: String?
    var exerciseName: String?
    var imagePaths: [String] = []
    var rawEquipment: String?
    var equipment: Equipment?
    var height: CGFloat = 170
    var fillsWidth = true
    var allowsDerivedImageLookup = true
    var animatesFrames = true
    var fallbackSystemImage = "figure.strengthtraining.traditional"
    var fallbackTitle = String(localized: "Exercise")

    @Environment(ProfileStore.self) private var profileStore
    @State private var animateFallback = false

    var body: some View {
        let generatedArtwork = FudExerciseArtworkLoader.artwork(
            for: exerciseID,
            gender: profileStore.profile.gender
        )
        let generatedURLs = generatedArtwork?.imageURLs ?? []
        let imageURLs = generatedURLs.isEmpty ? resolvedLegacyImageURLs : generatedURLs
        let usesGeneratedArtwork = !generatedURLs.isEmpty
        let frameDurationMilliseconds = generatedArtwork?.frameDurationMilliseconds ?? 850

        ZStack {
            if !imageURLs.isEmpty {
                ExerciseImageView(
                    urls: imageURLs,
                    animatesFrames: animatesFrames,
                    usesGeneratedArtwork: usesGeneratedArtwork,
                    frameDurationMilliseconds: frameDurationMilliseconds
                )
            } else {
                fallbackVisual
            }
        }
        .frame(maxWidth: fillsWidth ? .infinity : nil)
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color(uiColor: .separator).opacity(0.35), lineWidth: 0.5)
        )
    }

    private var resolvedLegacyImageURLs: [URL] {
        let directURLs = FreeExerciseDBAssetResolver.imageURLs(for: imagePaths)
        if !directURLs.isEmpty {
            return directURLs
        }

        guard allowsDerivedImageLookup else {
            return []
        }

        let namedURLs = FreeExerciseDBAssetResolver.imageURLs(
            forExerciseName: exerciseName,
            muscleGroup: muscleGroup,
            equipment: equipment
        )
        if !namedURLs.isEmpty {
            return namedURLs
        }

        guard let muscleGroup else {
            return []
        }

        return FreeExerciseDBAssetResolver.imageURLs(
            forMuscleGroup: muscleGroup,
            equipment: equipment
        )
    }

    private var fallbackVisual: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.workoutPanel,
                    Color.workoutCard,
                    Color.workoutAccent.opacity(animateFallback ? 0.20 : 0.10)
                ],
                startPoint: animateFallback ? .topLeading : .bottomLeading,
                endPoint: animateFallback ? .bottomTrailing : .topTrailing
            )
            .animation(
                .easeInOut(duration: 2.6).repeatForever(autoreverses: true),
                value: animateFallback
            )

            VStack(spacing: 12) {
                Image(systemName: muscleGroup?.icon ?? fallbackSystemImage)
                    .font(.system(size: 36, weight: .semibold))
                    .symbolEffect(.pulse, options: .repeating, value: animateFallback)
                Text((muscleGroup?.title ?? fallbackTitle).uppercased())
                    .font(.caption.weight(.bold))
                    .tracking(1.2)
                if let equipment {
                    Text(equipment.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.workoutMutedText)
                } else if let rawEquipment = rawEquipment?.nilIfBlank {
                    Text(rawEquipment)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.workoutMutedText)
                }
            }
            .foregroundStyle(Color.workoutCharcoal)
        }
        .onAppear { animateFallback = true }
    }
}

private struct ExerciseImageView: View {
    let urls: [URL]
    let animatesFrames: Bool
    let usesGeneratedArtwork: Bool
    let frameDurationMilliseconds: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var frameIndex = 0
    @State private var frames: [UIImage] = []

    var body: some View {
        ZStack {
            Color.workoutPanel.opacity(0.18)

            if !frames.isEmpty {
                ZStack {
                    ForEach(frames.indices, id: \.self) { index in
                        Image(uiImage: frames[index])
                            .resizable()
                            .modifier(ExerciseArtworkScaling(isGenerated: usesGeneratedArtwork))
                            .modifier(ExerciseArtworkTreatment(isGenerated: usesGeneratedArtwork))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .opacity(index == frameIndex ? 1 : 0)
                    }
                }
            }
        }
        .task(id: ExerciseImageTaskID(
            urls: urls,
            animatesFrames: animatesFrames,
            reduceMotion: reduceMotion,
            frameDurationMilliseconds: frameDurationMilliseconds
        )) {
            let loadedFrames = ExerciseImageCache.shared.images(for: urls)
            frameIndex = 0
            frames = loadedFrames

            guard animatesFrames, frames.count > 1, !reduceMotion else { return }
            let sequence = usesGeneratedArtwork
                ? ExerciseArtworkPlayback.pingPongIndices(frameCount: frames.count)
                : Array(frames.indices)
            guard sequence.count > 1 else { return }
            let interval = UInt64(max(frameDurationMilliseconds, 1)) * 1_000_000
            var playbackIndex = 0
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: interval)
                guard !Task.isCancelled else { return }
                playbackIndex = (playbackIndex + 1) % sequence.count
                frameIndex = sequence[playbackIndex]
            }
        }
    }
}

struct ExerciseArtworkPlayback {
    static func pingPongIndices(frameCount: Int) -> [Int] {
        guard frameCount > 1 else {
            return frameCount == 1 ? [0] : []
        }

        let forward = Array(0..<frameCount)
        guard frameCount > 2 else { return forward }
        return forward + Array(stride(from: frameCount - 2, through: 1, by: -1))
    }
}

private struct ExerciseImageTaskID: Hashable {
    let urls: [URL]
    let animatesFrames: Bool
    let reduceMotion: Bool
    let frameDurationMilliseconds: Int
}

private struct ExerciseArtworkScaling: ViewModifier {
    let isGenerated: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if isGenerated {
            content.scaledToFit()
        } else {
            content.scaledToFill().clipped()
        }
    }
}

private struct ExerciseArtworkTreatment: ViewModifier {
    let isGenerated: Bool

    func body(content: Content) -> some View {
        if isGenerated {
            // Approved Imagen artwork already carries the Fud AI flat-vector
            // palette and must remain in full color.
            content
        } else {
            // Preserve the existing treatment for original FreeExerciseDB
            // photos whenever a generated pair is absent or still under QA.
            content
                .saturation(0.30)
                .grayscale(0.36)
                .contrast(1.10)
                .brightness(-0.05)
        }
    }
}

private final class ExerciseImageCache {
    static let shared = ExerciseImageCache()

    private let imagesByURL = NSCache<NSURL, UIImage>()

    private init() {
        imagesByURL.countLimit = 96
        imagesByURL.totalCostLimit = 48 * 1_024 * 1_024
    }

    func images(for urls: [URL]) -> [UIImage] {
        urls.compactMap { image(for: $0) }
    }

    private func image(for url: URL) -> UIImage? {
        let key = url as NSURL
        if let cached = imagesByURL.object(forKey: key) {
            return cached
        }

        guard let image = UIImage(contentsOfFile: url.path) else {
            return nil
        }
        let cost = Int(image.size.width * image.size.height * image.scale * image.scale * 4)
        imagesByURL.setObject(image, forKey: key, cost: cost)
        return image
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
