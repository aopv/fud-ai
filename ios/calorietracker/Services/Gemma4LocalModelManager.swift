import CryptoKit
import Foundation
import LiteRTLM
import Observation

@MainActor
@Observable
final class Gemma4LocalModelManager {
    struct ChatTurn: Sendable {
        enum Role: Sendable {
            case user
            case assistant
        }

        let role: Role
        let text: String
    }

    enum InstallState: Equatable {
        case notDownloaded
        case downloaded
        case downloading(Double)
        case verifying
        case preparing
        case ready
        case generating
        case failed(String)

        var isBusy: Bool {
            switch self {
            case .downloading, .verifying, .preparing, .generating:
                true
            case .notDownloaded, .downloaded, .ready, .failed:
                false
            }
        }
    }

    enum LocalModelError: LocalizedError {
        case unsupportedDevice
        case notDownloaded
        case busy
        case insufficientStorage(required: Int64, available: Int64)
        case storageCapacityUnavailable
        case invalidDownload(String)
        case emptyResponse

        var errorDescription: String? {
            switch self {
            case .unsupportedDevice:
                LocalModelStrings.text(
                    "gemma.error.unsupportedDevice",
                    defaultValue: "Gemma 4 requires an iPhone with at least 8 GB of memory."
                )
            case .notDownloaded:
                LocalModelStrings.text(
                    "gemma.error.notDownloaded",
                    defaultValue: "Gemma 4 is not downloaded. Download it in Settings → AI Providers."
                )
            case .busy:
                LocalModelStrings.text(
                    "gemma.error.busy",
                    defaultValue: "Gemma 4 is already busy. Please wait for the current operation to finish."
                )
            case .insufficientStorage(let required, let available):
                LocalModelStrings.format(
                    "gemma.error.insufficientStorage",
                    defaultValue: "Gemma 4 needs %@ free, including installation headroom. This iPhone currently has %@ available.",
                    Self.fileSize(required),
                    Self.fileSize(available)
                )
            case .storageCapacityUnavailable:
                LocalModelStrings.text(
                    "gemma.error.storageCapacityUnavailable",
                    defaultValue: "Available storage could not be checked, so the large model download was not started."
                )
            case .invalidDownload(let reason):
                LocalModelStrings.format(
                    "gemma.error.invalidDownload",
                    defaultValue: "The Gemma 4 download could not be verified (%@). Please try again.",
                    reason
                )
            case .emptyResponse:
                LocalModelStrings.text(
                    "gemma.error.emptyResponse",
                    defaultValue: "Gemma 4 returned an empty response. Please try again."
                )
            }
        }

        private static func fileSize(_ bytes: Int64) -> String {
            ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
        }
    }

    struct ArtifactVerification: Equatable, Sendable {
        let byteCount: Int64
        let sha256: String
    }

    static let shared = Gemma4LocalModelManager()

    nonisolated static let minimumMemoryClassGB: UInt64 = 8
    nonisolated static let minimumPhysicalMemoryBytes: UInt64 = 8 * 1_024 * 1_024 * 1_024
    nonisolated static let maxContextTokens = 4_096
    nonisolated static let artifactByteCount: Int64 = 2_588_147_712
    nonisolated static let installationHeadroomBytes: Int64 = 1_024 * 1_024 * 1_024
    nonisolated static let artifactSHA256 = "181938105e0eefd105961417e8da75903eacda102c4fce9ce90f50b97139a63c"
    nonisolated static let artifactFilename = "gemma-4-E2B-it.litertlm"
    nonisolated static let modelID = "gemma-4-E2B-it"
    nonisolated static let preparedMarkerContents = "LiteRTLM-0.16.0-\(artifactSHA256)"
    nonisolated static let sourceRevision = "6b78abd019e61a1ca4cbe3b212d2c9ce8ff38a94"
    nonisolated static let sourceURL = URL(
        string: "https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/tree/6b78abd019e61a1ca4cbe3b212d2c9ce8ff38a94"
    )!
    nonisolated static let licenseURL = URL(string: "https://ai.google.dev/gemma/apache_2")!
    nonisolated static let artifactURL = URL(
        string: "https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/6b78abd019e61a1ca4cbe3b212d2c9ce8ff38a94/gemma-4-E2B-it.litertlm"
    )!

    static var isCurrentDeviceEligible: Bool {
        isEligible(physicalMemoryBytes: ProcessInfo.processInfo.physicalMemory)
    }

    static var isCurrentDeviceSelectable: Bool {
        guard isCurrentDeviceEligible else { return false }
        let fileManager = FileManager.default
        let root = defaultRootDirectory(fileManager: fileManager)
        return hasPreparedInstall(
            modelURL: root.appendingPathComponent(artifactFilename),
            verificationMarkerURL: root.appendingPathComponent("verified.sha256"),
            preparedMarkerURL: root.appendingPathComponent("prepared.version"),
            expectedByteCount: artifactByteCount,
            expectedSHA256: artifactSHA256,
            fileManager: fileManager
        )
    }

    private(set) var state: InstallState = .notDownloaded
    private(set) var installedByteCount: Int64 = 0

    @ObservationIgnored private let fileManager: FileManager
    @ObservationIgnored private let rootDirectory: URL
    @ObservationIgnored private let physicalMemoryBytes: UInt64
    @ObservationIgnored private var engine: Engine?
    @ObservationIgnored private var activeDownload: GemmaArtifactDownloadOperation?

    init(
        rootDirectory: URL? = nil,
        physicalMemoryBytes: UInt64 = ProcessInfo.processInfo.physicalMemory,
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        self.rootDirectory = rootDirectory ?? Self.defaultRootDirectory(fileManager: fileManager)
        self.physicalMemoryBytes = physicalMemoryBytes
        refresh()
    }

    var isEligible: Bool {
        Self.isEligible(physicalMemoryBytes: physicalMemoryBytes)
    }

    var isDownloaded: Bool {
        Self.hasVerifiedInstall(
            modelURL: modelURL,
            verificationMarkerURL: verificationMarkerURL,
            expectedByteCount: Self.artifactByteCount,
            expectedSHA256: Self.artifactSHA256,
            fileManager: fileManager
        )
    }

    var isSelectable: Bool {
        isEligible && Self.hasPreparedInstall(
            modelURL: modelURL,
            verificationMarkerURL: verificationMarkerURL,
            preparedMarkerURL: preparedMarkerURL,
            expectedByteCount: Self.artifactByteCount,
            expectedSHA256: Self.artifactSHA256,
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
        guard !state.isBusy else { return }
        guard isEligible else {
            state = .failed(LocalModelError.unsupportedDevice.localizedDescription)
            return
        }
        guard !isDownloaded else {
            state = .downloaded
            return
        }

        do {
            try prepareRootDirectory()
            try removeUnverifiedArtifacts()
            try requireDownloadHeadroom()

            state = .downloading(0)
            let download = GemmaArtifactDownloadOperation(
                destinationURL: partialModelURL,
                fileManager: fileManager
            ) { [weak self] progress in
                Task { @MainActor [weak self] in
                    guard let self, case .downloading = self.state else { return }
                    self.state = .downloading(progress)
                }
            }
            activeDownload = download
            try await download.start(url: Self.artifactURL)
            activeDownload = nil

            state = .verifying
            let partialURL = partialModelURL
            let verification = try await Task.detached(priority: .utility) {
                try Self.verifyArtifact(at: partialURL)
            }.value
            guard verification.byteCount == Self.artifactByteCount else {
                throw LocalModelError.invalidDownload(
                    LocalModelStrings.format(
                        "gemma.verification.wrongSize",
                        defaultValue: "expected %@ bytes, received %@",
                        String(Self.artifactByteCount),
                        String(verification.byteCount)
                    )
                )
            }
            guard verification.sha256 == Self.artifactSHA256 else {
                throw LocalModelError.invalidDownload(LocalModelStrings.text(
                    "gemma.verification.hashMismatch",
                    defaultValue: "SHA-256 mismatch"
                ))
            }

            try fileManager.moveItem(at: partialModelURL, to: modelURL)
            try Data(Self.artifactSHA256.utf8).write(to: verificationMarkerURL, options: .atomic)
            installedByteCount = Self.directorySize(at: rootDirectory, fileManager: fileManager)

            _ = try await ensureEngine()
            state = .ready
        } catch {
            activeDownload = nil
            try? fileManager.removeItem(at: partialModelURL)
            if !isDownloaded, fileManager.fileExists(atPath: rootDirectory.path) {
                try? fileManager.removeItem(at: rootDirectory)
            }
            installedByteCount = Self.directorySize(at: rootDirectory, fileManager: fileManager)
            if Task.isCancelled || Self.isCancellation(error) {
                state = isDownloaded ? .downloaded : .notDownloaded
            } else {
                state = .failed(Self.errorMessage(for: error))
            }
        }
    }

    func prepare() async {
        guard !state.isBusy else { return }
        do {
            _ = try await ensureEngine()
            state = .ready
        } catch {
            state = .failed(Self.errorMessage(for: error))
        }
    }

    func cancelDownload() {
        guard case .downloading = state else { return }
        activeDownload?.cancel()
    }

    func delete() throws {
        guard !state.isBusy else { throw LocalModelError.busy }
        activeDownload?.cancel()
        activeDownload = nil
        engine = nil
        if fileManager.fileExists(atPath: rootDirectory.path) {
            try fileManager.removeItem(at: rootDirectory)
        }
        installedByteCount = 0
        state = .notDownloaded
    }

    func generate(
        prompt: String,
        images: [Data] = [],
        systemPrompt: String? = nil,
        history: [ChatTurn] = [],
        maxOutputTokens: Int = 1_024
    ) async throws -> String {
        guard !state.isBusy else { throw LocalModelError.busy }
        guard isEligible else { throw LocalModelError.unsupportedDevice }
        guard isDownloaded else { throw LocalModelError.notDownloaded }

        let loadedEngine: Engine
        do {
            loadedEngine = try await ensureEngine()
        } catch {
            state = .failed(Self.errorMessage(for: error))
            throw error
        }

        state = .generating
        do {
            let initialMessages = history.suffix(8).map { turn in
                Message(turn.text, role: turn.role == .user ? .user : .model)
            }
            let conversationConfig = ConversationConfig(
                systemMessage: systemPrompt.map { Message($0) },
                initialMessages: initialMessages,
                thinkingConfig: ThinkingConfig(enableThinking: false)
            )
            let conversation = try await loadedEngine.createConversation(with: conversationConfig)
            let contents = images.map(Content.imageData) + [.text(prompt)]
            let response = try await conversation.sendMessage(
                Message(contents: contents),
                maxOutputTokens: max(1, min(maxOutputTokens, 4_096)),
                thinkingConfig: ThinkingConfig(enableThinking: false)
            )
            let text = response.toString.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { throw LocalModelError.emptyResponse }
            state = .ready
            return text
        } catch {
            state = .failed(Self.errorMessage(for: error))
            throw error
        }
    }

    nonisolated static func isEligible(physicalMemoryBytes: UInt64) -> Bool {
        memoryClassGB(physicalMemoryBytes: physicalMemoryBytes) >= minimumMemoryClassGB
    }

    /// iOS can report slightly less memory than the phone's marketed RAM because
    /// part of physical memory is reserved by the system. Round the reported GiB
    /// upward so an 8 GB device remains in the 8 GB eligibility class.
    nonisolated static func memoryClassGB(physicalMemoryBytes: UInt64) -> UInt64 {
        let wholeGiB = physicalMemoryBytes / (1_024 * 1_024 * 1_024)
        let hasPartialGiB = physicalMemoryBytes % (1_024 * 1_024 * 1_024) != 0
        return wholeGiB + (hasPartialGiB ? 1 : 0)
    }

    nonisolated static func hasRequiredStorage(
        availableBytes: Int64,
        artifactBytes: Int64 = artifactByteCount,
        headroomBytes: Int64 = installationHeadroomBytes
    ) -> Bool {
        guard artifactBytes >= 0, headroomBytes >= 0,
              artifactBytes <= Int64.max - headroomBytes else {
            return false
        }
        return availableBytes >= artifactBytes + headroomBytes
    }

    nonisolated static func hasVerifiedInstall(
        modelURL: URL,
        verificationMarkerURL: URL,
        expectedByteCount: Int64,
        expectedSHA256: String,
        fileManager: FileManager
    ) -> Bool {
        guard let attributes = try? fileManager.attributesOfItem(atPath: modelURL.path),
              let byteCount = (attributes[.size] as? NSNumber)?.int64Value,
              byteCount == expectedByteCount,
              let markerData = try? Data(contentsOf: verificationMarkerURL),
              let marker = String(data: markerData, encoding: .utf8) else {
            return false
        }
        return marker.trimmingCharacters(in: .whitespacesAndNewlines) == expectedSHA256
    }

    nonisolated static func hasPreparedInstall(
        modelURL: URL,
        verificationMarkerURL: URL,
        preparedMarkerURL: URL,
        expectedByteCount: Int64,
        expectedSHA256: String,
        fileManager: FileManager
    ) -> Bool {
        guard hasVerifiedInstall(
            modelURL: modelURL,
            verificationMarkerURL: verificationMarkerURL,
            expectedByteCount: expectedByteCount,
            expectedSHA256: expectedSHA256,
            fileManager: fileManager
        ), let markerData = try? Data(contentsOf: preparedMarkerURL),
           let marker = String(data: markerData, encoding: .utf8) else {
            return false
        }
        return marker.trimmingCharacters(in: .whitespacesAndNewlines) == preparedMarkerContents
    }

    nonisolated static func verifyArtifact(
        at fileURL: URL,
        chunkSize: Int = 4 * 1_024 * 1_024
    ) throws -> ArtifactVerification {
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }

        var hasher = SHA256()
        var byteCount: Int64 = 0
        while true {
            try Task.checkCancellation()
            guard let data = try handle.read(upToCount: chunkSize), !data.isEmpty else { break }
            byteCount += Int64(data.count)
            hasher.update(data: data)
        }

        let digest = hasher.finalize().map { String(format: "%02x", $0) }.joined()
        return ArtifactVerification(byteCount: byteCount, sha256: digest)
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

    private var modelURL: URL {
        rootDirectory.appendingPathComponent(Self.artifactFilename)
    }

    private var partialModelURL: URL {
        rootDirectory.appendingPathComponent("\(Self.artifactFilename).partial")
    }

    private var verificationMarkerURL: URL {
        rootDirectory.appendingPathComponent("verified.sha256")
    }

    private var preparedMarkerURL: URL {
        rootDirectory.appendingPathComponent("prepared.version")
    }

    private var cacheDirectory: URL {
        rootDirectory.appendingPathComponent("Cache", isDirectory: true)
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
            .appendingPathComponent("Gemma4E2B", isDirectory: true)
    }

    private func prepareRootDirectory() throws {
        try fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutableRoot = rootDirectory
        try mutableRoot.setResourceValues(values)
    }

    private func removeUnverifiedArtifacts() throws {
        for url in [partialModelURL, modelURL, verificationMarkerURL, preparedMarkerURL]
        where fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    private func requireDownloadHeadroom() throws {
        let values = try rootDirectory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        guard let available = values.volumeAvailableCapacityForImportantUsage else {
            throw LocalModelError.storageCapacityUnavailable
        }
        guard Self.hasRequiredStorage(availableBytes: available) else {
            throw LocalModelError.insufficientStorage(
                required: Self.artifactByteCount + Self.installationHeadroomBytes,
                available: available
            )
        }
    }

    private func ensureEngine() async throws -> Engine {
        guard isEligible else { throw LocalModelError.unsupportedDevice }
        guard isDownloaded else { throw LocalModelError.notDownloaded }
        if let engine { return engine }

        state = .preparing
        do {
            let loadedEngine: Engine
            let gpuCache = cacheDirectory.appendingPathComponent("GPU", isDirectory: true)
            try fileManager.createDirectory(at: gpuCache, withIntermediateDirectories: true)
            let gpuConfig = try EngineConfig(
                modelPath: modelURL.path,
                backend: .gpu,
                visionBackend: .gpu,
                maxNumTokens: Self.maxContextTokens,
                cacheDir: gpuCache.path
            )
            let gpuEngine = Engine(engineConfig: gpuConfig)
            do {
                try await gpuEngine.initialize()
                loadedEngine = gpuEngine
            } catch {
                // LiteRT-LM's documented multimodal path prefers Metal on iOS. Some
                // devices/runtime combinations reject GPU engine creation, so retry
                // once with an isolated XNNPACK cache before surfacing the error.
                let cpuCache = cacheDirectory.appendingPathComponent("CPU", isDirectory: true)
                try fileManager.createDirectory(at: cpuCache, withIntermediateDirectories: true)
                let cpuConfig = try EngineConfig(
                    modelPath: modelURL.path,
                    backend: .cpu(),
                    visionBackend: .cpu(),
                    maxNumTokens: Self.maxContextTokens,
                    cacheDir: cpuCache.path
                )
                let cpuEngine = Engine(engineConfig: cpuConfig)
                try await cpuEngine.initialize()
                loadedEngine = cpuEngine
            }

            try Data(Self.preparedMarkerContents.utf8).write(to: preparedMarkerURL, options: .atomic)
            engine = loadedEngine
            state = .ready
            return loadedEngine
        } catch {
            try? fileManager.removeItem(at: preparedMarkerURL)
            throw error
        }
    }

    private static func errorMessage(for error: Error) -> String {
        if let localized = error as? LocalizedError,
           let description = localized.errorDescription {
            return description
        }
        return error.localizedDescription
    }

    private static func isCancellation(_ error: Error) -> Bool {
        error is CancellationError || (error as? URLError)?.code == .cancelled
    }
}

private final class GemmaArtifactDownloadOperation: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    enum DownloadError: LocalizedError {
        case invalidHTTPResponse
        case httpStatus(Int)
        case missingDownloadedFile

        var errorDescription: String? {
            switch self {
            case .invalidHTTPResponse:
                LocalModelStrings.text(
                    "gemma.download.invalidHTTPResponse",
                    defaultValue: "The model server returned an invalid response."
                )
            case .httpStatus(let status):
                LocalModelStrings.format(
                    "gemma.download.httpStatus",
                    defaultValue: "The model server returned HTTP %@.",
                    String(status)
                )
            case .missingDownloadedFile:
                LocalModelStrings.text(
                    "gemma.download.missingFile",
                    defaultValue: "The model download completed without a file."
                )
            }
        }
    }

    private let destinationURL: URL
    private let fileManager: FileManager
    private let progressHandler: @Sendable (Double) -> Void
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Error>?
    private var session: URLSession?
    private var task: URLSessionDownloadTask?
    private var movedDownloadedFile = false

    init(
        destinationURL: URL,
        fileManager: FileManager,
        progressHandler: @escaping @Sendable (Double) -> Void
    ) {
        self.destinationURL = destinationURL
        self.fileManager = fileManager
        self.progressHandler = progressHandler
    }

    func start(url: URL) async throws {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let configuration = URLSessionConfiguration.ephemeral
                configuration.timeoutIntervalForRequest = 120
                configuration.timeoutIntervalForResource = 6 * 60 * 60
                configuration.waitsForConnectivity = true

                let delegateQueue = OperationQueue()
                delegateQueue.name = "app.fud-ai.gemma-download"
                delegateQueue.maxConcurrentOperationCount = 1

                let session = URLSession(
                    configuration: configuration,
                    delegate: self,
                    delegateQueue: delegateQueue
                )
                let task = session.downloadTask(with: url)

                lock.lock()
                self.continuation = continuation
                self.session = session
                self.task = task
                lock.unlock()

                task.resume()
                if Task.isCancelled { cancel() }
            }
        } onCancel: {
            self.cancel()
        }
    }

    func cancel() {
        lock.lock()
        let task = task
        lock.unlock()
        task?.cancel()
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let progress = min(1, max(0, Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)))
        progressHandler(progress)
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        do {
            guard let response = downloadTask.response as? HTTPURLResponse else {
                throw DownloadError.invalidHTTPResponse
            }
            guard (200..<300).contains(response.statusCode) else {
                throw DownloadError.httpStatus(response.statusCode)
            }
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.moveItem(at: location, to: destinationURL)
            lock.lock()
            movedDownloadedFile = true
            lock.unlock()
        } catch {
            complete(.failure(error))
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        if let error {
            complete(.failure(error))
            return
        }

        lock.lock()
        let movedDownloadedFile = movedDownloadedFile
        lock.unlock()
        complete(movedDownloadedFile ? .success(()) : .failure(DownloadError.missingDownloadedFile))
    }

    private func complete(_ result: Result<Void, Error>) {
        lock.lock()
        let continuation = continuation
        let session = session
        self.continuation = nil
        self.session = nil
        task = nil
        lock.unlock()

        guard let continuation else { return }
        session?.finishTasksAndInvalidate()
        continuation.resume(with: result)
    }
}
