import CoreSpotlight
import Foundation
import Testing
@testable import calorietracker

/// Verifies the Spotlight item built for a food entry — in particular the
/// expiration fix: an entry's searchable lifetime is measured from *now*
/// (index time), not from the entry's own (possibly old/imported) timestamp.
struct SpotlightIndexerTests {

    private func makeEntry(name: String, timestamp: Date) -> FoodEntry {
        FoodEntry(
            name: name,
            calories: 200,
            protein: 10,
            carbs: 20,
            fat: 5,
            timestamp: timestamp,
            emoji: "🍎",
            source: .textInput,
            mealType: .other
        )
    }

    /// Regression test for the bug where expiration = entry.timestamp + 30d.
    /// An entry dated 60 days ago must NOT already be expired, otherwise
    /// imported/back-dated history would never appear in Spotlight search.
    @Test func oldEntryIsNotImmediatelyExpired() {
        let sixtyDaysAgo = Calendar.current.date(byAdding: .day, value: -60, to: Date())!
        let item = SpotlightIndexer.makeItem(makeEntry(name: "Old import", timestamp: sixtyDaysAgo))

        let expiration = try! #require(item.expirationDate)
        #expect(expiration > Date(), "Expiration must be in the future even for old entries")
    }

    /// Expiration should sit ~30 days out from now regardless of the entry date.
    @Test func expirationIsRoughlyThirtyDaysFromNow() {
        let expected = Calendar.current.date(byAdding: .day, value: 30, to: Date())!

        for daysAgo in [0, -1, -60, -365] {
            let ts = Calendar.current.date(byAdding: .day, value: daysAgo, to: Date())!
            let item = SpotlightIndexer.makeItem(makeEntry(name: "E\(daysAgo)", timestamp: ts))
            let expiration = try! #require(item.expirationDate)
            // Allow a generous 1-hour window for test execution time / DST math.
            #expect(abs(expiration.timeIntervalSince(expected)) < 3600,
                    "daysAgo=\(daysAgo): expiration should be ~30 days from now")
        }
    }

    @Test func itemCarriesIdentifierTitleAndKeywords() {
        let entry = makeEntry(name: "Banana", timestamp: Date())
        let item = SpotlightIndexer.makeItem(entry)

        #expect(item.uniqueIdentifier == entry.id.uuidString)
        // Emoji is prefixed to the title.
        #expect(item.attributeSet.title == "🍎 Banana")
        #expect(item.attributeSet.keywords?.contains("Banana") == true)
    }
}
