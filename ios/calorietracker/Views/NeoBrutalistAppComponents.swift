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
    static let bottomBarHeight: CGFloat = 64
    static let bottomBarCornerRadius: CGFloat = 18
    static let quickActionSize: CGFloat = 56
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

struct NeoAppBottomNavigationBar: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Binding var selection: NeoAppTab
    let workoutsIcon: String
    let updateAvailable: Bool
    let onQuickAdd: () -> Void
    @State private var selectionFeedbackTrigger = 0

    var body: some View {
        bottomNavigation
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 6)
            .sensoryFeedback(.selection, trigger: selectionFeedbackTrigger)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("App navigation")
            .accessibilityAddTraits(.isTabBar)
    }

    @ViewBuilder
    private var bottomNavigation: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 10) {
                HStack(spacing: 10) {
                    navigationStrip
                        .glassEffect(
                            .regular
                                .tint(NeoAppColors.cobalt.opacity(colorScheme == .dark ? 0.44 : 0.32)),
                            in: .rect(cornerRadius: NeoAppMetrics.bottomBarCornerRadius)
                        )

                    quickActionButton
                        .glassEffect(
                            .regular
                                .tint(NeoAppColors.acid.opacity(colorScheme == .dark ? 0.58 : 0.72))
                                .interactive(),
                            in: .rect(cornerRadius: NeoAppMetrics.bottomBarCornerRadius)
                        )
                }
            }
        } else {
            HStack(spacing: 10) {
                navigationStrip
                    .background(.ultraThinMaterial, in: bottomBarShape)

                quickActionButton
                    .background(.ultraThinMaterial, in: bottomBarShape)
            }
        }
    }

    private var navigationStrip: some View {
        HStack(spacing: 2) {
            ForEach(NeoAppTab.allCases) { tab in
                navigationButton(for: tab)
            }
        }
        .padding(5)
        .frame(maxWidth: .infinity)
        .frame(height: NeoAppMetrics.bottomBarHeight)
        .background(NeoAppColors.cobalt.opacity(colorScheme == .dark ? 0.18 : 0.10), in: bottomBarShape)
        .overlay {
            bottomBarShape
                .stroke(NeoAppColors.cobalt, lineWidth: NeoAppMetrics.rule)
        }
    }

    private var quickActionButton: some View {
        Button(action: onQuickAdd) {
            VStack(spacing: 2) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 22, weight: .black))
                if !dynamicTypeSize.isAccessibilitySize {
                    Text("ADD")
                        .font(.caption2.weight(.black).width(.condensed))
                }
            }
            .foregroundStyle(Color.black)
            .frame(width: NeoAppMetrics.quickActionSize, height: NeoAppMetrics.bottomBarHeight)
            .background(NeoAppColors.acid.opacity(quickActionFillOpacity), in: bottomBarShape)
            .overlay {
                bottomBarShape
                    .stroke(Color.black, lineWidth: NeoAppMetrics.rule)
            }
            .accessibilityHidden(true)
        }
        .buttonStyle(NeoNavigationButtonStyle())
        .accessibilityLabel("Camera and note")
        .accessibilityIdentifier("nav.quickAdd")
    }

    private func navigationButton(for tab: NeoAppTab) -> some View {
        let isSelected = selection == tab
        let icon = tab == .workouts ? workoutsIcon : tab.systemImage
        let badgeFill = isSelected ? NeoAppColors.cobalt : NeoAppColors.acid

        return Button {
            guard !isSelected else { return }
            selection = tab
            selectionFeedbackTrigger += 1
        } label: {
            VStack(spacing: 3) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .bold))
                        .frame(width: 28, height: 23)

                    if tab == .settings && updateAvailable {
                        Text("!")
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .foregroundStyle(isSelected ? NeoAppColors.onCobalt : Color.black)
                            .frame(width: 15, height: 15)
                            .background(badgeFill)
                            .clipShape(Circle())
                            .offset(x: 7, y: -5)
                            .accessibilityHidden(true)
                    }
                }

                if !dynamicTypeSize.isAccessibilitySize {
                    Text(tab.title)
                        .textCase(.uppercase)
                        .font(.caption2.weight(.black).width(.condensed))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
            }
            .foregroundStyle(isSelected ? Color.black : NeoAppColors.ink)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(isSelected ? NeoAppColors.acid : Color.clear, in: selectedTabShape)
            .overlay {
                selectedTabShape
                    .stroke(isSelected ? Color.black : Color.clear, lineWidth: NeoAppMetrics.compactRule)
            }
            .accessibilityHidden(true)
        }
        .buttonStyle(NeoNavigationButtonStyle())
        .frame(maxWidth: .infinity)
        .frame(height: NeoAppMetrics.bottomBarHeight - 10)
        .accessibilityLabel(Text(tab.title))
        .accessibilityValue(tab == .settings && updateAvailable ? "Update available" : "")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("nav.\(tab.rawValue)")
    }

    private var bottomBarShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: NeoAppMetrics.bottomBarCornerRadius, style: .continuous)
    }

    private var selectedTabShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
    }

    private var quickActionFillOpacity: Double {
        if #available(iOS 26.0, *) {
            return colorScheme == .dark ? 0.24 : 0.32
        }
        return colorScheme == .dark ? 0.78 : 0.88
    }
}

private struct NeoNavigationButtonStyle: ButtonStyle {
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
