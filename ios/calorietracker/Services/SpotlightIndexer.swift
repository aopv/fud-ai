import CoreSpotlight
import Foundation

/// Indexes FoodEntry objects in CoreSpotlight so users can search their food log
/// from the iOS home screen Spotlight search.
enum SpotlightIndexer {
    private static let domain = "ai.fud.food"

    static func index(_ entry: FoodEntry) {
        CSSearchableIndex.default().indexSearchableItems([makeItem(entry)]) { error in
            if let error { print("[Spotlight] index failed: \(error)") }
        }
    }

    static func remove(id: UUID) {
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [id.uuidString]) { error in
            if let error { print("[Spotlight] remove failed: \(error)") }
        }
    }

    /// Full rebuild — called when entries are replaced wholesale (e.g. import / clear).
    static func reindexAll(_ entries: [FoodEntry]) {
        let items = entries.map { makeItem($0) }
        CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: [domain]) { _ in
            CSSearchableIndex.default().indexSearchableItems(items) { error in
                if let error { print("[Spotlight] reindex failed: \(error)") }
            }
        }
    }

    // Internal (not private) so SpotlightIndexerTests can verify the expiration
    // logic without indexing into the real CoreSpotlight index.
    static func makeItem(_ entry: FoodEntry) -> CSSearchableItem {
        let attributes = CSSearchableItemAttributeSet(contentType: .text)
        let prefix = entry.emoji.map { "\($0) " } ?? ""
        attributes.title = prefix + entry.name
        attributes.contentDescription = "\(entry.calories) kcal · \(String(format: "%.0f", entry.protein))g protein · \(entry.mealType.displayName)"
        attributes.keywords = [entry.name, entry.mealType.displayName, "food", "calories", "nutrition", "fud ai"]

        let item = CSSearchableItem(
            uniqueIdentifier: entry.id.uuidString,
            domainIdentifier: domain,
            attributeSet: attributes
        )
        // Expire 30 days after indexing, not after the entry's own date — otherwise
        // imported/back-dated entries older than 30 days get a past expiration and
        // are dropped from the index immediately, so they'd never be searchable.
        item.expirationDate = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
        return item
    }
}
