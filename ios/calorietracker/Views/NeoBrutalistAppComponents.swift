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
    static let railWidth: CGFloat = 72
    static let railCornerRadius: CGFloat = 18
    static let railTabHeight: CGFloat = 70
    static let quickActionHeight: CGFloat = 64
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
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Binding var selection: NeoAppTab
    let workoutsIcon: String
    let updateAvailable: Bool
    let onQuickAdd: () -> Void
    @State private var selectionFeedbackTrigger = 0

    var body: some View {
        railNavigation
            .padding(.leading, 6)
            .padding(.trailing, 8)
            .padding(.vertical, 8)
            .sensoryFeedback(.selection, trigger: selectionFeedbackTrigger)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("App navigation")
            .accessibilityAddTraits(.isTabBar)
    }

    @ViewBuilder
    private var railNavigation: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 10) {
                VStack(spacing: 10) {
                    navigationStrip
                        .glassEffect(
                            .regular
                                .tint(NeoAppColors.cobalt.opacity(colorScheme == .dark ? 0.40 : 0.28))
                                .interactive(),
                            in: .rect(cornerRadius: NeoAppMetrics.railCornerRadius)
                        )

                    quickActionButton
                        .glassEffect(
                            .regular
                                .tint(NeoAppColors.acid.opacity(colorScheme == .dark ? 0.58 : 0.72))
                                .interactive(),
                            in: .rect(cornerRadius: NeoAppMetrics.railCornerRadius)
                        )
                }
            }
        } else {
            VStack(spacing: 10) {
                navigationStrip
                    .background(.ultraThinMaterial, in: railShape)

                quickActionButton
                    .background(.ultraThinMaterial, in: railShape)
            }
        }
    }

    private var navigationStrip: some View {
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
                .padding(.bottom, 10)
                .accessibilityHidden(true)
        }
        .padding(4)
        .frame(width: NeoAppMetrics.railWidth)
        .frame(maxHeight: .infinity)
        .background(Color.black.opacity(colorScheme == .dark ? 0.62 : 0.80), in: railShape)
        .overlay {
            railShape
                .stroke(NeoAppColors.cobalt, lineWidth: NeoAppMetrics.rule)
        }
    }

    private var brand: some View {
        VStack(spacing: -3) {
            Text("FÜD")
            Text("AI")
        }
        .font(.system(size: 21, weight: .black, design: .rounded).width(.condensed))
        .foregroundStyle(Color.white)
        .frame(maxWidth: .infinity)
        .frame(height: 72)
        .background(NeoAppColors.cobalt)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.72))
                .frame(height: NeoAppMetrics.compactRule)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Fud AI")
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
            .frame(width: NeoAppMetrics.railWidth, height: NeoAppMetrics.quickActionHeight)
            .background(NeoAppColors.acid.opacity(quickActionFillOpacity), in: railShape)
            .overlay {
                railShape
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
                            .foregroundStyle(Color.black)
                            .frame(width: 15, height: 15)
                            .background(NeoAppColors.acid)
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
            .foregroundStyle(isSelected ? NeoAppColors.cobalt : Color.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(isSelected ? NeoAppColors.cobalt.opacity(0.18) : Color.clear, in: selectedTabShape)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(isSelected ? NeoAppColors.cobalt : Color.clear)
                    .frame(width: 4)
            }
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.white.opacity(0.20))
                    .frame(height: NeoAppMetrics.compactRule)
            }
            .accessibilityHidden(true)
        }
        .buttonStyle(NeoNavigationButtonStyle())
        .frame(width: NeoAppMetrics.railWidth - 8, height: NeoAppMetrics.railTabHeight)
        .accessibilityLabel(Text(tab.title))
        .accessibilityValue(tab == .settings && updateAvailable ? "Update available" : "")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("nav.\(tab.rawValue)")
    }

    private var railShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: NeoAppMetrics.railCornerRadius, style: .continuous)
    }

    private var selectedTabShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
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

// MARK: - Themed native glass choices

/// A reusable action description for app-owned choice surfaces. The destination
/// behavior stays at the call site, so swapping a system `Menu` for this themed
/// presentation never changes the underlying feature or stored data.
struct NeoGlassChoiceItem: Identifiable {
    let id: String
    let title: String
    var subtitle: String? = nil
    let systemImage: String
    var isSelected = false
    var isDestructive = false
    var showsDisclosure = false
    let action: () -> Void
}

struct NeoGlassChoicePanel<Content: View>: View {
    let title: String
    var eyebrow = String(localized: "Choose")
    var onBack: (() -> Void)?
    let onClose: () -> Void
    @ViewBuilder let content: () -> Content
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        themedGlass {
            VStack(spacing: 0) {
                header

                ScrollView {
                    LazyVStack(spacing: 8) {
                        content()
                    }
                    .padding(10)
                }
                .scrollIndicators(.hidden)
                .frame(maxHeight: 420)
            }
            .background(NeoAppColors.cobalt.opacity(colorScheme == .dark ? 0.16 : 0.10))
            .clipShape(panelShape)
            .overlay {
                panelShape
                    .stroke(NeoAppColors.cobalt, lineWidth: NeoAppMetrics.rule)
            }
        }
        .padding(6)
        .frame(minWidth: 300, idealWidth: 340, maxWidth: 370)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("neo.glassChoice.panel")
    }

    private var header: some View {
        HStack(spacing: 10) {
            if let onBack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .black))
                        .frame(width: 38, height: 38)
                        .background(NeoAppColors.acid)
                        .foregroundStyle(Color.black)
                        .overlay {
                            Rectangle().stroke(Color.black, lineWidth: NeoAppMetrics.compactRule)
                        }
                }
                .buttonStyle(NeoGlassChoiceButtonStyle())
                .accessibilityLabel("Back")
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(LocalizedStringKey(eyebrow))
                    .font(.system(size: 10, weight: .black, design: .rounded).width(.condensed))
                    .textCase(.uppercase)
                    .foregroundStyle(NeoAppColors.onCobalt.opacity(0.82))

                Text(LocalizedStringKey(title))
                    .font(.system(size: 22, weight: .black, design: .rounded).width(.condensed))
                    .textCase(.uppercase)
                    .foregroundStyle(NeoAppColors.onCobalt)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Spacer(minLength: 4)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .black))
                    .frame(width: 38, height: 38)
                    .background(Color.black.opacity(0.20))
                    .foregroundStyle(NeoAppColors.onCobalt)
                    .overlay {
                        Rectangle().stroke(NeoAppColors.onCobalt, lineWidth: NeoAppMetrics.compactRule)
                    }
            }
            .buttonStyle(NeoGlassChoiceButtonStyle())
            .accessibilityLabel("Close")
        }
        .padding(10)
        .background(NeoAppColors.cobalt.opacity(colorScheme == .dark ? 0.88 : 0.94))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(NeoAppColors.ink)
                .frame(height: NeoAppMetrics.rule)
        }
    }

    private var panelShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
    }

    @ViewBuilder
    private func themedGlass<GlassContent: View>(@ViewBuilder content: () -> GlassContent) -> some View {
        let glassContent = content()
        if #available(iOS 26.0, *) {
            glassContent
                .glassEffect(
                    .regular.tint(NeoAppColors.cobalt.opacity(colorScheme == .dark ? 0.44 : 0.32)),
                    in: panelShape
                )
        } else {
            glassContent
                .background(.ultraThinMaterial, in: panelShape)
        }
    }
}

struct NeoGlassActionRow: View {
    let item: NeoGlassChoiceItem

    var body: some View {
        Button(role: item.isDestructive ? .destructive : nil, action: item.action) {
            HStack(spacing: 12) {
                Image(systemName: item.systemImage)
                    .font(.system(size: 18, weight: .black))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(iconColor)
                    .frame(width: 38, height: 38)
                    .background(iconBackground)
                    .overlay {
                        Rectangle().stroke(NeoAppColors.ink, lineWidth: NeoAppMetrics.compactRule)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey(item.title))
                        .font(.system(.body, design: .rounded, weight: .black).width(.condensed))
                        .textCase(.uppercase)
                        .foregroundStyle(titleColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)

                    if let subtitle = item.subtitle {
                        Text(LocalizedStringKey(subtitle))
                            .font(.system(.caption, design: .rounded, weight: .bold))
                            .foregroundStyle(NeoAppColors.mutedInk)
                            .lineLimit(2)
                    }
                }

                Spacer(minLength: 4)

                if item.isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(Color.black)
                } else if item.showsDisclosure {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(NeoAppColors.cobalt)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .background(rowBackground)
            .overlay {
                Rectangle().stroke(NeoAppColors.ink, lineWidth: NeoAppMetrics.compactRule)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(NeoGlassChoiceButtonStyle())
        .accessibilityLabel(Text(LocalizedStringKey(item.title)))
        .accessibilityValue(item.isSelected ? "Selected" : "")
        .accessibilityAddTraits(item.isSelected ? .isSelected : [])
        .accessibilityIdentifier("neo.glassChoice.\(item.id)")
    }

    private var rowBackground: Color {
        if item.isSelected { return NeoAppColors.acid }
        if item.isDestructive { return NeoAppColors.warning.opacity(0.16) }
        return NeoAppColors.surface.opacity(0.90)
    }

    private var iconBackground: Color {
        if item.isSelected { return NeoAppColors.cobalt }
        if item.isDestructive { return NeoAppColors.warning }
        return NeoAppColors.acid
    }

    private var iconColor: Color {
        item.isSelected ? NeoAppColors.onCobalt : Color.black
    }

    private var titleColor: Color {
        item.isDestructive ? NeoAppColors.warning : NeoAppColors.ink
    }
}

struct NeoGlassChoiceMenu<Label: View>: View {
    let title: String
    var eyebrow = String(localized: "Choose")
    let items: [NeoGlassChoiceItem]
    var dismissOnSelection = true
    @ViewBuilder let label: () -> Label
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            label()
        }
        .popover(isPresented: $isPresented) {
            NeoGlassChoicePanel(
                title: title,
                eyebrow: eyebrow,
                onClose: { isPresented = false }
            ) {
                ForEach(items) { item in
                    NeoGlassActionRow(item: presentedItem(item))
                }
            }
            .presentationCompactAdaptation(.popover)
            .presentationBackground(.clear)
        }
    }

    private func presentedItem(_ item: NeoGlassChoiceItem) -> NeoGlassChoiceItem {
        NeoGlassChoiceItem(
            id: item.id,
            title: item.title,
            subtitle: item.subtitle,
            systemImage: item.systemImage,
            isSelected: item.isSelected,
            isDestructive: item.isDestructive,
            showsDisclosure: item.showsDisclosure
        ) {
            if dismissOnSelection {
                isPresented = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                    item.action()
                }
            } else {
                item.action()
            }
        }
    }
}

private struct NeoGlassChoiceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.72 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
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
