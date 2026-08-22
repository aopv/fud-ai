import SwiftUI

// MARK: - App-wide Neo-Brutalist design system

/// Structural colors used across every primary Fud AI surface. Nutrition data can
/// still use the user's saved app accent; the cobalt/acid palette defines the UI.
enum NeoAppColors {
    static let canvas = NeoHomeColors.canvas
    static let surface = NeoHomeColors.surface
    static let ink = NeoHomeColors.ink
    static let mutedInk = NeoHomeColors.mutedInk
    static let cobalt = NeoHomeColors.cobalt
    static let cobaltDeep = NeoHomeColors.cobaltDeep
    static let onCobalt = NeoHomeColors.onCobalt
    static let acid = NeoHomeColors.acidYellow
    static let paper = NeoHomeColors.paperWhite

    static let subtleSurface = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.075, alpha: 1)
            : UIColor(red: 0.94, green: 0.93, blue: 0.88, alpha: 1)
    })

    static let invertedInk = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? .black : .white
    })

    static let warning = Color(hex: 0xFF5B35)
    static let success = Color(hex: 0x30D17A)
}

enum NeoAppMetrics {
    static let rule: CGFloat = 2
    static let compactRule: CGFloat = 1
    static let cornerRadius: CGFloat = 2
    static let screenInset: CGFloat = 14
    static let sectionSpacing: CGFloat = 14
    /// The rail follows the reference's ~16% screen share while leaving enough
    /// room for Home's four-column nutrient grid on a 375-point iPhone.
    static let railWidth: CGFloat = 64
}

enum NeoAppTab: String, CaseIterable, Identifiable, Hashable {
    case home
    case progress
    case coach
    case settings
    case workouts

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: String(localized: "Home")
        case .progress: String(localized: "Progress")
        case .coach: String(localized: "AI Coach")
        case .settings: String(localized: "Settings")
        case .workouts: String(localized: "Workouts")
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house.fill"
        case .progress: "chart.bar.fill"
        case .coach: "sparkles"
        case .settings: "gearshape.fill"
        case .workouts: "dumbbell.fill"
        }
    }
}

struct NeoAppNavigationRail: View {
    @Binding var selection: NeoAppTab
    let workoutsIcon: String
    let updateAvailable: Bool
    let onQuickAdd: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            brand

            ForEach(NeoAppTab.allCases) { tab in
                navigationButton(for: tab)
            }

            Spacer(minLength: 8)

            Text("TRACK.\nLEARN.\nWIN.")
                .font(.system(size: 9, weight: .black, design: .rounded).width(.condensed))
                .tracking(0.6)
                .foregroundStyle(Color.white)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .accessibilityHidden(true)

            Spacer(minLength: 8)

            Button(action: onQuickAdd) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 28, weight: .black))
                    .foregroundStyle(NeoAppColors.acid)
                    .frame(width: 52, height: 52)
                    .neoInteractiveSurface(cornerRadius: 2)
            }
            .buttonStyle(NeoRailButtonStyle())
            .accessibilityLabel("Camera and note")
            .accessibilityIdentifier("nav.quickAdd")
            .padding(.bottom, 10)
        }
        .frame(width: NeoAppMetrics.railWidth)
        .background(Color.black)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color.white.opacity(0.82))
                .frame(width: NeoAppMetrics.compactRule)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("App navigation")
    }

    private var brand: some View {
        VStack(spacing: -3) {
            Text("FÜD")
            Text("AI")
        }
        .font(.system(size: 22, weight: .black, design: .rounded).width(.condensed))
        .foregroundStyle(Color.white)
        .frame(maxWidth: .infinity)
        .frame(height: 82)
        .background(NeoAppColors.cobalt)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.82))
                .frame(height: NeoAppMetrics.compactRule)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Fud AI")
    }

    private func navigationButton(for tab: NeoAppTab) -> some View {
        let isSelected = selection == tab
        let icon = tab == .workouts ? workoutsIcon : tab.systemImage

        return Button {
            guard !isSelected else { return }
            UISelectionFeedbackGenerator().selectionChanged()
            selection = tab
        } label: {
            VStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .bold))
                        .frame(width: 32, height: 26)

                    if tab == .settings && updateAvailable {
                        Text("!")
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .foregroundStyle(Color.black)
                            .frame(width: 15, height: 15)
                            .background(NeoAppColors.acid)
                            .clipShape(Circle())
                            .offset(x: 6, y: -6)
                    }
                }

                Text(tab.title)
                    .textCase(.uppercase)
                    .font(.system(size: 8, weight: .black, design: .rounded).width(.condensed))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .foregroundStyle(isSelected ? NeoAppColors.cobalt : Color.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(isSelected ? NeoAppColors.cobalt : Color.clear)
                    .frame(width: 4)
            }
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.white.opacity(0.22))
                    .frame(height: NeoAppMetrics.compactRule)
            }
        }
        .buttonStyle(NeoRailButtonStyle())
        .frame(height: 82)
        .accessibilityLabel(Text(tab.title))
        .accessibilityValue(tab == .settings && updateAvailable ? "Update available" : "")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("nav.\(tab.rawValue)")
    }
}

private struct NeoRailButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.68 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct NeoScreenHeader<Trailing: View>: View {
    let eyebrow: String?
    let title: String
    let subtitle: String?
    @ViewBuilder let trailing: () -> Trailing

    init(
        eyebrow: String? = nil,
        title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                if let eyebrow {
                    Text(LocalizedStringKey(eyebrow))
                        .textCase(.uppercase)
                        .font(.system(size: 11, weight: .black, design: .rounded).width(.condensed))
                        .foregroundStyle(NeoAppColors.cobalt)
                }

                Text(LocalizedStringKey(title))
                    .textCase(.uppercase)
                    .font(.system(size: 34, weight: .black, design: .rounded).width(.condensed))
                    .foregroundStyle(NeoAppColors.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)

                if let subtitle {
                    Text(LocalizedStringKey(subtitle))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(NeoAppColors.mutedInk)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 4)
            trailing()
        }
        .padding(14)
        .background(NeoAppColors.surface)
        .overlay {
            Rectangle()
                .stroke(NeoAppColors.ink, lineWidth: NeoAppMetrics.rule)
        }
    }
}

extension NeoScreenHeader where Trailing == EmptyView {
    init(eyebrow: String? = nil, title: String, subtitle: String? = nil) {
        self.init(eyebrow: eyebrow, title: title, subtitle: subtitle) { EmptyView() }
    }
}

struct NeoSectionBanner: View {
    let title: String
    var detail: String? = nil
    var style: Style = .cobalt

    enum Style {
        case cobalt
        case acid
        case ink
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(LocalizedStringKey(title))
                .textCase(.uppercase)
                .font(.system(size: 17, weight: .black, design: .rounded).width(.condensed))
            Spacer(minLength: 8)
            if let detail {
                Text(LocalizedStringKey(detail))
                    .textCase(.uppercase)
                    .font(.system(size: 10, weight: .black, design: .rounded).width(.condensed))
            }
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, 12)
        .frame(minHeight: 42)
        .background(background)
        .overlay {
            Rectangle().stroke(NeoAppColors.ink, lineWidth: NeoAppMetrics.rule)
        }
    }

    private var background: Color {
        switch style {
        case .cobalt: NeoAppColors.cobalt
        case .acid: NeoAppColors.acid
        case .ink: NeoAppColors.ink
        }
    }

    private var foreground: Color {
        switch style {
        case .cobalt: NeoAppColors.onCobalt
        case .acid: Color.black
        case .ink: NeoAppColors.invertedInk
        }
    }
}

struct NeoOutlinedPanel<Content: View>: View {
    var fill: Color = NeoAppColors.surface
    var ruleColor: Color = NeoAppColors.ink
    var padding: CGFloat = 14
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .background(fill)
            .overlay {
                Rectangle().stroke(ruleColor, lineWidth: NeoAppMetrics.rule)
            }
    }
}

struct NeoMetricTag: View {
    let label: String
    var color: Color = NeoAppColors.cobalt

    var body: some View {
        Text(LocalizedStringKey(label))
            .textCase(.uppercase)
            .font(.system(size: 10, weight: .black, design: .rounded).width(.condensed))
            .foregroundStyle(NeoAppColors.ink)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(color)
            .overlay {
                Rectangle().stroke(NeoAppColors.ink, lineWidth: NeoAppMetrics.compactRule)
            }
    }
}

extension View {
    func neoScreen() -> some View {
        background(NeoAppColors.canvas)
            .scrollContentBackground(.hidden)
    }

    func neoPanel(
        fill: Color = NeoAppColors.surface,
        ruleColor: Color = NeoAppColors.ink,
        lineWidth: CGFloat = NeoAppMetrics.rule
    ) -> some View {
        background(fill)
            .clipShape(Rectangle())
            .overlay {
                Rectangle().stroke(ruleColor, lineWidth: lineWidth)
            }
    }

    @ViewBuilder
    func neoInteractiveSurface(cornerRadius: CGFloat = 2) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(iOS 26.0, *) {
            self
                .glassEffect(.regular.interactive(), in: shape)
                .overlay(shape.stroke(Color.white.opacity(0.66), lineWidth: 1))
        } else {
            self
                .background(Color.white.opacity(0.10), in: shape)
                .overlay(shape.stroke(Color.white.opacity(0.66), lineWidth: 1))
        }
    }

    func neoListRow() -> some View {
        listRowBackground(NeoAppColors.surface)
            .listRowSeparatorTint(NeoAppColors.ink.opacity(0.34))
    }
}
