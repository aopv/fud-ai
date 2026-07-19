import Foundation
import Observation

/// Local-only persistence for the session-first workout logger. The state is a
/// single atomic payload containing completed history and at most one resumable
/// active session. It does not sync to HealthKit, a backend, or cloud storage.
@Observable
final class StrengthWorkoutStore {
    private(set) var completedSessions: [StrengthWorkoutSession] = []
    private(set) var activeSession: StrengthWorkoutSession?

    static let defaultStorageKey = "strengthWorkoutSessionState.v1"
    static let legacyStorageKey = "strengthWorkoutSessions"
    static let unreadableBackupSuffix = ".unreadableBackup"

    private let userDefaults: UserDefaults
    private let storageKey: String

    init(
        userDefaults: UserDefaults = .standard,
        storageKey: String = StrengthWorkoutStore.defaultStorageKey
    ) {
        self.userDefaults = userDefaults
        self.storageKey = storageKey
        load()
    }

    /// Newest completed workout first, with a stable ID tie-breaker.
    var sortedCompletedSessions: [StrengthWorkoutSession] {
        completedSessions.sorted { lhs, rhs in
            Self.isNewer(lhs, rhs)
        }
    }

    func completedSession(id: UUID) -> StrengthWorkoutSession? {
        completedSessions.first { $0.id == id }
    }

    /// Starts a session only when none is active. Calling this again resumes and
    /// returns the existing draft instead of replacing the user's in-progress work.
    @discardableResult
    func startSession(name: String? = nil, at startedAt: Date = .now) -> StrengthWorkoutSession {
        if let activeSession { return activeSession }

        let session = StrengthWorkoutSession(startedAt: startedAt, name: name)
        activeSession = session
        save()
        return session
    }

    @discardableResult
    func renameActiveSession(_ name: String?) -> Bool {
        guard var session = activeSession else { return false }
        session.name = StrengthWorkoutSession.normalizedName(name)
        activeSession = session
        save()
        return true
    }

    /// Adds one catalog exercise to the active workout. A repeated catalog ID
    /// returns the existing row, preventing accidental duplicate exercises.
    @discardableResult
    func addExercise(
        exerciseID: String,
        exerciseName: String,
        autofillFromHistory: Bool = false
    ) -> UUID? {
        guard var session = activeSession else { return nil }

        let normalizedID = exerciseID.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedName = exerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedID.isEmpty, !normalizedName.isEmpty else { return nil }

        if let existing = session.exercises.first(where: { $0.exerciseID == normalizedID }) {
            return existing.id
        }

        let sets = autofillFromHistory
            ? previousSets(for: normalizedID, before: session.startedAt).map { $0.copiedForNewSession() }
            : []
        let exercise = StrengthWorkoutExercise(
            exerciseID: normalizedID,
            exerciseName: normalizedName,
            sets: sets
        )
        session.exercises.append(exercise)
        activeSession = session
        save()
        return exercise.id
    }

    @discardableResult
    func removeExercise(id exerciseEntryID: UUID) -> Bool {
        guard var session = activeSession,
              let index = session.exercises.firstIndex(where: { $0.id == exerciseEntryID })
        else { return false }

        session.exercises.remove(at: index)
        activeSession = session
        save()
        return true
    }

    @discardableResult
    func addSet(
        to exerciseEntryID: UUID,
        reps: Int = 0,
        weightKg: Double? = nil,
        isBodyweight: Bool = false
    ) -> UUID? {
        guard var session = activeSession,
              let exerciseIndex = session.exercises.firstIndex(where: { $0.id == exerciseEntryID })
        else { return nil }

        let set = StrengthWorkoutSet(
            reps: reps,
            weightKg: weightKg,
            isBodyweight: isBodyweight
        )
        session.exercises[exerciseIndex].sets.append(set)
        activeSession = session
        save()
        return set.id
    }

    @discardableResult
    func updateSet(
        exerciseID exerciseEntryID: UUID,
        setID: UUID,
        reps: Int,
        weightKg: Double?,
        isBodyweight: Bool
    ) -> Bool {
        guard var session = activeSession,
              let exerciseIndex = session.exercises.firstIndex(where: { $0.id == exerciseEntryID }),
              let setIndex = session.exercises[exerciseIndex].sets.firstIndex(where: { $0.id == setID })
        else { return false }

        let wasPerformed = session.exercises[exerciseIndex].sets[setIndex].isPerformed
        session.exercises[exerciseIndex].sets[setIndex] = StrengthWorkoutSet(
            id: setID,
            reps: reps,
            weightKg: weightKg,
            isBodyweight: isBodyweight,
            isPerformed: wasPerformed && reps > 0
        )
        activeSession = session
        save()
        return true
    }

    /// Marks an autofilled suggestion as performed (or returns it to a pending
    /// state) without rewriting its reps or canonical weight.
    @discardableResult
    func setPerformed(
        exerciseID exerciseEntryID: UUID,
        setID: UUID,
        isPerformed: Bool
    ) -> Bool {
        guard var session = activeSession,
              let exerciseIndex = session.exercises.firstIndex(where: { $0.id == exerciseEntryID }),
              let setIndex = session.exercises[exerciseIndex].sets.firstIndex(where: { $0.id == setID })
        else { return false }

        let hasRepetitions = session.exercises[exerciseIndex].sets[setIndex].reps > 0
        session.exercises[exerciseIndex].sets[setIndex].isPerformed = isPerformed && hasRepetitions
        activeSession = session
        save()
        return true
    }

    @discardableResult
    func removeSet(exerciseID exerciseEntryID: UUID, setID: UUID) -> Bool {
        guard var session = activeSession,
              let exerciseIndex = session.exercises.firstIndex(where: { $0.id == exerciseEntryID }),
              let setIndex = session.exercises[exerciseIndex].sets.firstIndex(where: { $0.id == setID })
        else { return false }

        session.exercises[exerciseIndex].sets.remove(at: setIndex)
        activeSession = session
        save()
        return true
    }

    /// Copies the most recent completed performance into an empty active
    /// exercise, assigning fresh set IDs so later edits cannot alias history.
    @discardableResult
    func autofillActiveExercise(id exerciseEntryID: UUID) -> Bool {
        guard var session = activeSession,
              let exerciseIndex = session.exercises.firstIndex(where: { $0.id == exerciseEntryID }),
              session.exercises[exerciseIndex].sets.isEmpty
        else { return false }

        let exerciseID = session.exercises[exerciseIndex].exerciseID
        let priorSets = previousSets(for: exerciseID, before: session.startedAt)
        guard !priorSets.isEmpty else { return false }

        session.exercises[exerciseIndex].sets = priorSets.map { $0.copiedForNewSession() }
        activeSession = session
        save()
        return true
    }

    /// Completes the active workout after removing unfinished placeholder sets.
    /// An empty workout remains active so a stray Finish tap cannot create junk history.
    @discardableResult
    func completeActiveSession(at completedAt: Date = .now) -> StrengthWorkoutSession? {
        guard var session = activeSession else { return nil }

        session.exercises = session.exercises.compactMap { exercise in
            var completedExercise = exercise
            completedExercise.sets = exercise.recordedSets.map { $0.sanitized() }
            return completedExercise.sets.isEmpty ? nil : completedExercise
        }
        guard session.hasRecordedSets else { return nil }

        session.completedAt = max(completedAt, session.startedAt)
        completedSessions.removeAll { $0.id == session.id }
        completedSessions.append(session)
        activeSession = nil
        save()
        return session
    }

    /// Drops only the resumable draft and leaves completed history untouched.
    @discardableResult
    func discardActiveSession() -> StrengthWorkoutSession? {
        guard let discarded = activeSession else { return nil }
        activeSession = nil
        save()
        return discarded
    }

    @discardableResult
    func deleteCompletedSession(id: UUID) -> Bool {
        guard let index = completedSessions.firstIndex(where: { $0.id == id }) else { return false }
        completedSessions.remove(at: index)
        save()
        return true
    }

    func clearCompletedSessions() {
        guard !completedSessions.isEmpty else { return }
        completedSessions = []
        save()
    }

    func clearAll() {
        completedSessions = []
        activeSession = nil
        userDefaults.removeObject(forKey: storageKey)
        userDefaults.removeObject(forKey: storageKey + Self.unreadableBackupSuffix)
        userDefaults.removeObject(forKey: Self.legacyStorageKey)
    }

    /// Newest-first completed occurrences for a stable catalog exercise ID.
    func exerciseHistory(for exerciseID: String) -> [StrengthExerciseHistoryEntry] {
        completedSessions
            .flatMap { session -> [StrengthExerciseHistoryEntry] in
                guard let completedAt = session.completedAt else { return [] }
                return session.exercises
                    .filter { $0.exerciseID == exerciseID }
                    .map {
                        StrengthExerciseHistoryEntry(
                            sessionID: session.id,
                            startedAt: session.startedAt,
                            completedAt: completedAt,
                            sessionName: session.name,
                            exercise: $0
                        )
                    }
            }
            .sorted { lhs, rhs in
                if lhs.completedAt == rhs.completedAt {
                    return lhs.id.uuidString > rhs.id.uuidString
                }
                return lhs.completedAt > rhs.completedAt
            }
    }

    /// The exact sets from the most recently completed earlier occurrence.
    func previousSets(
        for exerciseID: String,
        before date: Date = .distantFuture,
        excludingSessionID: UUID? = nil
    ) -> [StrengthWorkoutSet] {
        exerciseHistory(for: exerciseID)
            .first {
                $0.startedAt < date && $0.sessionID != excludingSessionID
            }?
            .exercise.sets ?? []
    }

    /// Best all-time reps and explicit load before an optional cutoff.
    func allTimeRecords(
        for exerciseID: String,
        before date: Date = .distantFuture,
        excludingSessionID: UUID? = nil
    ) -> StrengthExercisePerformance? {
        let sets = completedSessions
            .filter {
                $0.startedAt < date && $0.id != excludingSessionID
            }
            .flatMap(\.exercises)
            .filter { $0.exerciseID == exerciseID }
            .flatMap(\.sets)
        let performance = StrengthExercisePerformance(sets: sets)
        return performance.hasRecordedValue ? performance : nil
    }

    /// Compares a draft or completed workout against all earlier history.
    func personalRecordComparison(
        for exerciseID: String,
        in session: StrengthWorkoutSession
    ) -> StrengthPersonalRecordComparison? {
        let currentSets = session.exercises
            .filter { $0.exerciseID == exerciseID }
            .flatMap(\.sets)
        let current = StrengthExercisePerformance(sets: currentSets)
        guard current.hasRecordedValue else { return nil }

        return StrengthPersonalRecordComparison(
            current: current,
            previous: allTimeRecords(
                for: exerciseID,
                before: session.startedAt,
                excludingSessionID: session.id
            )
        )
    }

    private func save() {
        let state = PersistedState(
            completedSessions: completedSessions,
            activeSession: activeSession
        )
        guard let data = try? JSONEncoder().encode(state) else { return }
        userDefaults.set(data, forKey: storageKey)
    }

    private func load() {
        guard let data = userDefaults.data(forKey: storageKey) else {
            if recoverQuarantinedStates() {
                save()
            } else {
                migrateLegacySessionsIfAvailable()
            }
            return
        }

        do {
            apply(try decodedState(from: data))
        } catch {
            completedSessions = []
            activeSession = nil
            quarantine(data)
            userDefaults.removeObject(forKey: storageKey)
        }

        // A newer build may understand payloads quarantined by an older one.
        // Merge every newly readable session by stable ID and retain any still
        // unknown payload for a future schema migration.
        if recoverQuarantinedStates() {
            save()
        }
    }

    private func decodedState(from data: Data) throws -> PersistedState {
        let state = try JSONDecoder().decode(PersistedState.self, from: data)
        guard state.schemaVersion == PersistedState.currentSchemaVersion else {
            throw PersistenceError.unsupportedSchema
        }
        return state
    }

    private func apply(_ state: PersistedState) {
        completedSessions = Self.sanitizedCompletedSessions(state.completedSessions)
        activeSession = state.activeSession.map { Self.sanitizedActiveSession($0) }

        if let activeSession,
           completedSessions.contains(where: { $0.id == activeSession.id }) {
            self.activeSession = nil
        }
    }

    /// Returns true when the recovered payload is fully represented in memory.
    /// A conflicting second active draft remains quarantined until the current
    /// draft is finished or discarded, preventing either draft from being lost.
    private func merge(_ state: PersistedState) -> Bool {
        let recoveredCompleted = Self.sanitizedCompletedSessions(state.completedSessions)
        let existingIDs = Set(completedSessions.map(\.id))
        completedSessions.append(contentsOf: recoveredCompleted.filter { !existingIDs.contains($0.id) })
        completedSessions = Self.sanitizedCompletedSessions(completedSessions)

        guard let recoveredActive = state.activeSession.map({ Self.sanitizedActiveSession($0) }) else {
            return true
        }
        if completedSessions.contains(where: { $0.id == recoveredActive.id }) {
            return true
        }
        if activeSession == nil {
            activeSession = recoveredActive
            return true
        }
        return activeSession?.id == recoveredActive.id
    }

    private func quarantine(_ data: Data) {
        var payloads = quarantinedPayloads()
        guard !payloads.contains(data) else { return }
        payloads.append(data)
        saveQuarantinedPayloads(payloads)
    }

    @discardableResult
    private func recoverQuarantinedStates() -> Bool {
        let payloads = quarantinedPayloads()
        guard !payloads.isEmpty else { return false }

        var recoveredAny = false
        var remaining: [Data] = []
        for payload in payloads {
            do {
                let fullyRecovered = merge(try decodedState(from: payload))
                recoveredAny = true
                if !fullyRecovered {
                    remaining.append(payload)
                }
            } catch {
                remaining.append(payload)
            }
        }
        saveQuarantinedPayloads(remaining)
        return recoveredAny
    }

    private func quarantinedPayloads() -> [Data] {
        let backupKey = storageKey + Self.unreadableBackupSuffix
        guard let data = userDefaults.data(forKey: backupKey) else { return [] }
        if let envelope = try? JSONDecoder().decode(QuarantinedPayloads.self, from: data) {
            return envelope.payloads
        }
        // Compatibility with the first backup implementation, which stored a
        // single raw payload directly at the backup key.
        return [data]
    }

    private func saveQuarantinedPayloads(_ payloads: [Data]) {
        let backupKey = storageKey + Self.unreadableBackupSuffix
        guard !payloads.isEmpty else {
            userDefaults.removeObject(forKey: backupKey)
            return
        }
        guard let data = try? JSONEncoder().encode(QuarantinedPayloads(payloads: payloads)) else { return }
        userDefaults.set(data, forKey: backupKey)
    }

    /// The reverted logger stored a raw array at `strengthWorkoutSessions` with
    /// `date` rather than lifecycle timestamps. Migrate it once, treating that
    /// date as both start and completion so no valid phone history is discarded.
    private func migrateLegacySessionsIfAvailable() {
        guard storageKey == Self.defaultStorageKey,
              let data = userDefaults.data(forKey: Self.legacyStorageKey),
              let legacySessions = try? JSONDecoder().decode([LegacySession].self, from: data)
        else { return }

        let migrated = legacySessions.map { $0.currentModel }
        completedSessions = Self.sanitizedCompletedSessions(migrated)
        activeSession = nil
        save()

        // Remove the old copy only after the new envelope was successfully written.
        if userDefaults.data(forKey: storageKey) != nil {
            userDefaults.removeObject(forKey: Self.legacyStorageKey)
        }
    }

    private static func sanitizedCompletedSessions(
        _ sessions: [StrengthWorkoutSession]
    ) -> [StrengthWorkoutSession] {
        var seenIDs = Set<UUID>()
        return sessions.compactMap { source in
            guard seenIDs.insert(source.id).inserted else { return nil }

            var session = source
            session.name = StrengthWorkoutSession.normalizedName(session.name)
            session.completedAt = max(source.completedAt ?? source.startedAt, source.startedAt)
            session.exercises = source.exercises.compactMap { exercise in
                var sanitized = exercise
                sanitized.sets = exercise.sets
                    .map { $0.sanitized() }
                    .filter(\.isRecorded)
                return sanitized.sets.isEmpty ? nil : sanitized
            }
            return session.hasRecordedSets ? session : nil
        }
    }

    private static func sanitizedActiveSession(
        _ source: StrengthWorkoutSession
    ) -> StrengthWorkoutSession {
        var session = source
        session.completedAt = nil
        session.name = StrengthWorkoutSession.normalizedName(session.name)
        session.exercises = source.exercises.map { exercise in
            var sanitized = exercise
            sanitized.sets = exercise.sets.map { $0.sanitized() }
            return sanitized
        }
        return session
    }

    private static func isNewer(_ lhs: StrengthWorkoutSession, _ rhs: StrengthWorkoutSession) -> Bool {
        let lhsDate = lhs.completedAt ?? lhs.startedAt
        let rhsDate = rhs.completedAt ?? rhs.startedAt
        if lhsDate == rhsDate {
            return lhs.id.uuidString > rhs.id.uuidString
        }
        return lhsDate > rhsDate
    }
}

private extension StrengthWorkoutStore {
    struct PersistedState: Codable {
        static let currentSchemaVersion = 1

        let schemaVersion: Int
        let completedSessions: [StrengthWorkoutSession]
        let activeSession: StrengthWorkoutSession?

        init(
            completedSessions: [StrengthWorkoutSession],
            activeSession: StrengthWorkoutSession?
        ) {
            schemaVersion = Self.currentSchemaVersion
            self.completedSessions = completedSessions
            self.activeSession = activeSession
        }
    }

    struct QuarantinedPayloads: Codable {
        let payloads: [Data]
    }

    enum PersistenceError: Error {
        case unsupportedSchema
    }

    struct LegacySession: Codable {
        let id: UUID
        let date: Date
        let name: String?
        let exercises: [LegacyExercise]

        var currentModel: StrengthWorkoutSession {
            StrengthWorkoutSession(
                id: id,
                startedAt: date,
                completedAt: date,
                name: name,
                exercises: exercises.map(\.currentModel)
            )
        }
    }

    struct LegacyExercise: Codable {
        let id: UUID
        let exerciseID: String
        let exerciseName: String
        let sets: [LegacySet]

        var currentModel: StrengthWorkoutExercise {
            StrengthWorkoutExercise(
                id: id,
                exerciseID: exerciseID,
                exerciseName: exerciseName,
                sets: sets.map(\.currentModel)
            )
        }
    }

    struct LegacySet: Codable {
        let id: UUID
        let reps: Int
        let weightKg: Double?
        let isBodyweight: Bool?

        var currentModel: StrengthWorkoutSet {
            StrengthWorkoutSet(
                id: id,
                reps: reps,
                weightKg: weightKg,
                isBodyweight: isBodyweight ?? (weightKg == nil),
                isPerformed: reps > 0
            )
        }
    }
}
