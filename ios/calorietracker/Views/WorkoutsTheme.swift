import SwiftUI
import UIKit

// MARK: - Workouts theme bridge
// The workout feature keeps its Delts-derived semantic tokens so its behavior and
// data flow remain isolated. Their visual values now resolve through Fud AI's
// app-wide Neo-Brutalist palette.

extension Color {
    /// Screen background.
    static var workoutBackground: Color { NeoAppColors.canvas }

    /// Card surface behind rows and hero imagery.
    static var workoutCard: Color { NeoAppColors.surface }

    /// Elevated panel behind menus / pills.
    static var workoutPanel: Color { NeoAppColors.subtleSurface }

    /// High-contrast structural rules.
    static var workoutHairline: Color { NeoAppColors.ink }

    /// Primary structural accent.
    static var workoutAccent: Color { NeoAppColors.cobalt }

    /// Readable companion accent for supporting labels and controls.
    static var workoutSecondaryAccent: Color { NeoAppColors.cobaltDeep }

    /// Destructive/reset emphasis.
    static var workoutInferno: Color { NeoAppColors.warning }

    /// Strong text.
    static var workoutCharcoal: Color { NeoAppColors.ink }

    /// Muted/supporting text.
    static var workoutMutedText: Color { NeoAppColors.mutedInk }

    /// Text/icons rendered on top of the accent color.
    static var workoutOnAccent: Color { NeoAppColors.onCobalt }
}

struct WorkoutBackground: View {
    var body: some View {
        Color.workoutBackground
            .ignoresSafeArea()
    }
}

extension View {
    func workoutScreen() -> some View {
        background(WorkoutBackground())
            .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    func workoutLiquidBarSurface(cornerRadius: CGFloat = 32) -> some View {
        modifier(WorkoutLiquidBarSurfaceModifier(cornerRadius: cornerRadius))
    }

    func workoutPressable() -> some View {
        buttonStyle(WorkoutPressableButtonStyle())
    }
}

private struct WorkoutLiquidBarSurfaceModifier: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(
            cornerRadius: min(cornerRadius, NeoAppMetrics.cornerRadius),
            style: .continuous
        )

        content
            .background(Color.workoutCard, in: shape)
            .overlay(
                shape.stroke(
                    Color.workoutHairline,
                    lineWidth: NeoAppMetrics.rule
                )
            )
    }
}

struct WorkoutPressableButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let isPressed = configuration.isPressed && isEnabled

        configuration.label
            .scaleEffect(isPressed ? 0.985 : 1)
            .opacity(isEnabled ? (isPressed ? 0.78 : 1) : 0.48)
            .animation(.easeOut(duration: 0.14), value: isPressed)
    }
}
