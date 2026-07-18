import Foundation
import SwiftUI

/// Local-only persistence and history queries for the optional strength logger.
/// No workout data is sent to HealthKit, a backend, or a cloud service.
@Observable
final class StrengthWorkoutStore {
    private(set) var sessions: [StrengthWorkoutSession] = []

    static let defaultStorageKey = "strengthWorkoutSessions"

    private let userDefaults: UserDefaults
    private let storageKey: String

    init(
        userDefaults: UserDefaults = .standard,
        storageKey: String = StrengthWorkoutStore.defaultStorageKey
    ) {
        self.userDefaults = userDefaults
        self.storageKey = storageKey
        loadSessions()
    }

    /// Newest-first sessions for the logger's history screen.
    var sortedSessions: [StrengthWorkoutSession] {
        sessions.sorted { lhs, rhs in
            if lhs.date == rhs.date {
                return lhs.id.uuidString > rhs.id.uuidString
            }
            return lhs.date > rhs.date
        }
    }

    func session(id: UUID) -> StrengthWorkoutSession? {
        sessions.first { $0.id == id }
    }

    /// Adds a new session. Duplicate IDs are rejected so an accidental double
    /// save cannot create two copies of the same workout.
    @discardableResult
    func addSession(_ session: StrengthWorkoutSession) -> Bool {
        guard self.session(id: session.id) == nil else { return false }
        sessions.append(session)
        saveSessions()
        return true
    }

    /// Replaces an existing session while retaining its stable ID.
    @discardableResult
    func updateSession(_ session: StrengthWorkoutSession) -> Bool {
        guard let index = sessions.firstIndex(where: { $0.id == session.id }) else { return false }
        sessions[index] = session
        saveSessions()
        return true
    }

    @discardableResult
    func deleteSession(_ session: StrengthWorkoutSession) -> Bool {
        deleteSession(id: session.id)
    }

    @discardableResult
    func deleteSession(id: UUID) -> Bool {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else { return false }
        sessions.remove(at: index)
        saveSessions()
        return true
    }

    func replaceAllSessions(_ newSessions: [StrengthWorkoutSession]) {
        sessions = newSessions
        saveSessions()
    }

    /// Newest-first occurrences for a stable exercise database ID.
    func exerciseHistory(for exerciseID: String) -> [StrengthExerciseHistoryEntry] {
        sessions
            .flatMap { session in
                session.exercises
                    .filter { $0.exerciseID == exerciseID }
                    .map {
                        StrengthExerciseHistoryEntry(
                            sessionID: session.id,
                            date: session.date,
                            sessionName: session.name,
                            exercise: $0
                        )
                    }
            }
            .sorted { lhs, rhs in
                if lhs.date == rhs.date {
                    return lhs.id.uuidString > rhs.id.uuidString
                }
                return lhs.date > rhs.date
            }
    }

    /// Most recent occurrence strictly earlier than `date`. Pass the draft or
    /// edited session's ID to ensure it cannot become its own previous value.
    func previousExercise(
        for exerciseID: String,
        before date: Date = .distantFuture,
        excludingSessionID: UUID? = nil
    ) -> StrengthExerciseHistoryEntry? {
        exerciseHistory(for: exerciseID).first {
            $0.date < date && $0.sessionID != excludingSessionID
        }
    }

    func previousSets(
        for exerciseID: String,
        before date: Date = .distantFuture,
        excludingSessionID: UUID? = nil
    ) -> [StrengthWorkoutSet] {
        previousExercise(
            for: exerciseID,
            before: date,
            excludingSessionID: excludingSessionID
        )?.exercise.sets ?? []
    }

    /// Compares this session's exercise against every earlier occurrence. The
    /// passed session may be an unsaved draft, which lets the UI preview a PR
    /// before it persists the workout.
    func personalRecordComparison(
        for exerciseID: String,
        in session: StrengthWorkoutSession
    ) -> StrengthPersonalRecordComparison? {
        let currentSets = session.exercises
            .filter { $0.exerciseID == exerciseID }
            .flatMap(\.sets)
        let current = StrengthExercisePerformance(sets: currentSets)
        guard current.hasRecordedValue else { return nil }

        let priorSets = sessions
            .filter { $0.id != session.id && $0.date < session.date }
            .flatMap(\.exercises)
            .filter { $0.exerciseID == exerciseID }
            .flatMap(\.sets)
        let previousPerformance = StrengthExercisePerformance(sets: priorSets)
        let previous = previousPerformance.hasRecordedValue ? previousPerformance : nil

        return StrengthPersonalRecordComparison(current: current, previous: previous)
    }

    private func saveSessions() {
        guard let data = try? JSONEncoder().encode(sessions) else { return }
        userDefaults.set(data, forKey: storageKey)
    }

    private func loadSessions() {
        guard let data = userDefaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([StrengthWorkoutSession].self, from: data)
        else {
            sessions = []
            return
        }
        sessions = decoded
    }
}
