//
//  TipJarView.swift
//  calorietracker
//

import SwiftUI
import RevenueCat

/// Food-themed tip jar. Tips are consumable IAPs that fund development —
/// everything in the app is already unlocked, so they deliberately grant nothing.
struct TipJarView: View {
    @Environment(\.dismiss) private var dismiss

    private struct Tier: Identifiable {
        let productID: String
        let emoji: String
        let name: String
        var id: String { productID }
    }

    private static let tiers: [Tier] = [
        Tier(productID: "com.apoorvdarshan.calorietracker.tip.snack",
             emoji: "🍎", name: String(localized: "Snack")),
        Tier(productID: "com.apoorvdarshan.calorietracker.tip.proteinshake",
             emoji: "🥤", name: String(localized: "Protein Shake")),
        Tier(productID: "com.apoorvdarshan.calorietracker.tip.lunch",
             emoji: "🍱", name: String(localized: "Lunch")),
        Tier(productID: "com.apoorvdarshan.calorietracker.tip.feast",
             emoji: "🎉", name: String(localized: "Feast"))
    ]

    @State private var products: [String: StoreProduct] = [:]
    @State private var isLoading = true
    @State private var purchasingID: String?
    @State private var showThanks = false

    var body: some View {
        NavigationStack {
            Group {
                if showThanks {
                    thanksView
                } else {
                    tipList
                }
            }
            .background(AppColors.appBackground)
            .navigationTitle(Text("Tip Jar"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task { await loadProducts() }
    }

    private var tipList: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Fud AI is free and open source — no subscriptions, no paywalls, everything already unlocked. If it's helped you, a tip keeps it that way.")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.primary)
                    Text("Don't worry — tips have zero calories.")
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 8, leading: 4, bottom: 4, trailing: 4))
            }

            Section {
                ForEach(Self.tiers) { tier in
                    tierRow(tier)
                }
            }
            .listRowBackground(AppColors.appCard)
        }
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private func tierRow(_ tier: Tier) -> some View {
        let product = products[tier.productID]
        Button {
            if let product { Task { await purchase(product) } }
        } label: {
            HStack(spacing: 12) {
                Text(tier.emoji)
                    .font(.title2)
                Text(tier.name)
                    .font(.system(.body, design: .rounded, weight: .medium))
                    .foregroundStyle(.primary)
                Spacer()
                if purchasingID == tier.productID {
                    ProgressView()
                } else if let product {
                    Text(product.localizedPriceString)
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(AppColors.calorie)
                } else if isLoading {
                    ProgressView()
                } else {
                    // Store unreachable (offline, or products still propagating).
                    Image(systemName: "wifi.slash")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .disabled(product == nil || purchasingID != nil)
    }

    private var thanksView: some View {
        VStack(spacing: 14) {
            Text("🩷")
                .font(.system(size: 64))
            Text("Thank you!")
                .font(.system(.title2, design: .rounded, weight: .bold))
            Text("Your support keeps Fud AI free for everyone.")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppColors.calorie, in: Capsule())
                    .foregroundStyle(.white)
            }
            .padding(.top, 12)
        }
        .padding(28)
    }

    private func loadProducts() async {
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
                showThanks = true
            }
        } catch {
            // Cancelled or failed — no alert needed; the sheet simply stays usable.
        }
    }
}
