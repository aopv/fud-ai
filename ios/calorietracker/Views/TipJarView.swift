//
//  TipJarView.swift
//  calorietracker
//

import SwiftUI
import RevenueCat

/// Compact food-themed tip rows shown immediately before About in Settings.
/// Tips are consumable IAPs that fund development; everything in the app is
/// already unlocked, so they grant nothing.
struct TipJarSettingsSection: View {
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

    @State private var products: [String: StoreProduct] = [:]
    @State private var isLoading = true
    @State private var purchasingID: String?
    @State private var didTip = false

    var body: some View {
        Section("Leave a Tip") {
            ForEach(Self.tiers) { tier in
                tierRow(tier)
            }
        }
        .listRowBackground(AppColors.appCard)
        .task {
            if products.isEmpty { await loadProducts() }
        }
        .alert("Thank you!", isPresented: $didTip) {
            Button("Done", role: .cancel) {}
        } message: {
            Text("Your support keeps Fud AI free for everyone.")
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
                    .frame(width: 24, height: 24)
                Text(tier.name)
                    .foregroundStyle(.primary)
                Spacer()
                if purchasingID == tier.productID || (product == nil && isLoading) {
                    ProgressView()
                } else if let product {
                    Text(product.localizedPriceString)
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
