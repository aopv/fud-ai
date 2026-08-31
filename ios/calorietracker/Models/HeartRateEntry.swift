import Foundation

enum HeartRateSource: String, Codable, CaseIterable, Sendable {
    case camera
    case manual

    var displayName: String {
        switch self {
        case .camera:
            String(localized: "Camera")
        case .manual:
            String(localized: "Manual")
        }
    }
}

/// A single wellness-oriented spot heart-rate reading. Camera frames and the
/// raw pulse waveform are deliberately never part of this persisted model.
struct HeartRateEntry: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let date: Date
    let bpm: Int
    let source: HeartRateSource
    /// Optional normalized confidence from 0...1 for camera measurements.
    /// Manual entries intentionally leave this nil.
    let quality: Double?

    init(
        id: UUID = UUID(),
        date: Date = .now,
        bpm: Int,
        source: HeartRateSource,
        quality: Double? = nil
    ) {
        self.id = id
        self.date = date
        self.bpm = bpm
        self.source = source
        self.quality = quality.map { min(max($0, 0), 1) }
    }
}
