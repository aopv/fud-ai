import CryptoKit
import Foundation
import Testing
@testable import calorietracker

@MainActor
struct WhisperBaseModelManagerTests {
    @Test func modelRuntimeAndTokenizerDownloadsAreRevisionPinned() {
        #expect(WhisperBaseModelManager.modelRepository == "argmaxinc/whisperkit-coreml")
        #expect(WhisperBaseModelManager.modelRevision == "0f63a7800b00dd0226abd051b906c246e1907482")
        #expect(WhisperBaseModelManager.modelDownloadPattern == "openai_whisper-base/*")
        #expect(WhisperBaseModelManager.tokenizerRepository == "openai/whisper-base")
        #expect(WhisperBaseModelManager.tokenizerRevision == "e37978b90ca9030d5170a5c07aadb050351a65bb")
        #expect(WhisperBaseModelManager.whisperKitRevision == "1e2a163736dfa5a198e637ae44c114e1c6d5cc2d")
        #expect(WhisperBaseModelManager.modelSourceURL.absoluteString.contains(WhisperBaseModelManager.modelRevision))
        #expect(WhisperBaseModelManager.modelLicenseURL.absoluteString.contains("5f86d1d86363843179951550570367b37c5d6f78"))
        #expect(WhisperBaseModelManager.whisperKitSourceURL.absoluteString.contains(WhisperBaseModelManager.whisperKitRevision))
        #expect(WhisperBaseModelManager.whisperKitLicenseURL.absoluteString.contains(WhisperBaseModelManager.whisperKitRevision))
        #expect(WhisperBaseModelManager.preparedMarkerContents.contains(WhisperBaseModelManager.modelRevision))
        #expect(WhisperBaseModelManager.preparedMarkerContents.contains(WhisperBaseModelManager.tokenizerRevision))
    }

    @Test func completeModelRequiresAllThreeCoreMLComponents() throws {
        let root = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        #expect(!WhisperBaseModelManager.hasCompleteModel(
            at: root,
            fileManager: .default
        ))

        for component in ["AudioEncoder.mlmodelc", "MelSpectrogram.mlmodelc"] {
            try FileManager.default.createDirectory(
                at: root.appendingPathComponent(component, isDirectory: true),
                withIntermediateDirectories: true
            )
        }
        #expect(!WhisperBaseModelManager.hasCompleteModel(
            at: root,
            fileManager: .default
        ))

        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("TextDecoder.mlmodelc", isDirectory: true),
            withIntermediateDirectories: true
        )
        #expect(WhisperBaseModelManager.hasCompleteModel(
            at: root,
            fileManager: .default
        ))
    }

    @Test func selectableInstallRequiresSuccessfulRuntimeMarker() throws {
        let root = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let model = root.appendingPathComponent("model", isDirectory: true)
        let marker = root.appendingPathComponent("prepared.version")

        for component in ["AudioEncoder.mlmodelc", "MelSpectrogram.mlmodelc", "TextDecoder.mlmodelc"] {
            try FileManager.default.createDirectory(
                at: model.appendingPathComponent(component, isDirectory: true),
                withIntermediateDirectories: true
            )
        }

        #expect(!WhisperBaseModelManager.hasCompleteInstall(
            modelDirectory: model,
            preparedMarkerURL: marker,
            fileManager: .default
        ))

        try Data(WhisperBaseModelManager.preparedMarkerContents.utf8).write(to: marker)
        #expect(WhisperBaseModelManager.hasCompleteInstall(
            modelDirectory: model,
            preparedMarkerURL: marker,
            fileManager: .default
        ))
    }

    @Test func directorySizeCountsNestedModelFiles() throws {
        let root = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let nested = root.appendingPathComponent("AudioEncoder.mlmodelc", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try Data(repeating: 0x2A, count: 4_096).write(
            to: nested.appendingPathComponent("weights.bin")
        )

        #expect(WhisperBaseModelManager.directorySize(
            at: root,
            fileManager: .default
        ) >= 4_096)
    }

    @Test func deletionRemovesOnlyTheDedicatedModelRoot() throws {
        let parent = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: parent) }

        let modelRoot = parent.appendingPathComponent("WhisperBase", isDirectory: true)
        let sibling = parent.appendingPathComponent("keep.txt")
        try FileManager.default.createDirectory(at: modelRoot, withIntermediateDirectories: true)
        try Data([0x01]).write(to: modelRoot.appendingPathComponent("partial.bin"))
        try Data([0x02]).write(to: sibling)

        let manager = WhisperBaseModelManager(rootDirectory: modelRoot)
        #expect(manager.hasStoredData)

        try manager.delete()

        #expect(!FileManager.default.fileExists(atPath: modelRoot.path))
        #expect(FileManager.default.fileExists(atPath: sibling.path))
        #expect(manager.state == .notDownloaded)
    }

    @Test func cancellingOutsideAnActiveDownloadNeverDeletesStoredData() throws {
        let root = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let storedFile = root.appendingPathComponent("keep.partial")
        try Data([0x01]).write(to: storedFile)
        let manager = WhisperBaseModelManager(rootDirectory: root)

        manager.cancelDownload()

        #expect(FileManager.default.fileExists(atPath: storedFile.path))
        #expect(manager.hasStoredData)
    }

    @Test func bundledNoticesAreAvailableOfflineAndMatchTheAuditedFile() throws {
        let url = try #require(WhisperBaseNoticesView.noticesURL(in: .main))
        let data = try Data(contentsOf: url)

        #expect(data.count == 25_788)
        #expect(Self.sha256(data) == "d414ae53d7797aeaf420cf17b4f905e0833578a700746ffce5a7018ba1fbd715")
    }

    private static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func makeTemporaryDirectory() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("WhisperBaseModelManagerTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
