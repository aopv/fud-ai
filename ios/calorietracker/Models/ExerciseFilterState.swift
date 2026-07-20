import Foundation

struct ExerciseFilterState: Codable, Equatable {
    var searchText = ""
    var splitIdentifier: String?
    var splitGroups: Set<String> = []
    var levels: Set<String> = []
    var rawEquipment: Set<String> = []
    var primaryMuscles: Set<String> = []
    var secondaryMuscles: Set<String> = []
    var forces: Set<String> = []
    var mechanics: Set<String> = []
    var categories: Set<String> = []
    var sort: ExerciseLibrarySort = .name

    init(
        searchText: String = "",
        splitIdentifier: String? = nil,
        splitGroups: Set<String> = [],
        levels: Set<String> = [],
        rawEquipment: Set<String> = [],
        primaryMuscles: Set<String> = [],
        secondaryMuscles: Set<String> = [],
        forces: Set<String> = [],
        mechanics: Set<String> = [],
        categories: Set<String> = [],
        sort: ExerciseLibrarySort = .name
    ) {
        self.searchText = searchText
        self.splitIdentifier = splitIdentifier
        self.splitGroups = splitGroups
        self.levels = levels
        self.rawEquipment = rawEquipment
        self.primaryMuscles = primaryMuscles
        self.secondaryMuscles = secondaryMuscles
        self.forces = forces
        self.mechanics = mechanics
        self.categories = categories
        self.sort = sort
    }

    private enum CodingKeys: String, CodingKey {
        case searchText
        case splitIdentifier
        case splitGroups
        case levels
        case rawEquipment
        case primaryMuscles
        case secondaryMuscles
        case forces
        case mechanics
        case categories
        case sort
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        searchText = try container.decodeIfPresent(String.self, forKey: .searchText) ?? ""
        splitIdentifier = try container.decodeIfPresent(String.self, forKey: .splitIdentifier)
        splitGroups = try container.decodeIfPresent(Set<String>.self, forKey: .splitGroups) ?? []
        levels = try container.decodeIfPresent(Set<String>.self, forKey: .levels) ?? []
        rawEquipment = try container.decodeIfPresent(Set<String>.self, forKey: .rawEquipment) ?? []
        primaryMuscles = try container.decodeIfPresent(Set<String>.self, forKey: .primaryMuscles) ?? []
        secondaryMuscles = try container.decodeIfPresent(Set<String>.self, forKey: .secondaryMuscles) ?? []
        forces = try container.decodeIfPresent(Set<String>.self, forKey: .forces) ?? []
        mechanics = try container.decodeIfPresent(Set<String>.self, forKey: .mechanics) ?? []
        categories = try container.decodeIfPresent(Set<String>.self, forKey: .categories) ?? []
        sort = try container.decodeIfPresent(ExerciseLibrarySort.self, forKey: .sort) ?? .name
    }
}

enum ExerciseFilterStateStore {
    static let workoutsKey = "fudai.workouts.filterState"

    static func load(key: String) -> ExerciseFilterState {
        guard let data = UserDefaults.standard.data(forKey: key),
              let state = try? JSONDecoder().decode(ExerciseFilterState.self, from: data) else {
            return ExerciseFilterState()
        }
        return state
    }

    static func save(_ state: ExerciseFilterState, key: String) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
