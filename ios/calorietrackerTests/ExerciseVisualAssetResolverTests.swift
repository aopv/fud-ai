import Foundation
import Testing
import UIKit
@testable import calorietracker

@MainActor
struct ExerciseVisualAssetResolverTests {
    private let jpegPaths = [
        "Barbell_Full_Squat_0.jpg",
        "Barbell_Full_Squat_1.jpg"
    ]

    @Test func manifestAcceptsThreeFourAndFiveFrameAtomicGenderSets() throws {
        for frameCount in 3...5 {
            let manifest = try makeManifest(frameCount: frameCount)
            let entry = try #require(manifest.entry(for: "Barbell_Full_Squat"))

            #expect(entry.frameCount == frameCount)
            #expect(entry.frames(for: .female) == frameNames(gender: "female", count: frameCount))
            #expect(entry.frames(for: .male) == frameNames(gender: "male", count: frameCount))
            #expect(entry.frames(for: .other) == frameNames(gender: "male", count: frameCount))
        }
    }

    @Test func completeSVGSetIsPreferredAndUsesManifestRepresentativeFrame() throws {
        let svgNames = frameNames(gender: "female", count: 4)
        let asset = FreeExerciseDBAssetResolver.preferredVisualAsset(
            for: jpegPaths,
            gender: .female,
            manifest: try makeManifest(frameCount: 4, representativeFrameIndex: 2),
            resolveJPEGURL: jpegResolver
        )

        #expect(asset.format == .svg)
        #expect(asset.frames == svgNames.map(ExerciseVisualFrame.imageAsset))
        #expect(asset.representativeFrameIndex == 2)
    }

    @Test func missingOppositeGenderSetFallsBackToOriginalJPEGSequence() throws {
        let manifest = try makeManifest(frameCount: 4, includeFemaleFrames: false)
        let asset = FreeExerciseDBAssetResolver.preferredVisualAsset(
            for: jpegPaths,
            gender: .male,
            manifest: manifest,
            resolveJPEGURL: jpegResolver
        )

        #expect(asset.format == .jpeg)
        #expect(asset.frames == jpegPaths.map { .file(resolvedURL(for: $0)) })
        #expect(asset.representativeFrameIndex == 0)
    }

    @Test func manifestSupportsVersionedPNGFrames() throws {
        let femaleFrames = v2FrameNames(gender: "female")
        let asset = FreeExerciseDBAssetResolver.preferredVisualAsset(
            for: jpegPaths,
            gender: .female,
            manifest: try makeManifest(
                frameCount: 4,
                representativeFrameIndex: 2,
                format: "png",
                maleFrames: v2FrameNames(gender: "male"),
                femaleFrames: femaleFrames
            ),
            resolveJPEGURL: jpegResolver
        )

        #expect(asset.format == .png)
        #expect(asset.frames == femaleFrames.map(ExerciseVisualFrame.imageAsset))
        #expect(asset.representativeFrameIndex == 2)
    }

    @Test func invalidTwoOrSixFrameSetsFallBackToJPEG() throws {
        for frameCount in [2, 6] {
            let asset = FreeExerciseDBAssetResolver.preferredVisualAsset(
                for: jpegPaths,
                gender: .male,
                manifest: try makeManifest(frameCount: frameCount),
                resolveJPEGURL: jpegResolver
            )

            #expect(asset.format == .jpeg)
            #expect(asset.frames == jpegPaths.map { .file(resolvedURL(for: $0)) })
        }
    }

    @Test func exerciseIDIsInferredFromNestedJPEGFilename() throws {
        let nestedJPEGPaths = jpegPaths.map { "FreeExerciseDB/images/\($0)" }
        let svgNames = frameNames(gender: "male", count: 4)
        let asset = FreeExerciseDBAssetResolver.preferredVisualAsset(
            for: nestedJPEGPaths,
            gender: .other,
            manifest: try makeManifest(frameCount: 4),
            resolveJPEGURL: { _ in nil }
        )

        #expect(asset.format == .svg)
        #expect(asset.frames == svgNames.map(ExerciseVisualFrame.imageAsset))
    }

    @Test func bundledV2PNGsResolveThroughAssetCatalog() throws {
        let manifestData = try #require(NSDataAsset(name: "ExerciseVisualManifest")?.data)
        let manifest = try ExerciseVisualManifest(data: manifestData)
        #expect(manifest.entry(for: "Barbell_Full_Squat")?.frameCount == 4)

        for gender in [Gender.male, .female] {
            let asset = FreeExerciseDBAssetResolver.preferredVisualAsset(
                for: jpegPaths,
                gender: gender
            )

            #expect(asset.format == .png)
            #expect(asset.frames.count == 4)
            #expect(
                asset.frames.allSatisfy { frame in
                    guard case .imageAsset(let name) = frame else { return false }
                    return UIImage(named: name) != nil
                }
            )
        }
    }

    private func makeManifest(
        frameCount: Int,
        representativeFrameIndex: Int = 1,
        format: String? = nil,
        maleFrames: [String]? = nil,
        femaleFrames: [String]? = nil,
        includeMaleFrames: Bool = true,
        includeFemaleFrames: Bool = true
    ) throws -> ExerciseVisualManifest {
        var entry: [String: Any] = [
            "exerciseId": "Barbell_Full_Squat",
            "frameCount": frameCount,
            "representativeFrameIndex": representativeFrameIndex,
        ]
        if let format {
            entry["format"] = format
        }
        if includeMaleFrames {
            entry["maleFrames"] = maleFrames ?? frameNames(gender: "male", count: frameCount)
        }
        if includeFemaleFrames {
            entry["femaleFrames"] = femaleFrames ?? frameNames(gender: "female", count: frameCount)
        }
        let data = try JSONSerialization.data(withJSONObject: [
            "schemaVersion": 1,
            "exercises": [entry],
        ])
        return try ExerciseVisualManifest(data: data)
    }

    private func frameNames(gender: String, count: Int) -> [String] {
        guard count > 0 else { return [] }
        return (0..<count).map { "Barbell_Full_Squat_\(gender)_\($0)" }
    }

    private func v2FrameNames(gender: String) -> [String] {
        (0..<4).map { "Barbell_Full_Squat_\(gender)_v2_\($0)" }
    }

    private var jpegResolver: (String) -> URL? {
        { resolvedURL(for: $0) }
    }

    private func resolvedURL(for path: String) -> URL {
        URL(fileURLWithPath: "/resolved/\(path)")
    }
}
