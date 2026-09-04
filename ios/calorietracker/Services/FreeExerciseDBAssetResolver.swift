import Foundation

struct FreeExerciseDBAssetResolver {
    static func exercisesJSONURL() -> URL? {
        firstExistingURL(candidates: [
            Bundle.main.url(forResource: "exercises", withExtension: "json"),
            Bundle.main.url(forResource: "exercises", withExtension: "json", subdirectory: "FreeExerciseDB/dist"),
            Bundle.main.url(forResource: "exercises", withExtension: "json", subdirectory: "Resources/FreeExerciseDB/dist"),
            Bundle.main.resourceURL?.appendingPathComponent("FreeExerciseDB/dist/exercises.json"),
            Bundle.main.resourceURL?.appendingPathComponent("Resources/FreeExerciseDB/dist/exercises.json")
        ])
    }

    static func imageURLs(for imagePaths: [String]) -> [URL] {
        imagePaths.compactMap { imagePath in
            imageURL(for: imagePath)
        }
    }

    static func imageURLs(forExerciseName exerciseName: String?) -> [URL] {
        imageURLs(forExerciseName: exerciseName, muscleGroup: nil, equipment: nil)
    }

    static func imageURLs(
        forExerciseName exerciseName: String?,
        muscleGroup: MuscleGroup?,
        equipment: Equipment?
    ) -> [URL] {
        guard let key = exerciseName?.normalizedExerciseName else {
            return []
        }

        if let exactPaths = imagePathsByName[key] {
            return imageURLs(for: exactPaths)
        }

        let queryTokens = Set(key.split(separator: " ").map(String.init))
        let bestMatch = imageRecords
            .filter { !$0.images.isEmpty }
            .map { record in
                (
                    record: record,
                    score: matchScore(
                        record: record,
                        query: key,
                        queryTokens: queryTokens,
                        muscleGroup: muscleGroup,
                        equipment: equipment
                    )
                )
            }
            .filter { $0.score > 0 }
            .max { $0.score < $1.score }?
            .record

        return imageURLs(for: bestMatch?.images ?? [])
    }

    static func imageURLs(forMuscleGroup muscleGroup: MuscleGroup, equipment: Equipment?) -> [URL] {
        let bestMatch = imageRecords
            .filter { !$0.images.isEmpty && $0.matches(muscleGroup: muscleGroup) }
            .map { record in
                (
                    record: record,
                    score: fallbackScore(record: record, muscleGroup: muscleGroup, equipment: equipment)
                )
            }
            .filter { $0.score > 0 }
            .max { $0.score < $1.score }?
            .record

        return imageURLs(for: bestMatch?.images ?? [])
    }

    private static let imagePathsByName: [String: [String]] = {
        imageRecords.reduce(into: [:]) { partialResult, record in
            partialResult[record.name.normalizedExerciseName] = record.images
        }
    }()

    private static let imageRecords: [FreeExerciseDBRecord] = {
        guard
            let url = exercisesJSONURL(),
            let data = try? Data(contentsOf: url),
            let records = try? JSONDecoder().decode([FreeExerciseDBRecord].self, from: data)
        else {
            return []
        }

        return records
    }()

    private static func imageURL(for relativePath: String) -> URL? {
        let cleanPath = relativePath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let path = cleanPath as NSString
        let filename = path.deletingPathExtension
        let fileExtension = path.pathExtension.isEmpty ? nil : path.pathExtension

        return firstExistingURL(candidates: [
            Bundle.main.url(forResource: filename, withExtension: fileExtension),
            Bundle.main.url(forResource: cleanPath, withExtension: nil, subdirectory: "FreeExerciseDB/images"),
            Bundle.main.url(forResource: cleanPath, withExtension: nil, subdirectory: "Resources/FreeExerciseDB/images"),
            Bundle.main.resourceURL?.appendingPathComponent("FreeExerciseDB/images/\(cleanPath)"),
            Bundle.main.resourceURL?.appendingPathComponent("Resources/FreeExerciseDB/images/\(cleanPath)")
        ])
    }

    private static func firstExistingURL(candidates: [URL?]) -> URL? {
        candidates.compactMap { $0 }.first { FileManager.default.fileExists(atPath: $0.path) }
    }

    private static func matchScore(
        record: FreeExerciseDBRecord,
        query: String,
        queryTokens: Set<String>,
        muscleGroup: MuscleGroup?,
        equipment: Equipment?
    ) -> Int {
        let name = record.name.normalizedExerciseName
        let nameTokens = Set(name.split(separator: " ").map(String.init))
        let sharedTokens = queryTokens.intersection(nameTokens)

        var score = sharedTokens.count * 4
        if name == query {
            score += 100
        }
        if name.contains(query) || query.contains(name) {
            score += 24
        }
        if let muscleGroup, record.matches(muscleGroup: muscleGroup) {
            score += 12
        }
        if let equipment, record.matches(equipment: equipment) {
            score += 8
        }

        return score
    }

    private static func fallbackScore(
        record: FreeExerciseDBRecord,
        muscleGroup: MuscleGroup,
        equipment: Equipment?
    ) -> Int {
        var score = record.matches(muscleGroup: muscleGroup) ? 20 : 0

        if let equipment, record.matches(equipment: equipment) {
            score += 10
        }

        if record.category?.localizedCaseInsensitiveContains("strength") == true {
            score += 4
        }

        if record.level?.localizedCaseInsensitiveContains("beginner") == true {
            score += 2
        }

        return score
    }
}

private extension String {
    var normalizedExerciseName: String {
        lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

private extension FreeExerciseDBRecord {
    func matches(muscleGroup: MuscleGroup) -> Bool {
        let muscles = (primaryMuscles + secondaryMuscles).map { $0.lowercased() }.joined(separator: " ")
        let categoryText = category?.lowercased() ?? ""

        switch muscleGroup {
        case .chest:
            return muscles.contains("chest")
        case .back:
            return muscles.contains("lats") || muscles.contains("middle back") || muscles.contains("lower back") || muscles.contains("traps")
        case .legs:
            return muscles.contains("quadriceps") || muscles.contains("hamstrings") || muscles.contains("calves") || muscles.contains("glutes") || muscles.contains("adductors") || muscles.contains("abductors")
        case .shoulders:
            return muscles.contains("shoulders")
        case .arms:
            return muscles.contains("biceps") || muscles.contains("triceps") || muscles.contains("forearms")
        case .core:
            return muscles.contains("abdominals")
        case .fullBody:
            return categoryText.contains("cardio") || categoryText.contains("plyometrics") || categoryText.contains("strongman") || categoryText.contains("olympic")
        }
    }

    func matches(equipment target: Equipment) -> Bool {
        let equipmentText = equipment?.lowercased() ?? ""
        let nameText = name.lowercased()

        switch target {
        case .dumbbells:
            return equipmentText.contains("dumbbell") || equipmentText.contains("kettlebell") || nameText.contains("dumbbell") || nameText.contains("kettlebell")
        case .barbell:
            return equipmentText.contains("barbell") || equipmentText.contains("e-z") || nameText.contains("barbell")
        case .cableMachine:
            return equipmentText.contains("cable") || nameText.contains("cable")
        case .smithMachine:
            return nameText.contains("smith")
        case .bench:
            return nameText.contains("bench")
        case .chestPress:
            return nameText.contains("chest press")
        case .shoulderPress:
            return nameText.contains("shoulder press") && equipmentText.contains("machine")
        case .latPulldown:
            return nameText.contains("pulldown") || nameText.contains("pull-down")
        case .rowMachine:
            return nameText.contains("row") && equipmentText.contains("machine")
        case .legPress:
            return nameText.contains("leg press")
        case .legExtension:
            return nameText.contains("leg extension")
        case .legCurl:
            return nameText.contains("leg curl")
        case .pullUpBar:
            return nameText.contains("pull-up") || nameText.contains("pull up") || nameText.contains("chin-up") || nameText.contains("chin up")
        case .treadmill:
            return nameText.contains("treadmill")
        case .bodyweight:
            return equipmentText.contains("body") || equipmentText.isEmpty
        }
    }
}
