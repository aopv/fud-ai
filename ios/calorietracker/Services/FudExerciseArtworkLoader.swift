import Foundation

/// Resolves reviewed Imagen exercise frames bundled with Fud AI.
///
/// Generated frames are optional and may arrive incrementally. A frame set is
/// accepted only when both start and finish images exist for the selected
/// gender; otherwise the caller keeps using the original FreeExerciseDB pair.
/// This prevents a half-generated exercise from mixing visual styles.
enum FudExerciseArtworkLoader {
    static let frameCount = 2

    static func imageURLs(
        for exerciseID: String?,
        gender: Gender,
        bundle: Bundle = .main
    ) -> [URL] {
        guard
            let exerciseID,
            isValidStableExerciseID(exerciseID)
        else {
            return []
        }

        let figureGender = gender == .female ? "female" : "male"
        let urls = (0..<frameCount).compactMap { frameIndex in
            imageURL(
                exerciseID: exerciseID,
                gender: figureGender,
                frameIndex: frameIndex,
                bundle: bundle
            )
        }
        return urls.count == frameCount ? urls : []
    }

    private static func imageURL(
        exerciseID: String,
        gender: String,
        frameIndex: Int,
        bundle: Bundle
    ) -> URL? {
        let canonicalFilename = "\(frameIndex).webp"
        let flattenedFilename = "FudExercise_\(gender)_\(exerciseID)_\(frameIndex).webp"
        let flattenedStem = (flattenedFilename as NSString).deletingPathExtension

        return firstExistingURL(candidates: [
            // Canonical generated-artwork layout when copied as a folder
            // reference into the application bundle.
            bundle.url(
                forResource: "\(frameIndex)",
                withExtension: "webp",
                subdirectory: "FudExerciseArtwork/frames/\(gender)/\(exerciseID)"
            ),
            bundle.url(
                forResource: "\(frameIndex)",
                withExtension: "webp",
                subdirectory: "Resources/FudExerciseArtwork/frames/\(gender)/\(exerciseID)"
            ),
            bundle.resourceURL?.appendingPathComponent(
                "FudExerciseArtwork/frames/\(gender)/\(exerciseID)/\(canonicalFilename)"
            ),
            bundle.resourceURL?.appendingPathComponent(
                "Resources/FudExerciseArtwork/frames/\(gender)/\(exerciseID)/\(canonicalFilename)"
            ),

            // Xcode's synchronized resource group currently flattens bundled
            // files. The acceptance pipeline can copy/rename approved outputs
            // to this collision-free form without changing runtime code.
            bundle.url(forResource: flattenedStem, withExtension: "webp"),
            bundle.url(
                forResource: flattenedStem,
                withExtension: "webp",
                subdirectory: "FudExerciseArtwork/frames"
            ),
            bundle.resourceURL?.appendingPathComponent(flattenedFilename)
        ])
    }

    private static func isValidStableExerciseID(_ exerciseID: String) -> Bool {
        !exerciseID.isEmpty && exerciseID.unicodeScalars.allSatisfy {
            CharacterSet.alphanumerics.contains($0) || "_-".unicodeScalars.contains($0)
        }
    }

    private static func firstExistingURL(candidates: [URL?]) -> URL? {
        candidates.compactMap { $0 }.first {
            FileManager.default.fileExists(atPath: $0.path)
        }
    }
}
