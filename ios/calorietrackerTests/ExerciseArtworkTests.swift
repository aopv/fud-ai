import Foundation
import Testing
import UIKit
@testable import calorietracker

@MainActor
struct ExerciseArtworkTests {
    @Test func generatedArtworkRequiresBothEndpointFrames() throws {
        let bundleURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathExtension("bundle")
        try FileManager.default.createDirectory(at: bundleURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: bundleURL) }

        let info: [String: Any] = [
            "CFBundleIdentifier": "app.fud.tests.\(UUID().uuidString)",
            "CFBundleName": "ExerciseArtworkTests",
            "CFBundleVersion": "1"
        ]
        let plist = try PropertyListSerialization.data(
            fromPropertyList: info,
            format: .xml,
            options: 0
        )
        try plist.write(to: bundleURL.appendingPathComponent("Info.plist"))
        let bundle = try #require(Bundle(url: bundleURL))

        let first = bundleURL.appendingPathComponent("FudExercise_female_Dumbbell_Curl_0.webp")
        try Data("RIFF-test-WEBP".utf8).write(to: first)
        #expect(
            FudExerciseArtworkLoader.imageURLs(
                for: "Dumbbell_Curl",
                gender: .female,
                bundle: bundle
            ).isEmpty
        )

        let second = bundleURL.appendingPathComponent("FudExercise_female_Dumbbell_Curl_1.webp")
        try Data("RIFF-test-WEBP".utf8).write(to: second)
        let pair = FudExerciseArtworkLoader.imageURLs(
            for: "Dumbbell_Curl",
            gender: .female,
            bundle: bundle
        )
        #expect(pair.map(\.lastPathComponent) == [first.lastPathComponent, second.lastPathComponent])
    }

    @Test func otherGenderUsesMaleGeneratedArtwork() throws {
        let bundleURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathExtension("bundle")
        try FileManager.default.createDirectory(at: bundleURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: bundleURL) }

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
        let bundle = try #require(Bundle(url: bundleURL))

        for frameIndex in 0..<2 {
            try Data([0x89, 0x50, 0x4E, 0x47]).write(
                to: bundleURL.appendingPathComponent(
                    "FudExercise_male_Push-Up_\(frameIndex).webp"
                )
            )
        }

        let other = FudExerciseArtworkLoader.imageURLs(
            for: "Push-Up",
            gender: .other,
            bundle: bundle
        )
        #expect(other.count == 2)
        #expect(other.allSatisfy { $0.lastPathComponent.contains("_male_") })
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
}
