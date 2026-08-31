import Foundation
import Observation
import WhisperKit

@MainActor
@Observable
final class WhisperBaseModelManager {
    enum InstallState: Equatable {
        case notDownloaded
        case downloaded
        case downloading(Double)
        case preparing
        case ready
        case transcribing
        case failed(String)

        var isBusy: Bool {
            switch self {
            case .downloading, .preparing, .transcribing:
                true
            case .notDownloaded, .downloaded, .ready, .failed:
                false
            }
        }
    }

    enum LocalModelError: LocalizedError {
        case notDownloaded
        case busy
        case emptyTranscript

        var errorDescription: String? {
            switch self {
            case .notDownloaded:
                LocalModelStrings.text(
                    "whisper.error.notDownloaded",
                    defaultValue: "Whisper Base is not downloaded. Download it in Settings → Speech-to-Text."
                )
            case .busy:
                LocalModelStrings.text(
                    "whisper.error.busy",
                    defaultValue: "Whisper Base is already busy. Please wait for the current operation to finish."
                )
            case .emptyTranscript:
                LocalModelStrings.text(
                    "whisper.error.emptyTranscript",
                    defaultValue: "Whisper Base could not detect any speech in this recording."
                )
            }
        }
    }

    static let shared = WhisperBaseModelManager()
    nonisolated static let variant = "base"
    nonisolated static let approximateDownloadBytes: Int64 = 147_000_000
    nonisolated static let modelRepository = "argmaxinc/whisperkit-coreml"
    nonisolated static let modelRevision = "0f63a7800b00dd0226abd051b906c246e1907482"
    nonisolated static let modelDirectoryName = "openai_whisper-base"
    nonisolated static let modelDownloadPattern = "\(modelDirectoryName)/*"
    nonisolated static let tokenizerRepository = "openai/whisper-base"
    nonisolated static let tokenizerRevision = "e37978b90ca9030d5170a5c07aadb050351a65bb"
    nonisolated static let tokenizerDownloadPatterns = [
        "config.json",
        "tokenizer.json",
        "tokenizer_config.json",
    ]
    nonisolated static let whisperKitRevision = "1e2a163736dfa5a198e637ae44c114e1c6d5cc2d"
    nonisolated static let preparedMarkerContents = "WhisperKit-1.1.0-\(modelRevision)-\(tokenizerRevision)"
    nonisolated static let modelSourceURL = URL(
        string: "https://huggingface.co/argmaxinc/whisperkit-coreml/tree/0f63a7800b00dd0226abd051b906c246e1907482/openai_whisper-base"
    )!
    nonisolated static let modelLicenseURL = URL(
        string: "https://github.com/openai/whisper/blob/5f86d1d86363843179951550570367b37c5d6f78/LICENSE"
    )!
    nonisolated static let whisperKitSourceURL = URL(
        string: "https://github.com/argmaxinc/argmax-oss-swift/tree/1e2a163736dfa5a198e637ae44c114e1c6d5cc2d"
    )!
    nonisolated static let whisperKitLicenseURL = URL(
        string: "https://github.com/argmaxinc/argmax-oss-swift/blob/1e2a163736dfa5a198e637ae44c114e1c6d5cc2d/LICENSE"
    )!

    static var isCurrentDeviceSelectable: Bool {
        let fileManager = FileManager.default
        let root = defaultRootDirectory(fileManager: fileManager)
        let modelDirectory = root
            .appendingPathComponent("models", isDirectory: true)
            .appendingPathComponent("argmaxinc", isDirectory: true)
            .appendingPathComponent("whisperkit-coreml", isDirectory: true)
            .appendingPathComponent(modelDirectoryName, isDirectory: true)
        return hasCompleteInstall(
            modelDirectory: modelDirectory,
            preparedMarkerURL: root.appendingPathComponent("prepared.version"),
            fileManager: fileManager
        )
    }

    private(set) var state: InstallState = .notDownloaded
    private(set) var installedByteCount: Int64 = 0

    @ObservationIgnored private let fileManager: FileManager
    @ObservationIgnored private let rootDirectory: URL
    @ObservationIgnored private var runtime: WhisperKit?
    @ObservationIgnored private var activeDownloadTask: Task<Void, Never>?

    init(
        rootDirectory: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        self.rootDirectory = rootDirectory ?? Self.defaultRootDirectory(fileManager: fileManager)
        refresh()
    }

    var isDownloaded: Bool {
        Self.hasCompleteInstall(
            modelDirectory: modelDirectory,
            preparedMarkerURL: preparedMarkerURL,
            fileManager: fileManager
        )
    }

    var hasStoredData: Bool {
        installedByteCount > 0 || fileManager.fileExists(atPath: rootDirectory.path)
    }

    var downloadProgress: Double? {
        guard case .downloading(let progress) = state else { return nil }
        return progress
    }

    var installedSizeDescription: String? {
        guard installedByteCount > 0 else { return nil }
        return ByteCountFormatter.string(fromByteCount: installedByteCount, countStyle: .file)
    }

    func refresh() {
        guard !state.isBusy else { return }
        installedByteCount = Self.directorySize(at: rootDirectory, fileManager: fileManager)
        state = isDownloaded ? .downloaded : .notDownloaded
    }

    func download() async {
        guard activeDownloadTask == nil, !state.isBusy else { return }
        guard !isDownloaded else {
            state = .downloaded
            return
        }

        state = .downloading(0)
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.performDownload()
        }
        activeDownloadTask = task
        await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
        activeDownloadTask = nil
    }

    func cancelDownload() {
        guard case .downloading = state else { return }
        activeDownloadTask?.cancel()
    }

    private func performDownload() async {
        do {
            try Task.checkCancellation()
            try prepareRootDirectory()

            let modelDownloader = ModelDownloader(config: ModelDownloadConfig(
                downloadBase: rootDirectory.path,
                modelRepo: Self.modelRepository,
                revision: Self.modelRevision
            ))
            let snapshotRoot = try await modelDownloader.resolveRepo(
                patterns: [Self.modelDownloadPattern],
                downloadBase: rootDirectory,
                progressCallback: { [weak self] progress in
                    Task { @MainActor [weak self] in
                        guard let self, case .downloading = self.state else { return }
                        self.state = .downloading(progress.fractionCompleted)
                    }
                }
            )
            try Task.checkCancellation()
            let folder = snapshotRoot.appendingPathComponent(Self.modelDirectoryName, isDirectory: true)
            guard Self.hasCompleteModel(at: folder, fileManager: fileManager) else {
                throw LocalModelError.notDownloaded
            }

            let tokenizerDownloader = ModelDownloader(config: ModelDownloadConfig(
                downloadBase: rootDirectory.path,
                modelRepo: Self.tokenizerRepository,
                revision: Self.tokenizerRevision
            ))
            _ = try await tokenizerDownloader.resolveRepo(
                patterns: Self.tokenizerDownloadPatterns,
                downloadBase: rootDirectory
            )
            try Task.checkCancellation()

            state = .preparing
            runtime = try await makeRuntime(modelFolder: folder)
            try Task.checkCancellation()
            try Data(Self.preparedMarkerContents.utf8).write(
                to: preparedMarkerURL,
                options: .atomic
            )
            installedByteCount = Self.directorySize(at: rootDirectory, fileManager: fileManager)
            state = .ready
        } catch {
            cleanupIncompleteDownload()
            state = Task.isCancelled
                ? .notDownloaded
                : .failed(Self.errorMessage(for: error))
        }
    }

    func delete() throws {
        guard !state.isBusy else { throw LocalModelError.busy }
        runtime = nil
        if fileManager.fileExists(atPath: rootDirectory.path) {
            try fileManager.removeItem(at: rootDirectory)
        }
        installedByteCount = 0
        state = .notDownloaded
    }

    func transcribe(audioURL: URL, languageCode: String?) async throws -> String {
        guard !state.isBusy else { throw LocalModelError.busy }
        guard isDownloaded else { throw LocalModelError.notDownloaded }

        let whisper: WhisperKit
        do {
            whisper = try await ensureRuntime()
        } catch {
            state = .failed(Self.errorMessage(for: error))
            throw error
        }

        state = .transcribing
        do {
            let options = DecodingOptions(
                language: languageCode,
                detectLanguage: languageCode == nil
            )
            let results = try await whisper.transcribe(
                audioPath: audioURL.path,
                decodeOptions: options
            )
            let transcript = results
                .map(\.text)
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !transcript.isEmpty else { throw LocalModelError.emptyTranscript }
            state = .ready
            return transcript
        } catch {
            state = .failed(Self.errorMessage(for: error))
            throw error
        }
    }

    nonisolated static func hasCompleteInstall(
        modelDirectory: URL,
        preparedMarkerURL: URL,
        fileManager: FileManager
    ) -> Bool {
        guard hasCompleteModel(at: modelDirectory, fileManager: fileManager),
              let markerData = try? Data(contentsOf: preparedMarkerURL),
              let marker = String(data: markerData, encoding: .utf8) else {
            return false
        }
        return marker.trimmingCharacters(in: .whitespacesAndNewlines) == preparedMarkerContents
    }

    nonisolated static func hasCompleteModel(at modelDirectory: URL, fileManager: FileManager) -> Bool {
        ["AudioEncoder.mlmodelc", "MelSpectrogram.mlmodelc", "TextDecoder.mlmodelc"]
            .allSatisfy { component in
                fileManager.fileExists(
                    atPath: modelDirectory.appendingPathComponent(component, isDirectory: true).path
                )
            }
    }

    nonisolated static func directorySize(at directory: URL, fileManager: FileManager) -> Int64 {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .fileAllocatedSizeKey, .fileSizeKey]
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: keys),
                  values.isRegularFile == true else {
                continue
            }
            total += Int64(values.fileAllocatedSize ?? values.fileSize ?? 0)
        }
        return total
    }

    private var modelDirectory: URL {
        rootDirectory
            .appendingPathComponent("models", isDirectory: true)
            .appendingPathComponent("argmaxinc", isDirectory: true)
            .appendingPathComponent("whisperkit-coreml", isDirectory: true)
            .appendingPathComponent(Self.modelDirectoryName, isDirectory: true)
    }

    private var preparedMarkerURL: URL {
        rootDirectory.appendingPathComponent("prepared.version")
    }

    private static func defaultRootDirectory(fileManager: FileManager) -> URL {
        let applicationSupport = (try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? fileManager.temporaryDirectory

        return applicationSupport
            .appendingPathComponent("FudAI", isDirectory: true)
            .appendingPathComponent("LocalModels", isDirectory: true)
            .appendingPathComponent("WhisperBase", isDirectory: true)
    }

    private func prepareRootDirectory() throws {
        try fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutableRoot = rootDirectory
        try mutableRoot.setResourceValues(values)
    }

    private func ensureRuntime() async throws -> WhisperKit {
        if let runtime { return runtime }
        state = .preparing
        let loadedRuntime = try await makeRuntime(modelFolder: modelDirectory)
        runtime = loadedRuntime
        state = .ready
        return loadedRuntime
    }

    private func makeRuntime(modelFolder: URL) async throws -> WhisperKit {
        try await WhisperKit(WhisperKitConfig(
            model: Self.variant,
            downloadBase: rootDirectory,
            modelFolder: modelFolder.path,
            tokenizerFolder: rootDirectory,
            verbose: false,
            prewarm: true,
            load: true,
            download: false
        ))
    }

    private func cleanupIncompleteDownload() {
        runtime = nil
        if !isDownloaded, fileManager.fileExists(atPath: rootDirectory.path) {
            try? fileManager.removeItem(at: rootDirectory)
        }
        installedByteCount = Self.directorySize(at: rootDirectory, fileManager: fileManager)
    }

    private static func errorMessage(for error: Error) -> String {
        if let localized = error as? LocalizedError,
           let description = localized.errorDescription {
            return description
        }
        return error.localizedDescription
    }
}
