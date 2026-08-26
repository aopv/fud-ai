import SwiftUI
import UIKit

struct WorkoutsView: View {
    @AppStorage(WorkoutTabMode.storageKey) private var selectedModeRaw = WorkoutTabMode.defaultMode.rawValue
    @AppStorage(AppThemeColor.storageKey) private var appThemeColorRaw = AppThemeColor.defaultColor.rawValue
    @State private var workoutLogSession = WorkoutLogSessionState()

    private var selectedMode: WorkoutTabMode {
        WorkoutTabMode.mode(for: selectedModeRaw)
    }

    var body: some View {
        NavigationStack {
            Group {
                if selectedMode == .log {
                    WorkoutLogView(
                        session: workoutLogSession,
                        embedsInNavigationStack: false,
                        onShowLibrary: { showMode(.library) }
                    )
                    .transition(.opacity)
                } else {
                    ExerciseLibraryBrowserView(
                        onShowWorkoutLog: { showMode(.log) }
                    )
                    .background(WorkoutsScreenBackground())
                    .navigationTitle("Workouts")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar(.hidden, for: .navigationBar)
                    .transition(.opacity)
                }
            }
        }
        // Refresh static workout theme tokens without replacing this stack or
        // discarding its route and session-only timer state.
        .animation(.easeInOut(duration: 0.2), value: appThemeColorRaw)
    }

    private func showMode(_ mode: WorkoutTabMode) {
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedModeRaw = mode.rawValue
        }
    }
}

private struct ExerciseLibraryBrowserView: View {
    @Environment(StrengthWorkoutStore.self) private var workoutStore
    var onShowWorkoutLog: (() -> Void)?

    @State private var searchText = ""
    @State private var selectedSplitGroupTitles: Set<String> = []
    @State private var selectedLevels: Set<String> = []
    @State private var selectedRawEquipment: Set<String> = []
    @State private var selectedPrimaryMuscles: Set<String> = []
    @State private var selectedSecondaryMuscles: Set<String> = []
    @State private var selectedForces: Set<String> = []
    @State private var selectedMechanics: Set<String> = []
    @State private var selectedCategories: Set<String> = []
    @State private var selectedSort: ExerciseLibrarySort = .name

    private let service = ExerciseLibraryService.shared

    private var selectedWorkoutSplit: StrengthWorkoutSplit {
        workoutStore.preferences.split
    }

    private var bodyPartFilterTitle: String {
        String(localized: "Body Part")
    }

    private var usesBodyPartSplitFilter: Bool {
        selectedWorkoutSplit == .fullBody || selectedWorkoutSplit == .custom
    }

    private var splitGroups: [StrengthWorkoutSplitGroup] {
        StrengthWorkoutSplitGroup.selectionGroups(
            for: selectedWorkoutSplit,
            availablePrimaryMuscles: service.availablePrimaryMuscles,
            availableSecondaryMuscles: service.availableSecondaryMuscles
        )
    }

    private var selectedSplitGroups: [StrengthWorkoutSplitGroup] {
        splitGroups.filter { selectedSplitGroupTitles.contains($0.title) }
    }

    private var shouldShowPrimaryFilter: Bool {
        !(usesBodyPartSplitFilter && !selectedSplitGroupTitles.isEmpty)
    }

    private var primaryFilterOptions: [String] {
        guard !selectedSplitGroups.isEmpty else { return service.availablePrimaryMuscles }
        let allowedMuscles = Set(selectedSplitGroups.flatMap(\.muscles))
        return service.availablePrimaryMuscles.filter(allowedMuscles.contains)
    }

    private var profileRawEquipmentOptions: [String] {
        service.availableRawEquipment
    }

    private var effectiveRawEquipmentSelection: Set<String> {
        if selectedRawEquipment.isEmpty {
            return Set(profileRawEquipmentOptions)
        }
        return selectedRawEquipment
    }

    private var items: [ExerciseLibraryItem] {
        let rawEquipmentSelection = effectiveRawEquipmentSelection
        guard !rawEquipmentSelection.isEmpty else { return [] }

        let filtered = service.filtered(
            levels: selectedLevels,
            rawEquipment: rawEquipmentSelection,
            primaryMuscles: selectedPrimaryMuscles,
            secondaryMuscles: selectedSecondaryMuscles,
            forces: selectedForces,
            mechanics: selectedMechanics,
            categories: selectedCategories,
            sort: selectedSort,
            searchText: searchText
        )

        guard !selectedSplitGroups.isEmpty else { return filtered }
        let selectedMuscles = Set(selectedSplitGroups.flatMap(\.muscles))
        return filtered.filter { item in
            item.primaryMuscles.contains(where: selectedMuscles.contains) ||
                item.secondaryMuscles.contains(where: selectedMuscles.contains)
        }
    }

    private var hasActiveFilters: Bool {
        !searchText.isEmpty ||
            !selectedSplitGroupTitles.isEmpty ||
            !selectedLevels.isEmpty ||
            !selectedRawEquipment.isEmpty ||
            !selectedPrimaryMuscles.isEmpty ||
            !selectedSecondaryMuscles.isEmpty ||
            !selectedForces.isEmpty ||
            !selectedMechanics.isEmpty ||
            !selectedCategories.isEmpty ||
            selectedSort != .name
    }

    private var filterStateSnapshot: ExerciseFilterState {
        ExerciseFilterState(
            searchText: searchText,
            splitIdentifier: selectedWorkoutSplit.rawValue,
            splitGroups: selectedSplitGroupTitles,
            levels: selectedLevels,
            rawEquipment: selectedRawEquipment,
            primaryMuscles: selectedPrimaryMuscles,
            secondaryMuscles: selectedSecondaryMuscles,
            forces: selectedForces,
            mechanics: selectedMechanics,
            categories: selectedCategories,
            sort: selectedSort
        )
    }

    var body: some View {
        // Search, filter chips, and the results header stay pinned; only the
        // exercise list scrolls beneath them.
        VStack(alignment: .leading, spacing: 0) {
            NeoScreenHeader(
                eyebrow: String(localized: "Training database"),
                title: String(localized: "Workouts"),
                subtitle: String(localized: "Find exercises, build your day, and track every set")
            )
            .padding(.horizontal, NeoAppMetrics.screenInset)
            .padding(.top, 10)

            filters
                .padding(.horizontal, NeoAppMetrics.screenInset)
                .padding(.top, 10)
                .padding(.bottom, 10)

            ResultsHeader(
                count: items.count,
                noun: String(localized: "exercise"),
                subtitle: selectedSort.title,
                selectedSort: $selectedSort,
                canReset: hasActiveFilters,
                onReset: {
                    withAnimation(.snappy) {
                        resetFilters()
                    }
                }
            )
            .padding(.horizontal, NeoAppMetrics.screenInset)
            .padding(.bottom, 8)

            scrollingList
        }
        .workoutScreen()
        .onAppear {
            applyFilterState(ExerciseFilterStateStore.load(key: ExerciseFilterStateStore.workoutsKey))
            normalizeSplitGroupSelection()
            normalizePrimaryFilterSelection()
            normalizeEquipmentFilterSelection()
        }
        .onChange(of: filterStateSnapshot) { _, state in
            ExerciseFilterStateStore.save(state, key: ExerciseFilterStateStore.workoutsKey)
        }
        .onChange(of: selectedWorkoutSplit) {
            selectedSplitGroupTitles.removeAll()
            normalizePrimaryFilterSelection()
        }
        .onChange(of: selectedSplitGroupTitles) {
            normalizePrimaryFilterSelection()
        }
    }

    private var scrollingList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                if items.isEmpty {
                    ContentUnavailableView {
                        Label("No exercises match", systemImage: "line.3.horizontal.decrease")
                    } description: {
                        Text("Try a different muscle, equipment, or search — or reset the filters above.")
                    }
                    .frame(maxWidth: .infinity, minHeight: 260)
                    .padding(.horizontal, 20)
                } else {
                    ForEach(items) { item in
                        NavigationLink {
                            ExerciseLibraryDetailView(item: item)
                        } label: {
                            ExerciseLibraryRow(item: item)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, NeoAppMetrics.screenInset)
                    }
                }
            }
            .padding(.top, 2)
            .padding(.bottom, 112)
        }
        .contentMargins(.bottom, 104, for: .scrollContent)
        .scrollDismissesKeyboard(.immediately)
    }

    private var filters: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                WorkoutsSearchPill(searchText: $searchText)

                if let onShowWorkoutLog {
                    Button(action: onShowWorkoutLog) {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(KitchenTablePalette.onBrass)
                            .frame(width: 50, height: 50)
                            .background(NeoAppColors.brass, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 15, style: .continuous)
                                    .stroke(KitchenTablePalette.brassDeep, lineWidth: NeoAppMetrics.rule)
                            }
                            .contentShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .workoutPressable()
                    .accessibilityLabel("Workout log")
                    .accessibilityHint("Opens your workout diary")
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 9) {
                    filterMenuPill(
                        title: bodyPartFilterTitle,
                        value: selectionTitle(selectedSplitGroupTitles),
                        systemImage: "square.grid.2x2",
                        isActive: !selectedSplitGroupTitles.isEmpty,
                        items: splitGroupFilterItems
                    )

                    if shouldShowPrimaryFilter {
                        filterMenuPill(
                            title: String(localized: "Primary"),
                            value: primaryFilterTitle,
                            systemImage: "scope",
                            isActive: !selectedPrimaryMuscles.isEmpty,
                            items: primaryFilterItems
                        )
                    }

                    filterMenuPill(
                        title: String(localized: "Secondary"),
                        value: selectionTitle(selectedSecondaryMuscles),
                        systemImage: "scope",
                        isActive: !selectedSecondaryMuscles.isEmpty,
                        items: secondaryFilterItems
                    )

                    filterMenuPill(
                        title: String(localized: "Equipment"),
                        value: equipmentFilterTitle,
                        systemImage: "dumbbell.fill",
                        isActive: !selectedRawEquipment.isEmpty,
                        items: equipmentFilterItems
                    )

                    filterMenuPill(
                        title: String(localized: "Level"),
                        value: selectionTitle(selectedLevels),
                        systemImage: "chart.bar.fill",
                        isActive: !selectedLevels.isEmpty,
                        items: levelFilterItems
                    )

                    filterMenuPill(
                        title: String(localized: "Force"),
                        value: selectionTitle(selectedForces),
                        systemImage: "arrow.left.arrow.right",
                        isActive: !selectedForces.isEmpty,
                        items: forceFilterItems
                    )

                    filterMenuPill(
                        title: String(localized: "Mechanic"),
                        value: selectionTitle(selectedMechanics),
                        systemImage: "gearshape",
                        isActive: !selectedMechanics.isEmpty,
                        items: mechanicFilterItems
                    )

                    filterMenuPill(
                        title: String(localized: "Category"),
                        value: categoryFilterTitle,
                        systemImage: "tag",
                        isActive: !selectedCategories.isEmpty,
                        items: categoryFilterItems
                    )
                }
                .padding(.vertical, 1)
            }
        }
    }

    private var equipmentFilterTitle: String {
        if selectedRawEquipment.isEmpty {
            return String(localized: "All \(profileRawEquipmentOptions.count)")
        }
        return selectionTitle(selectedRawEquipment)
    }

    private var primaryFilterTitle: String {
        if selectedPrimaryMuscles.isEmpty {
            return String(localized: "All \(primaryFilterOptions.count)")
        }
        return selectionTitle(selectedPrimaryMuscles)
    }

    private var allPrimaryMenuTitle: String {
        String(localized: "All Primary (\(primaryFilterOptions.count))")
    }

    private var allEquipmentMenuTitle: String {
        String(localized: "All Equipment (\(profileRawEquipmentOptions.count))")
    }

    private var categoryFilterTitle: String {
        selectionTitle(selectedCategories)
    }

    private func categoryMenuTitle(_ categoryCount: ExerciseCategoryCount) -> String {
        categoryCount.category
    }

    private func resetFilters() {
        searchText = ""
        selectedSplitGroupTitles.removeAll()
        selectedLevels.removeAll()
        selectedRawEquipment.removeAll()
        selectedPrimaryMuscles.removeAll()
        selectedSecondaryMuscles.removeAll()
        selectedForces.removeAll()
        selectedMechanics.removeAll()
        selectedCategories.removeAll()
        selectedSort = .name
    }

    private func applyFilterState(_ state: ExerciseFilterState) {
        searchText = state.searchText
        selectedSplitGroupTitles = state.splitIdentifier == selectedWorkoutSplit.rawValue
            ? singleStoredSelection(state.splitGroups)
            : []
        selectedLevels = singleStoredSelection(state.levels)
        selectedRawEquipment = singleStoredSelection(state.rawEquipment)
        selectedPrimaryMuscles = singleStoredSelection(state.primaryMuscles)
        selectedSecondaryMuscles = singleStoredSelection(state.secondaryMuscles)
        selectedForces = singleStoredSelection(state.forces)
        selectedMechanics = singleStoredSelection(state.mechanics)
        selectedCategories = singleStoredSelection(state.categories)
        selectedSort = state.sort
    }

    private func normalizeSplitGroupSelection() {
        let validTitles = Set(splitGroups.map(\.title))
        selectedSplitGroupTitles = singleStoredSelection(selectedSplitGroupTitles.intersection(validTitles))
    }

    private func normalizePrimaryFilterSelection() {
        if !shouldShowPrimaryFilter {
            selectedPrimaryMuscles.removeAll()
            return
        }

        let validOptions = Set(primaryFilterOptions)
        guard !validOptions.isEmpty else {
            selectedPrimaryMuscles.removeAll()
            return
        }
        selectedPrimaryMuscles = singleStoredSelection(selectedPrimaryMuscles.intersection(validOptions))
    }

    private func normalizeEquipmentFilterSelection() {
        let validOptions = Set(profileRawEquipmentOptions)
        selectedRawEquipment = singleStoredSelection(selectedRawEquipment.intersection(validOptions))
    }

    private func selectionTitle(_ selection: Set<String>) -> String {
        if selection.isEmpty { return "All" }
        if selection.count == 1 { return selection.first ?? "All" }
        return String(localized: "\(selection.count) selected")
    }

    private func singleStoredSelection(_ selection: Set<String>) -> Set<String> {
        guard let value = selection.sorted().first else { return [] }
        return [value]
    }

    private func filterMenuPill(
        title: String,
        value: String,
        systemImage: String,
        isActive: Bool,
        items: [NeoGlassChoiceItem]
    ) -> some View {
        NeoGlassChoiceMenu(title: title, items: items) {
            FilterMenuPill(title: title, value: value, systemImage: systemImage, isActive: isActive)
        }
        .workoutPressable()
    }

    private var splitGroupFilterItems: [NeoGlassChoiceItem] {
        [choiceItem(
            id: "split.all",
            title: String(localized: "All \(bodyPartFilterTitle)"),
            systemImage: "square.grid.2x2",
            isSelected: selectedSplitGroupTitles.isEmpty
        ) { selectedSplitGroupTitles.removeAll() }] + splitGroups.map { group in
            choiceItem(
                id: "split.\(group.id)",
                title: group.title,
                systemImage: "figure.strengthtraining.traditional",
                isSelected: selectedSplitGroupTitles.contains(group.title)
            ) { selectedSplitGroupTitles = [group.title] }
        }
    }

    private var primaryFilterItems: [NeoGlassChoiceItem] {
        [choiceItem(id: "primary.all", title: allPrimaryMenuTitle, systemImage: "scope", isSelected: selectedPrimaryMuscles.isEmpty) {
            selectedPrimaryMuscles.removeAll()
        }] + primaryFilterOptions.map { muscle in
            choiceItem(id: "primary.\(muscle)", title: muscle, systemImage: "figure.strengthtraining.traditional", isSelected: selectedPrimaryMuscles.contains(muscle)) {
                selectedPrimaryMuscles = [muscle]
            }
        }
    }

    private var secondaryFilterItems: [NeoGlassChoiceItem] {
        [choiceItem(id: "secondary.all", title: String(localized: "All Secondary"), systemImage: "scope", isSelected: selectedSecondaryMuscles.isEmpty) {
            selectedSecondaryMuscles.removeAll()
        }] + service.availableSecondaryMuscles.map { muscle in
            choiceItem(id: "secondary.\(muscle)", title: muscle, systemImage: "figure.strengthtraining.traditional", isSelected: selectedSecondaryMuscles.contains(muscle)) {
                selectedSecondaryMuscles = [muscle]
            }
        }
    }

    private var equipmentFilterItems: [NeoGlassChoiceItem] {
        [choiceItem(id: "equipment.all", title: allEquipmentMenuTitle, systemImage: "dumbbell.fill", isSelected: selectedRawEquipment.isEmpty) {
            selectedRawEquipment.removeAll()
        }] + profileRawEquipmentOptions.map { equipment in
            choiceItem(id: "equipment.\(equipment)", title: equipment, systemImage: "dumbbell", isSelected: selectedRawEquipment.contains(equipment)) {
                selectedRawEquipment = [equipment]
            }
        }
    }

    private var levelFilterItems: [NeoGlassChoiceItem] {
        [choiceItem(id: "level.all", title: String(localized: "All Levels"), systemImage: "chart.bar.fill", isSelected: selectedLevels.isEmpty) {
            selectedLevels.removeAll()
        }] + service.availableLevels.map { level in
            choiceItem(id: "level.\(level)", title: level, systemImage: "chart.bar", isSelected: selectedLevels.contains(level)) {
                selectedLevels = [level]
            }
        }
    }

    private var forceFilterItems: [NeoGlassChoiceItem] {
        [choiceItem(id: "force.all", title: String(localized: "All Forces"), systemImage: "arrow.left.arrow.right", isSelected: selectedForces.isEmpty) {
            selectedForces.removeAll()
        }] + service.availableForces.map { force in
            choiceItem(id: "force.\(force)", title: force, systemImage: "arrow.left.arrow.right", isSelected: selectedForces.contains(force)) {
                selectedForces = [force]
            }
        }
    }

    private var mechanicFilterItems: [NeoGlassChoiceItem] {
        [choiceItem(id: "mechanic.all", title: String(localized: "All Mechanics"), systemImage: "gearshape", isSelected: selectedMechanics.isEmpty) {
            selectedMechanics.removeAll()
        }] + service.availableMechanics.map { mechanic in
            choiceItem(id: "mechanic.\(mechanic)", title: mechanic, systemImage: "gearshape.2", isSelected: selectedMechanics.contains(mechanic)) {
                selectedMechanics = [mechanic]
            }
        }
    }

    private var categoryFilterItems: [NeoGlassChoiceItem] {
        [choiceItem(id: "category.all", title: String(localized: "All Categories"), systemImage: "tag", isSelected: selectedCategories.isEmpty) {
            selectedCategories.removeAll()
        }] + service.availableCategoryCounts.map { categoryCount in
            choiceItem(id: "category.\(categoryCount.category)", title: categoryMenuTitle(categoryCount), systemImage: "tag.fill", isSelected: selectedCategories.contains(categoryCount.category)) {
                selectedCategories = [categoryCount.category]
            }
        }
    }

    private func choiceItem(
        id: String,
        title: String,
        systemImage: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> NeoGlassChoiceItem {
        NeoGlassChoiceItem(
            id: "workout.filter.\(id)",
            title: title,
            systemImage: systemImage,
            isSelected: isSelected,
            action: action
        )
    }
}

private struct WorkoutsSearchPill: View {
    @Binding var searchText: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.workoutAccent)

            TextField("Search", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(.subheadline, design: .rounded, weight: .black).width(.condensed))
                .foregroundStyle(Color.workoutCharcoal)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.workoutMutedText)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
        .kitchenTableSurface(
            fill: Color.workoutCard,
            border: Color.workoutHairline,
            cornerRadius: 16,
            lineWidth: NeoAppMetrics.rule,
            shadowRadius: 3,
            shadowY: 1
        )
    }
}

private struct FilterMenuPill: View {
    let title: String
    let value: String
    let systemImage: String
    let isActive: Bool

    private var isDefaultValue: Bool {
        !isActive
    }

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(isDefaultValue ? Color.workoutSecondaryAccent : Color.black)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 10, weight: .black, design: .rounded).width(.condensed))
                    .foregroundStyle(isDefaultValue ? Color.workoutMutedText : Color.black.opacity(0.72))
                    .textCase(.uppercase)
                    .lineLimit(1)

                Text(value)
                    .font(.system(.subheadline, design: .rounded, weight: .black).width(.condensed))
                    .foregroundStyle(isDefaultValue ? Color.workoutCharcoal : Color.black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            Image(systemName: "chevron.down")
                .font(.caption2.weight(.bold))
                .foregroundStyle(isDefaultValue ? Color.workoutMutedText : Color.black)
                .padding(.leading, 1)
        }
        .padding(.horizontal, 12)
        .frame(minWidth: 112, minHeight: 46, alignment: .leading)
        .background(isDefaultValue ? Color.workoutCard : NeoAppColors.acid)
        .overlay {
            Rectangle()
                .stroke(Color.workoutHairline, lineWidth: NeoAppMetrics.compactRule)
        }
        .contentShape(Rectangle())
    }
}

private struct ResultsHeader: View {
    let count: Int
    let noun: String
    let subtitle: String
    @Binding var selectedSort: ExerciseLibrarySort
    let canReset: Bool
    let onReset: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(count) \(count == 1 ? noun : String(localized: "\(noun)s"))")
                    .font(.system(.headline, design: .rounded, weight: .black).width(.condensed))
                    .foregroundStyle(Color.workoutCharcoal)
                    .textCase(.uppercase)
                Text(subtitle)
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(Color.workoutMutedText)
                    .textCase(nil)
            }

            Spacer()

            HStack(spacing: 8) {
                Button {
                    onReset()
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                        .font(.system(.caption, design: .rounded, weight: .black).width(.condensed))
                        .foregroundStyle(canReset ? Color.workoutInferno : Color.workoutMutedText)
                        .lineLimit(1)
                        .padding(.horizontal, 11)
                        .frame(height: 34)
                        .background(canReset ? Color.workoutInferno.opacity(0.16) : Color.workoutPanel)
                        .overlay {
                            Rectangle()
                                .stroke(canReset ? Color.workoutInferno : Color.workoutHairline, lineWidth: NeoAppMetrics.compactRule)
                        }
                }
                .disabled(!canReset)
                .buttonStyle(.plain)
                .workoutPressable()

                NeoGlassChoiceMenu(
                    title: String(localized: "Sort Exercises"),
                    items: ExerciseLibrarySort.allCases.map { sort in
                        NeoGlassChoiceItem(
                            id: "workout.results.sort.\(sort.id)",
                            title: sort.title,
                            systemImage: "arrow.up.arrow.down",
                            isSelected: selectedSort == sort
                        ) { selectedSort = sort }
                    }
                ) {
                    Label("Sort", systemImage: "arrow.up.arrow.down")
                        .font(.system(.caption, design: .rounded, weight: .black).width(.condensed))
                        .foregroundStyle(count == 0 ? Color.workoutMutedText : (selectedSort == .name ? Color.workoutMutedText : Color.black))
                        .lineLimit(1)
                        .padding(.horizontal, 11)
                        .frame(height: 34)
                        .background(selectedSort == .name ? Color.workoutPanel : NeoAppColors.acid)
                        .overlay {
                            Rectangle()
                                .stroke(Color.workoutHairline, lineWidth: NeoAppMetrics.compactRule)
                        }
                }
                .buttonStyle(.plain)
                .workoutPressable()
                .disabled(count == 0)
            }
        }
        .padding(10)
        .kitchenTableSurface(
            fill: Color.workoutCard,
            border: Color.workoutHairline,
            cornerRadius: 16,
            lineWidth: NeoAppMetrics.rule,
            shadowRadius: 4,
            shadowY: 2
        )
    }
}

private struct ExerciseLibraryRow: View {
    let item: ExerciseLibraryItem

    var body: some View {
        HStack(spacing: 16) {
            thumbnail

            VStack(alignment: .leading, spacing: 9) {
                Text(item.name)
                    .font(.system(.headline, design: .rounded, weight: .black).width(.condensed))
                    .foregroundStyle(Color.workoutCharcoal)
                    .textCase(.uppercase)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        LibraryTag(title: item.primaryMusclesTitle, systemImage: "scope", tint: Color.workoutMutedText)
                        LibraryTag(title: item.rawEquipment, systemImage: "dumbbell.fill", tint: Color.workoutMutedText)
                        LibraryTag(title: item.rawLevel, systemImage: "chart.bar.fill", tint: Color.workoutMutedText)
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        LibraryTag(title: item.primaryMusclesTitle, systemImage: "scope", tint: Color.workoutMutedText)
                        LibraryTag(title: "\(item.rawEquipment) - \(item.rawLevel)", systemImage: "dumbbell.fill", tint: Color.workoutMutedText)
                    }
                }

                Label(item.databaseMetadataSummary, systemImage: "server.rack")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.workoutSecondaryAccent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.workoutAccent)
        }
        .padding(10)
        .kitchenTableSurface(
            fill: Color.workoutCard,
            border: Color.workoutHairline,
            cornerRadius: 18,
            lineWidth: NeoAppMetrics.rule,
            shadowRadius: 5,
            shadowY: 2
        )
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var thumbnail: some View {
        AnimatedExerciseVisual(
            exerciseName: item.name,
            imagePaths: item.imagePaths,
            height: 104,
            fillsWidth: false,
            allowsDerivedImageLookup: false
        )
        .frame(width: 104, height: 104)
        .background(Color.workoutPanel)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.workoutHairline, lineWidth: NeoAppMetrics.compactRule)
        }
        .accessibilityHidden(true)
    }

}

private struct LibraryTag: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.system(.caption2, design: .rounded, weight: .black).width(.condensed))
            .labelStyle(.titleAndIcon)
            .foregroundStyle(tint)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Color.workoutPanel, in: Capsule())
            .overlay {
                Capsule().stroke(Color.workoutHairline, lineWidth: NeoAppMetrics.compactRule)
            }
            .accessibilityElement(children: .combine)
    }
}

struct ExerciseLibraryDetailView: View {
    let item: ExerciseLibraryItem
    @State private var isMetricsPresented = false

    var body: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width

            ZStack(alignment: .top) {
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 0) {
                        Color.clear
                            .frame(width: screenWidth, height: 294)

                        VStack(alignment: .leading, spacing: 24) {
                            DetailInstructionSection(instructions: item.instructions)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                        .padding(.bottom, 40)
                        .frame(width: screenWidth, alignment: .leading)
                    }
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)

                detailHero(width: screenWidth)
                    .zIndex(1)
            }
            .frame(width: screenWidth, alignment: .top)
        }
        .workoutScreen()
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(Color.workoutBackground, for: .navigationBar)
    }

    private func detailHero(width: CGFloat) -> some View {
        ZStack(alignment: .topTrailing) {
            AnimatedExerciseVisual(
                exerciseName: item.name,
                imagePaths: item.imagePaths,
                height: 294,
                allowsDerivedImageLookup: false
            )
            .frame(width: width, height: 294)
            .frame(width: width, height: 294, alignment: .bottomLeading)

            if isMetricsPresented {
                Color.black.opacity(0.5)
                    .frame(width: width, height: 294)
                    .allowsHitTesting(false)
                    .transition(.opacity)

                ExerciseHeroMetricOverlay(item: item)
                    .padding(.top, 8)
                    .padding(.leading, 24)
                    .padding(.trailing, 84)
                    .frame(width: width, height: 294, alignment: .topLeading)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            }

            Button {
                withAnimation(.snappy(duration: 0.28)) {
                    isMetricsPresented.toggle()
                }
            } label: {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(KitchenTablePalette.onBrass)
                    .frame(width: 44, height: 44)
                    .background(NeoAppColors.brass, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(KitchenTablePalette.brassDeep, lineWidth: NeoAppMetrics.rule)
                    }
            }
            .buttonStyle(.plain)
            .workoutPressable()
            .padding(.top, 14)
            .padding(.trailing, 16)
            .accessibilityLabel(isMetricsPresented ? String(localized: "Hide exercise details") : String(localized: "Show exercise details"))
        }
        .frame(width: width, height: 294)
        .animation(.snappy(duration: 0.28), value: isMetricsPresented)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.workoutHairline, lineWidth: NeoAppMetrics.rule)
        }
        .shadow(color: KitchenTablePalette.shadow, radius: 7, x: 0, y: 3)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(item.name) exercise visual"))
    }

}

private struct ExerciseHeroMetricOverlay: View {
    let item: ExerciseLibraryItem
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .center, spacing: 6) {
            HStack(spacing: 8) {
                metricButton(title: String(localized: "Level"), value: item.rawLevel, systemImage: "chart.bar.fill", compact: true)
                metricButton(title: String(localized: "Category"), value: item.category, systemImage: "tag", compact: true)
            }

            HStack(spacing: 8) {
                metricButton(title: String(localized: "Force"), value: item.force, systemImage: "arrow.left.arrow.right", compact: true)
                metricButton(title: String(localized: "Mechanic"), value: item.mechanic, systemImage: "gearshape", compact: true)
            }

            metricButton(title: String(localized: "Primary"), value: item.primaryMusclesTitle, systemImage: "scope", compact: false, valueLineLimit: 2)
            metricButton(title: String(localized: "Secondary"), value: item.secondaryMusclesTitle, systemImage: "scope", compact: false, valueLineLimit: 3)
            metricButton(title: String(localized: "Equipment"), value: item.rawEquipment, systemImage: "dumbbell.fill", compact: false, valueLineLimit: 2)
        }
        .frame(maxWidth: .infinity)
    }

    private func metricButton(title: String, value: String, systemImage: String, compact: Bool = true, valueLineLimit: Int = 1) -> some View {
        let valueFontSize: CGFloat = compact ? 15 : (valueLineLimit > 2 ? 13 : 14)
        let labelColor = colorScheme == .light ? Color.workoutSecondaryAccent : Color.workoutAccent
        let fillColor = Color.workoutCard
        let strokeColor = Color.workoutHairline

        return VStack(alignment: .leading, spacing: 3) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(labelColor)
                .lineLimit(1)

            Text(value)
                .font(.system(size: valueFontSize, weight: .bold, design: .rounded))
                .foregroundStyle(Color.workoutCharcoal)
                .lineLimit(valueLineLimit)
                .minimumScaleFactor(0.50)
                .allowsTightening(true)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, compact ? 6 : 5)
        .frame(maxWidth: .infinity, minHeight: compact ? 44 : (valueLineLimit > 2 ? 50 : 42), alignment: .leading)
        .background(fillColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(strokeColor, lineWidth: NeoAppMetrics.compactRule)
        }
    }
}

private struct DetailInstructionSection: View {
    let instructions: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "list.number")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(KitchenTablePalette.onBrass)
                    .frame(width: 30, height: 30)
                    .background(NeoAppColors.brass, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(Color.workoutHairline, lineWidth: NeoAppMetrics.compactRule)
                    }

                Text("Instructions")
                    .font(.system(.title3, design: .rounded, weight: .black).width(.condensed))
                    .textCase(.uppercase)
                    .foregroundStyle(Color.workoutCharcoal)

                Spacer(minLength: 0)

                Text("\(instructions.count)")
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(NeoAppColors.brass, in: Capsule())
                    .overlay {
                        Capsule().stroke(Color.workoutHairline, lineWidth: NeoAppMetrics.compactRule)
                    }
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(instructions.enumerated()), id: \.offset) { index, instruction in
                    HStack(alignment: .top, spacing: 13) {
                        Text("\(index + 1)")
                            .font(.subheadline.weight(.heavy))
                            .monospacedDigit()
                            .foregroundStyle(Color.workoutOnAccent)
                            .frame(width: 27, height: 27)
                            .background(Color.workoutAccent)

                        Text(instruction)
                            .font(.callout)
                            .foregroundStyle(Color.workoutCharcoal.opacity(0.86))
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(14)
                    .background(Color.workoutCard)
                    .overlay {
                        Rectangle()
                            .stroke(Color.workoutHairline, lineWidth: NeoAppMetrics.compactRule)
                    }
                }
            }
        }
    }
}

private struct WorkoutsScreenBackground: View {
    var body: some View {
        WorkoutBackground()
    }
}
