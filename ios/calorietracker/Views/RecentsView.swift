import SwiftUI

enum SavedMealsMode: String, Identifiable {
    case recent = "Recent"
    case frequent = "Frequent"
    case favorites = "Favorites"

    var id: String { rawValue }
}

struct RecentsView: View {
    let mode: SavedMealsMode
    let logDate: Date
    var onReview: ((FoodEntry) -> Void)? = nil

    @Environment(FoodStore.self) private var foodStore
    @Environment(\.dismiss) private var dismiss

    @State private var searchText: String = ""

    private var recentItems: [FoodEntry] {
        let items = foodStore.recentEntries(days: 30)
        return filterByName(items) { $0.name }
    }

    private var frequentItems: [FrequentFoodGroup] {
        let items = foodStore.frequentGroups(days: 90)
        return filterByName(items) { $0.template.name }
    }

    private var favoriteItems: [FoodEntry] {
        filterByName(foodStore.favorites) { $0.name }
    }

    /// Substring, case-insensitive, diacritic-insensitive match against the
    /// extracted name. Empty query returns the full list unchanged.
    private func filterByName<T>(_ items: [T], name: (T) -> String) -> [T] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return items }
        return items.filter { item in
            name(item).range(of: q, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NeoScreenHeader(
                        eyebrow: "SAVED FOOD",
                        title: mode.rawValue,
                        subtitle: "Tap any meal to review it before logging."
                    )
                }
                .listRowInsets(EdgeInsets(top: 12, leading: 14, bottom: 2, trailing: 14))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                switch mode {
                case .recent:
                    if recentItems.isEmpty {
                        emptySection(
                            icon: isSearching ? "magnifyingglass" : "clock",
                            message: isSearching ? "No matching foods" : "No foods logged yet"
                        )
                    } else {
                        Section {
                            ForEach(recentItems) { entry in
                                Button {
                                    logEntry(entry)
                                } label: {
                                    SavedMealRow(entry: entry, isFavorite: foodStore.isFavorite(entry))
                                }
                                    .buttonStyle(.plain)
                                    .savedMealRowStyle(entry: entry, isFavorite: foodStore.isFavorite(entry))
                                    .swipeActions(edge: .trailing) {
                                        Button {
                                            withAnimation { foodStore.toggleFavorite(entry) }
                                        } label: {
                                            Label(foodStore.isFavorite(entry) ? "Unfavorite" : "Favorite", systemImage: foodStore.isFavorite(entry) ? "heart.slash.fill" : "heart.fill")
                                        }
                                        .tint(NeoAppColors.cobalt)
                                    }
                            }
                        }
                    }

                case .frequent:
                    if frequentItems.isEmpty {
                        emptySection(
                            icon: isSearching ? "magnifyingglass" : "repeat",
                            message: isSearching ? "No matching foods" : "No foods logged yet"
                        )
                    } else {
                        Section {
                            ForEach(frequentItems) { group in
                                Button {
                                    logEntry(group.template)
                                } label: {
                                    SavedMealRow(
                                        entry: group.template,
                                        isFavorite: foodStore.isFavorite(group.template),
                                        subtitle: "\(group.count)× logged"
                                    )
                                }
                                    .buttonStyle(.plain)
                                    .savedMealRowStyle(entry: group.template, isFavorite: foodStore.isFavorite(group.template))
                                    .swipeActions(edge: .trailing) {
                                        Button {
                                            withAnimation { foodStore.toggleFavorite(group.template) }
                                        } label: {
                                            Label(foodStore.isFavorite(group.template) ? "Unfavorite" : "Favorite", systemImage: foodStore.isFavorite(group.template) ? "heart.slash.fill" : "heart.fill")
                                        }
                                        .tint(NeoAppColors.cobalt)
                                    }
                            }
                        }
                    }

                case .favorites:
                    if favoriteItems.isEmpty {
                        emptySection(
                            icon: isSearching ? "magnifyingglass" : "heart",
                            message: isSearching ? "No matching favorites" : "No favorites yet\nSwipe left on any food to add it"
                        )
                    } else {
                        Section {
                            ForEach(favoriteItems) { entry in
                                Button {
                                    logEntry(entry)
                                } label: {
                                    SavedMealRow(entry: entry, isFavorite: true)
                                }
                                    .buttonStyle(.plain)
                                    .savedMealRowStyle(entry: entry, isFavorite: true)
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            withAnimation { foodStore.toggleFavorite(entry) }
                                        } label: {
                                            Label("Remove", systemImage: "heart.slash.fill")
                                        }
                                    }
                            }
                            // Reorder is only meaningful on the unfiltered list — the
                            // ForEach indices we'd hand to moveFavorite are the
                            // filtered indices, which don't map back to favorites
                            // when a search is active.
                            .onMove(perform: isSearching ? nil : { from, to in
                                foodStore.moveFavorite(from: from, to: to)
                            })
                        }
                    }
                }
            }
            .listStyle(.plain)
            .listSectionSpacing(NeoAppMetrics.sectionSpacing)
            .neoScreen()
            .navigationTitle(mode.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: Text("Search saved foods"))
            .tint(NeoAppColors.cobalt)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                // Hide the EditButton while searching — drag-to-reorder writes
                // back to the unfiltered favorites list using the rendered row
                // indices, so a filtered list would reorder the wrong items.
                if mode == .favorites && !foodStore.favorites.isEmpty && !isSearching {
                    ToolbarItem(placement: .topBarTrailing) {
                        EditButton()
                    }
                }
            }
        }
    }

    private func logEntry(_ entry: FoodEntry) {
        let prepared = entry.duplicatedForLogging(at: logDate)
        dismiss()
        if let onReview {
            onReview(prepared)
        } else {
            foodStore.addEntry(prepared)
        }
    }

    private func emptySection(icon: String, message: String) -> some View {
        Section {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 32, weight: .black))
                    .foregroundStyle(NeoAppColors.cobalt)
                Text(message)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(NeoAppColors.mutedInk)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .neoPanel(fill: NeoAppColors.surface)
            .accessibilityElement(children: .combine)
        }
        .listRowInsets(EdgeInsets(top: 0, leading: 14, bottom: 0, trailing: 14))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
}

private extension View {
    func savedMealRowStyle(entry: FoodEntry, isFavorite: Bool) -> some View {
        self
            .padding(12)
            .background(NeoAppColors.surface)
            .overlay {
                Rectangle().stroke(NeoAppColors.ink, lineWidth: NeoAppMetrics.rule)
            }
            .contentShape(Rectangle())
            .listRowInsets(EdgeInsets(top: 4, leading: 14, bottom: 4, trailing: 14))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(entry.name)
            .accessibilityValue("\(entry.calories) calories\(isFavorite ? ", favorite" : "")")
            .accessibilityHint("Reviews this food before logging")
            .accessibilityIdentifier("savedMeal.\(entry.id)")
    }
}

// MARK: - Saved Meal Row

private struct SavedMealRow: View {
    let entry: FoodEntry
    let isFavorite: Bool
    var subtitle: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            if let imageData = entry.imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(Rectangle())
                    .overlay(
                        Rectangle()
                            .strokeBorder(NeoAppColors.ink, lineWidth: NeoAppMetrics.compactRule)
                    )
            } else if let emoji = entry.emoji {
                Text(emoji)
                    .font(.system(size: 28))
                    .frame(width: 56, height: 56)
                    .background(NeoAppColors.subtleSurface)
                    .overlay {
                        Rectangle().stroke(NeoAppColors.ink, lineWidth: NeoAppMetrics.compactRule)
                    }
            } else {
                Image(systemName: "fork.knife")
                    .font(.title3.weight(.black))
                    .foregroundStyle(NeoAppColors.cobalt)
                    .frame(width: 56, height: 56)
                    .background(NeoAppColors.subtleSurface)
                    .overlay {
                        Rectangle().stroke(NeoAppColors.ink, lineWidth: NeoAppMetrics.compactRule)
                    }
            }

            // Info
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(entry.name)
                        .font(.system(.body, design: .rounded, weight: .black))
                        .foregroundStyle(NeoAppColors.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    if isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.caption2)
                            .foregroundStyle(NeoAppColors.cobalt)
                    }
                }

                HStack(spacing: 6) {
                    Text("\(entry.calories) kcal")
                        .font(.system(.subheadline, design: .rounded, weight: .black))
                        .foregroundStyle(NeoAppColors.cobalt)

                    if let subtitle {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text(subtitle)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(NeoAppColors.mutedInk)
                    }
                }

                HStack(spacing: 8) {
                    MacroTag(label: "P", value: entry.protein)
                    MacroTag(label: "C", value: entry.carbs)
                    MacroTag(label: "F", value: entry.fat)
                }
            }

            Spacer(minLength: 0)

            // Log button
            Image(systemName: "plus")
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(Color.black)
                .frame(width: 36, height: 36)
                .background(NeoAppColors.acid)
                .overlay {
                    Rectangle().stroke(NeoAppColors.ink, lineWidth: NeoAppMetrics.rule)
                }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Macro Tag

private struct MacroTag: View {
    let label: String
    let value: Double

    var body: some View {
        Text("\(label) \(MacroValueFormatter.withUnit(value))")
            .font(.system(.caption2, design: .rounded, weight: .black))
            .foregroundStyle(NeoAppColors.ink)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(NeoAppColors.acid.opacity(0.48))
            .overlay {
                Rectangle().stroke(NeoAppColors.ink, lineWidth: NeoAppMetrics.compactRule)
            }
    }
}
