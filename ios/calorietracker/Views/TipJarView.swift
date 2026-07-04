//
//  TipJarView.swift
//  calorietracker
//

import SwiftUI
import RevenueCat

/// Food-themed tip jar, inlined in the Settings About section as a disclosure row
/// (same pattern as What's New) — no separate sheet. Tips are consumable IAPs that
/// fund development; everything in the app is already unlocked, so they grant nothing.
struct TipJarDisclosureRow: View {
    private struct Tier: Identifiable {
        let productID: String
        let icon: String
        let name: String
        var id: String { productID }
    }

    private static let tiers: [Tier] = [
        Tier(productID: "com.apoorvdarshan.calorietracker.tip.snack",
             icon: "tip_snack", name: String(localized: "Snack")),
        Tier(productID: "com.apoorvdarshan.calorietracker.tip.proteinshake",
             icon: "tip_proteinshake", name: String(localized: "Protein Shake")),
        Tier(productID: "com.apoorvdarshan.calorietracker.tip.lunch",
             icon: "tip_lunch", name: String(localized: "Lunch")),
        Tier(productID: "com.apoorvdarshan.calorietracker.tip.feast",
             icon: "tip_feast", name: String(localized: "Feast"))
    ]

    @State private var isExpanded = false
    @State private var products: [String: StoreProduct] = [:]
    @State private var isLoading = true
    @State private var purchasingID: String?
    @State private var didTip = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 10) {
                if didTip {
                    HStack(spacing: 8) {
                        Text("🩷")
                        Text("Thank you!")
                            .font(.subheadline.weight(.semibold))
                        Text("Your support keeps Fud AI free for everyone.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Fud AI is free and open source — no subscriptions, no paywalls, everything already unlocked. If it's helped you, a tip keeps it that way.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                ForEach(Self.tiers) { tier in
                    tierRow(tier)
                }

                Text("Don't worry — tips have zero calories.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)
        } label: {
            Label {
                Text("Leave a Tip")
            } icon: {
                Image(systemName: "heart.fill")
                    .foregroundStyle(AppColors.calorie)
            }
        }
        .tint(.primary)
        .task(id: isExpanded) {
            if isExpanded && products.isEmpty { await loadProducts() }
        }
    }

    @ViewBuilder
    private func tierRow(_ tier: Tier) -> some View {
        let product = products[tier.productID]
        Button {
            if let product { Task { await purchase(product) } }
        } label: {
            HStack(spacing: 10) {
                // PixelLab-generated pixel art; .none interpolation keeps pixels crisp.
                Image(tier.icon)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(width: 26, height: 26)
                Text(tier.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                Spacer()
                if purchasingID == tier.productID || (product == nil && isLoading) {
                    ProgressView()
                } else if let product {
                    Text(product.localizedPriceString)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColors.calorie)
                } else {
                    // Store unreachable (offline, or products still propagating).
                    Image(systemName: "wifi.slash")
                        .foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(product == nil || purchasingID != nil)
    }

    private func loadProducts() async {
        isLoading = true
        let fetched = await Purchases.shared.products(Self.tiers.map(\.productID))
        products = Dictionary(uniqueKeysWithValues: fetched.map { ($0.productIdentifier, $0) })
        isLoading = false
    }

    private func purchase(_ product: StoreProduct) async {
        purchasingID = product.productIdentifier
        defer { purchasingID = nil }
        do {
            let result = try await Purchases.shared.purchase(product: product)
            if !result.userCancelled {
                didTip = true
            }
        } catch {
            // Cancelled or failed — the rows simply stay usable.
        }
    }
}
