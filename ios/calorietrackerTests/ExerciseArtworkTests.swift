import Foundation
import Testing
import UIKit
@testable import calorietracker

@MainActor
struct ExerciseArtworkTests {
    @Test func generatedArtworkRequiresEveryIndexedFrame() throws {
        let testBundle = try makeBundle(
            entries: [indexEntry(exerciseID: "Dumbbell_Curl", gender: "female", frameCount: 2)],
            filenamesToCreate: ["FudExercise_female_Dumbbell_Curl_0.webp"]
        )
        defer { try? FileManager.default.removeItem(at: testBundle.url) }

        #expect(
            FudExerciseArtworkLoader.artwork(
                for: "Dumbbell_Curl",
                gender: .female,
                bundle: testBundle.bundle
            ) == nil
        )
    }

    @Test func sixFrameArtworkUsesIndexOrderAndFastDefaultTiming() throws {
        var entry = indexEntry(
            exerciseID: "Dumbbell_Curl",
            gender: "female",
            frameCount: 6
        )
        entry["frames"] = (0..<6).reversed().map {
            frame(exerciseID: "Dumbbell_Curl", gender: "female", index: $0)
        }
        let filenames = (0..<6).map {
            filename(exerciseID: "Dumbbell_Curl", gender: "female", index: $0)
        }
        let testBundle = try makeBundle(entries: [entry], filenamesToCreate: filenames)
        defer { try? FileManager.default.removeItem(at: testBundle.url) }

        let artwork = try #require(FudExerciseArtworkLoader.artwork(
            for: "Dumbbell_Curl",
            gender: .female,
            bundle: testBundle.bundle
        ))
        #expect(artwork.imageURLs.map(\.lastPathComponent) == filenames)
        #expect(
            artwork.frameDurationMilliseconds
                == FudExerciseArtworkLoader.multiFrameDurationMilliseconds
        )
    }

    @Test func twoFrameArtworkKeepsExistingGeneratedTiming() throws {
        let entry = indexEntry(exerciseID: "Push-Up", gender: "male", frameCount: 2)
        let filenames = (0..<2).map {
            filename(exerciseID: "Push-Up", gender: "male", index: $0)
        }
        let testBundle = try makeBundle(entries: [entry], filenamesToCreate: filenames)
        defer { try? FileManager.default.removeItem(at: testBundle.url) }

        let artwork = try #require(FudExerciseArtworkLoader.artwork(
            for: "Push-Up",
            gender: .other,
            bundle: testBundle.bundle
        ))
        #expect(artwork.imageURLs.count == 2)
        #expect(artwork.imageURLs.allSatisfy { $0.lastPathComponent.contains("_male_") })
        #expect(
            artwork.frameDurationMilliseconds
                == FudExerciseArtworkLoader.twoFrameDurationMilliseconds
        )
    }

    @Test func indexTimingOverridesDefault() throws {
        var entry = indexEntry(exerciseID: "Push-Up", gender: "female", frameCount: 6)
        entry["frameDurationMs"] = 165
        let filenames = (0..<6).map {
            filename(exerciseID: "Push-Up", gender: "female", index: $0)
        }
        let testBundle = try makeBundle(entries: [entry], filenamesToCreate: filenames)
        defer { try? FileManager.default.removeItem(at: testBundle.url) }

        let artwork = try #require(FudExerciseArtworkLoader.artwork(
            for: "Push-Up",
            gender: .female,
            bundle: testBundle.bundle
        ))
        #expect(artwork.frameDurationMilliseconds == 165)
    }

    @Test func noncontiguousIndexIsRejected() throws {
        var entry = indexEntry(exerciseID: "Push-Up", gender: "female", frameCount: 2)
        entry["frames"] = [
            frame(exerciseID: "Push-Up", gender: "female", index: 0),
            frame(exerciseID: "Push-Up", gender: "female", index: 2)
        ]
        let filenames = [0, 2].map {
            filename(exerciseID: "Push-Up", gender: "female", index: $0)
        }
        let testBundle = try makeBundle(entries: [entry], filenamesToCreate: filenames)
        defer { try? FileManager.default.removeItem(at: testBundle.url) }

        #expect(FudExerciseArtworkLoader.artwork(
            for: "Push-Up",
            gender: .female,
            bundle: testBundle.bundle
        ) == nil)
    }

    @Test func pingPongSequenceDoesNotSnapFromLastFrameToFirst() {
        #expect(ExerciseArtworkPlayback.pingPongIndices(frameCount: 0) == [])
        #expect(ExerciseArtworkPlayback.pingPongIndices(frameCount: 1) == [0])
        #expect(ExerciseArtworkPlayback.pingPongIndices(frameCount: 2) == [0, 1])
        #expect(
            ExerciseArtworkPlayback.pingPongIndices(frameCount: 6)
                == [0, 1, 2, 3, 4, 5, 4, 3, 2, 1]
        )
    }

    @Test func unsafeOrMissingStableIDsNeverResolveGeneratedFiles() {
        #expect(FudExerciseArtworkLoader.imageURLs(for: nil, gender: .female).isEmpty)
        #expect(FudExerciseArtworkLoader.imageURLs(for: "../outside", gender: .female).isEmpty)
        #expect(FudExerciseArtworkLoader.imageURLs(for: "", gender: .female).isEmpty)
    }

    @Test func stagedWebPArtworkDecodesWithUIKit() throws {
        let urls = FudExerciseArtworkLoader.imageURLs(
            for: "Dumbbell_Bicep_Curl",
            gender: .female,
            bundle: .main
        )
        let pair = try #require(urls.count == 2 ? urls : nil)
        for url in pair {
            let image = try #require(UIImage(contentsOfFile: url.path))
            #expect(image.size.width == 768)
            #expect(image.size.height == 768)
        }
    }

    private func makeBundle(
        entries: [[String: Any]],
        filenamesToCreate: [String]
    ) throws -> (url: URL, bundle: Bundle) {
        let bundleURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathExtension("bundle")
        try FileManager.default.createDirectory(at: bundleURL, withIntermediateDirectories: true)

        let plist = try PropertyListSerialization.data(
            fromPropertyList: [
                "CFBundleIdentifier": "app.fud.tests.\(UUID().uuidString)",
                "CFBundleName": "ExerciseArtworkTests",
                "CFBundleVersion": "1"
            ],
            format: .xml,
            options: 0
        )
        try plist.write(to: bundleURL.appendingPathComponent("Info.plist"))

        let index = try JSONSerialization.data(
            withJSONObject: ["entries": entries],
            options: [.sortedKeys]
        )
        try index.write(to: bundleURL.appendingPathComponent("frames-index.json"))
        for filename in filenamesToCreate {
            try Data("RIFF-test-WEBP".utf8).write(
                to: bundleURL.appendingPathComponent(filename)
            )
        }

        return (bundleURL, try #require(Bundle(url: bundleURL)))
    }

    private func indexEntry(
        exerciseID: String,
        gender: String,
        frameCount: Int
    ) -> [String: Any] {
        [
            "exerciseID": exerciseID,
            "gender": gender,
            "frames": (0..<frameCount).map {
                frame(exerciseID: exerciseID, gender: gender, index: $0)
            }
        ]
    }

    private func frame(exerciseID: String, gender: String, index: Int) -> [String: Any] {
        [
            "filename": filename(exerciseID: exerciseID, gender: gender, index: index),
            "frameIndex": index
        ]
    }

    private func filename(exerciseID: String, gender: String, index: Int) -> String {
        "FudExercise_\(gender)_\(exerciseID)_\(index).webp"
    }
}
