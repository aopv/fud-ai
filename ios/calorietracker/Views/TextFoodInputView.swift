import SwiftUI
import Combine

struct TextFoodInputView: View {
    @State private var foodDescription = ""
    @State private var placeholderIndex = 0
    @FocusState private var isFocused: Bool

    var onCancel: () -> Void
    var onSubmit: (String) -> Void

    private let placeholders = [
        "2 eggs, toast with butter and a coffee",
        "Chipotle burrito bowl with chicken and rice",
        "Domino's pepperoni pizza, 2 slices",
        "Greek yogurt with granola and blueberries",
    ]

    private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 14) {
            NeoSectionBanner(title: "Describe Meal", detail: "AI INPUT", style: .cobalt)

            ZStack(alignment: .topLeading) {
                if foodDescription.isEmpty {
                    Text(placeholders[placeholderIndex])
                        .foregroundStyle(NeoAppColors.mutedInk)
                        .font(.system(.body, design: .rounded, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 14)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        ))
                        .id(placeholderIndex)
                        .allowsHitTesting(false)
                }

                TextField("", text: $foodDescription, axis: .vertical)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(NeoAppColors.ink)
                    .lineLimit(2...5)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .focused($isFocused)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 14)
            }
            .frame(minHeight: 112, alignment: .topLeading)
            .kitchenTableSurface(
                fill: NeoAppColors.surface,
                border: KitchenTablePalette.rule,
                cornerRadius: 16,
                lineWidth: NeoAppMetrics.rule,
                shadowRadius: 4,
                shadowY: 2
            )
            .accessibilityIdentifier("quickAdd.text.description")

            Button {
                onSubmit(foodDescription)
            } label: {
                Text("Analyze")
                    .textCase(.uppercase)
                    .font(.system(.headline, design: .rounded, weight: .black))
                    .foregroundStyle(KitchenTablePalette.onStrongAccent)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 50)
                    .background(NeoAppColors.tomato, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(KitchenTablePalette.tomatoDeep, lineWidth: NeoAppMetrics.rule)
                    }
            }
            .buttonStyle(KitchenTablePressableButtonStyle())
            .disabled(foodDescription.trimmingCharacters(in: .whitespaces).isEmpty)
            .opacity(foodDescription.trimmingCharacters(in: .whitespaces).isEmpty ? 0.45 : 1)
            .accessibilityIdentifier("quickAdd.text.analyze")

            Button {
                onCancel()
            } label: {
                Text("Cancel")
                    .textCase(.uppercase)
                    .font(.system(.subheadline, design: .rounded, weight: .black))
                    .foregroundStyle(NeoAppColors.cobalt)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                    .background(NeoAppColors.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(NeoAppColors.cobalt, lineWidth: NeoAppMetrics.rule)
                    }
            }
            .buttonStyle(KitchenTablePressableButtonStyle())
            .accessibilityIdentifier("quickAdd.text.cancel")
        }
        .padding(14)
        .frame(width: 320)
        .background(KitchenTableBackdrop())
        .onAppear { isFocused = true }
        .onReceive(timer) { _ in
            guard foodDescription.isEmpty else { return }
            withAnimation(.easeInOut(duration: 0.3)) {
                placeholderIndex = (placeholderIndex + 1) % placeholders.count
            }
        }
    }
}
