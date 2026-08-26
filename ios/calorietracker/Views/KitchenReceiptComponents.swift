import SwiftUI

/// Small presentation primitives for the paper receipts and workout tickets
/// used by Progress, Workouts, and their Settings section. These views are
/// deliberately data-free so feature state and actions stay at their existing
/// call sites.
struct KitchenReceiptRule: View {
    var color: Color = KitchenTablePalette.rule

    var body: some View {
        Canvas { context, size in
            var path = Path()
            path.move(to: CGPoint(x: 0, y: size.height / 2))
            path.addLine(to: CGPoint(x: size.width, y: size.height / 2))
            context.stroke(
                path,
                with: .color(color),
                style: StrokeStyle(lineWidth: 1, dash: [3, 3])
            )
        }
        .frame(height: 1)
        .accessibilityHidden(true)
    }
}

struct KitchenGraphPaper: View {
    var color: Color = KitchenTablePalette.cobalt
    var spacing: CGFloat = 18

    var body: some View {
        Canvas { context, size in
            var path = Path()

            var x: CGFloat = 0
            while x <= size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += spacing
            }

            var y: CGFloat = 0
            while y <= size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += spacing
            }

            context.stroke(path, with: .color(color.opacity(0.09)), lineWidth: 0.7)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct KitchenReceiptSurfaceModifier: ViewModifier {
    let accent: Color?

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 7, style: .continuous)

        content
            .background(KitchenTablePalette.paperRaised, in: shape)
            .clipShape(shape)
            .overlay {
                shape.stroke(KitchenTablePalette.strongRule, lineWidth: 0.8)
            }
            .overlay(alignment: .top) {
                KitchenReceiptRule(color: KitchenTablePalette.rule)
                    .padding(.horizontal, 12)
                    .padding(.top, 5)
            }
            .overlay(alignment: .leading) {
                if let accent {
                    Rectangle()
                        .fill(accent)
                        .frame(width: 4)
                        .padding(.vertical, 8)
                        .accessibilityHidden(true)
                }
            }
            .shadow(color: KitchenTablePalette.shadow, radius: 4, x: 0, y: 2)
    }
}

private struct KitchenWorkoutTicketSurfaceModifier: ViewModifier {
    let accent: Color

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)

        content
            .background(KitchenTablePalette.paperRaised, in: shape)
            .clipShape(shape)
            .overlay {
                shape.stroke(
                    KitchenTablePalette.strongRule,
                    style: StrokeStyle(lineWidth: 0.9, dash: [4, 2.5])
                )
            }
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(accent)
                    .frame(width: 5)
                    .padding(.vertical, 5)
                    .accessibilityHidden(true)
            }
            .overlay(alignment: .leading) {
                Circle()
                    .fill(KitchenTablePalette.canvas)
                    .frame(width: 9, height: 9)
                    .offset(x: -4.5)
                    .accessibilityHidden(true)
            }
            .overlay(alignment: .trailing) {
                Circle()
                    .fill(KitchenTablePalette.canvas)
                    .frame(width: 9, height: 9)
                    .offset(x: 4.5)
                    .accessibilityHidden(true)
            }
            .shadow(color: KitchenTablePalette.shadow, radius: 4, x: 0, y: 2)
    }
}

extension View {
    func kitchenReceiptSurface(accent: Color? = nil) -> some View {
        modifier(KitchenReceiptSurfaceModifier(accent: accent))
    }

    func kitchenWorkoutTicket(accent: Color = KitchenTablePalette.tomato) -> some View {
        modifier(KitchenWorkoutTicketSurfaceModifier(accent: accent))
    }
}
