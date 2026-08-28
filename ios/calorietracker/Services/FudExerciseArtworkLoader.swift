import Foundation

/// Resolves reviewed Imagen exercise frames bundled with Fud AI.
///
/// `frames-index.json` is the source of truth for membership, ordering, and
/// playback timing. A generated set is exposed only when every indexed frame
/// exists and the indexes are contiguous from zero. This keeps partial artwork
/// packages from mixing with the original FreeExerciseDB visuals.
enum FudExerciseArtworkLoader {
    struct Artwork: Equatable {
        let imageURLs: [URL]
        let frameDurationMilliseconds: Int
    }

    static let twoFrameDurationMilliseconds = 700
    static let multiFrameDurationMilliseconds = 120

    static func artwork(
        for exerciseID: String?,
        gender: Gender,
        bundle: Bundle = .main
    ) -> Artwork? {
        guard
            let exerciseID,
            isValidStableExerciseID(exerciseID),
            let index = ExerciseArtworkIndexCache.shared.index(for: bundle)
        else {
            return nil
        }

        let figureGender = gender == .female ? "female" : "male"
        guard let entry = index.entries.first(where: {
            $0.exerciseID == exerciseID && $0.gender == figureGender
        }) else {
            return nil
        }

        let frames = entry.frames.sorted { $0.frameIndex < $1.frameIndex }
        guard
            frames.count >= 2,
            frames.map(\.frameIndex) == Array(frames.indices),
            Set(frames.map(\.frameIndex)).count == frames.count
        else {
            return nil
        }

        let urls = frames.compactMap { frame in
            imageURL(filename: frame.filename, bundle: bundle)
        }
        guard urls.count == frames.count else {
            return nil
        }

        let defaultDuration = frames.count >= 3
            ? multiFrameDurationMilliseconds
            : twoFrameDurationMilliseconds
        let duration = entry.frameDurationMs.flatMap { $0 > 0 ? $0 : nil }
            ?? defaultDuration

        return Artwork(
            imageURLs: urls,
            frameDurationMilliseconds: duration
        )
    }

    /// Compatibility helper for callers that only need the ordered URLs.
    static func imageURLs(
        for exerciseID: String?,
        gender: Gender,
        bundle: Bundle = .main
    ) -> [URL] {
        artwork(for: exerciseID, gender: gender, bundle: bundle)?.imageURLs ?? []
    }

    private static func imageURL(filename: String, bundle: Bundle) -> URL? {
        guard
            (filename as NSString).lastPathComponent == filename,
            (filename as NSString).pathExtension.lowercased() == "webp"
        else {
            return nil
        }

        let stem = (filename as NSString).deletingPathExtension
        return firstExistingURL(candidates: [
            bundle.url(forResource: stem, withExtension: "webp"),
            bundle.url(
                forResource: stem,
                withExtension: "webp",
                subdirectory: "FudExerciseArtwork/frames"
            ),
            bundle.url(
                forResource: stem,
                withExtension: "webp",
                subdirectory: "Resources/FudExerciseArtwork/frames"
            ),
            bundle.resourceURL?.appendingPathComponent(filename),
            bundle.resourceURL?.appendingPathComponent("FudExerciseArtwork/frames/\(filename)"),
            bundle.resourceURL?.appendingPathComponent("Resources/FudExerciseArtwork/frames/\(filename)")
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

private struct ExerciseArtworkIndex: Decodable {
    let entries: [Entry]

    struct Entry: Decodable {
        let exerciseID: String
        let gender: String
        let frameDurationMs: Int?
        let frames: [Frame]
    }

    struct Frame: Decodable {
        let filename: String
        let frameIndex: Int
    }
}

private final class ExerciseArtworkIndexCache: @unchecked Sendable {
    static let shared = ExerciseArtworkIndexCache()

    private let lock = NSLock()
    private var indexesByURL: [URL: ExerciseArtworkIndex] = [:]

    private init() {}

    func index(for bundle: Bundle) -> ExerciseArtworkIndex? {
        guard let url = indexURL(in: bundle) else {
            return nil
        }

        lock.lock()
        defer { lock.unlock() }
        if let cached = indexesByURL[url] {
            return cached
        }

        guard
            let data = try? Data(contentsOf: url),
            let index = try? JSONDecoder().decode(ExerciseArtworkIndex.self, from: data)
        else {
            return nil
        }
        indexesByURL[url] = index
        return index
    }

    private func indexURL(in bundle: Bundle) -> URL? {
        FudExerciseArtworkLoaderIndexResolver.firstExistingURL(candidates: [
            bundle.url(forResource: "frames-index", withExtension: "json"),
            bundle.url(
                forResource: "frames-index",
                withExtension: "json",
                subdirectory: "FudExerciseArtwork"
            ),
            bundle.url(
                forResource: "frames-index",
                withExtension: "json",
                subdirectory: "Resources/FudExerciseArtwork"
            ),
            bundle.resourceURL?.appendingPathComponent("frames-index.json"),
            bundle.resourceURL?.appendingPathComponent("FudExerciseArtwork/frames-index.json"),
            bundle.resourceURL?.appendingPathComponent("Resources/FudExerciseArtwork/frames-index.json")
        ])
    }
}

private enum FudExerciseArtworkLoaderIndexResolver {
    static func firstExistingURL(candidates: [URL?]) -> URL? {
        candidates.compactMap { $0 }.first {
            FileManager.default.fileExists(atPath: $0.path)
        }
    }
}
