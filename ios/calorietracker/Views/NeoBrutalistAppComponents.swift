import SwiftUI

// MARK: - App-wide Kitchen Table design system

/// Compatibility tokens keep the v7 view hierarchy and behavior untouched while
/// resolving every app-owned surface through the warm Kitchen Table palette.
enum NeoAppColors {
    static let canvas = NeoHomeColors.canvas
    static let surface = NeoHomeColors.surface
    static let ink = NeoHomeColors.ink
    static let mutedInk = NeoHomeColors.mutedInk
    static let cobalt = NeoHomeColors.cobalt
    static let cobaltDeep = NeoHomeColors.cobaltDeep
    static let onCobalt = NeoHomeColors.onCobalt
    static let acid = NeoHomeColors.brass
    static let paper = NeoHomeColors.paperWhite
    static let tomato = NeoHomeColors.tomato
    static let herb = NeoHomeColors.herb
    static let brass = NeoHomeColors.brass

    static let subtleSurface = KitchenTablePalette.paperMuted

    static let invertedInk = KitchenTablePalette.onStrongAccent

    static let warning = KitchenTablePalette.tomato
    static let success = KitchenTablePalette.herb
}

enum NeoAppMetrics {
    static let rule: CGFloat = 1
    static let compactRule: CGFloat = 0.75
    static let cornerRadius: CGFloat = 18
    static let screenInset: CGFloat = 16
    static let sectionSpacing: CGFloat = 16
    static let bottomBarHeight: CGFloat = 66
    static let bottomBarCornerRadius: CGFloat = 26
    static let quickActionSize: CGFloat = 60
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
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 8)
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
                                .tint(NeoAppColors.paper.opacity(colorScheme == .dark ? 0.36 : 0.62)),
                            in: .rect(cornerRadius: NeoAppMetrics.bottomBarCornerRadius)
                        )

                    quickActionButton
                        .glassEffect(
                            .regular
                                .tint(NeoAppColors.tomato.opacity(colorScheme == .dark ? 0.60 : 0.76))
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
        .background(NeoAppColors.paper.opacity(colorScheme == .dark ? 0.88 : 0.94), in: bottomBarShape)
        .overlay {
            bottomBarShape
                .stroke(KitchenTablePalette.strongRule, lineWidth: NeoAppMetrics.rule)
        }
        .shadow(color: KitchenTablePalette.shadow, radius: 8, x: 0, y: 4)
    }

    private var quickActionButton: some View {
        Button(action: onQuickAdd) {
            VStack(spacing: 2) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 22, weight: .black))
                if !dynamicTypeSize.isAccessibilitySize {
                    Text("ADD")
                        .font(.caption2.weight(.bold))
                }
            }
            .foregroundStyle(KitchenTablePalette.onStrongAccent)
            .frame(width: NeoAppMetrics.quickActionSize, height: NeoAppMetrics.bottomBarHeight)
            .background(NeoAppColors.tomato.opacity(quickActionFillOpacity), in: bottomBarShape)
            .overlay {
                bottomBarShape
                    .stroke(KitchenTablePalette.onStrongAccent.opacity(0.42), lineWidth: NeoAppMetrics.rule)
            }
            .shadow(color: KitchenTablePalette.tomato.opacity(0.22), radius: 8, x: 0, y: 4)
            .accessibilityHidden(true)
        }
        .buttonStyle(KitchenTablePressableButtonStyle())
        .accessibilityLabel("Camera and note")
        .accessibilityIdentifier("nav.quickAdd")
    }

    private func navigationButton(for tab: NeoAppTab) -> some View {
        let isSelected = selection == tab
        let icon = tab == .workouts ? workoutsIcon : tab.systemImage
        let badgeFill = isSelected ? NeoAppColors.brass : NeoAppColors.tomato

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
                            .foregroundStyle(isSelected ? KitchenTablePalette.onBrass : KitchenTablePalette.onStrongAccent)
                            .frame(width: 15, height: 15)
                            .background(badgeFill)
                            .clipShape(Circle())
                            .offset(x: 7, y: -5)
                            .accessibilityHidden(true)
                    }
                }

                if !dynamicTypeSize.isAccessibilitySize {
                    Text(tab.title)
                        .font(.caption2.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
            }
            .foregroundStyle(isSelected ? NeoAppColors.onCobalt : NeoAppColors.ink)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(isSelected ? NeoAppColors.cobalt : Color.clear, in: selectedTabShape)
            .overlay {
                selectedTabShape
                    .stroke(isSelected ? NeoAppColors.cobaltDeep : Color.clear, lineWidth: NeoAppMetrics.compactRule)
            }
            .accessibilityHidden(true)
        }
        .buttonStyle(KitchenTablePressableButtonStyle())
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
        RoundedRectangle(cornerRadius: 18, style: .continuous)
    }

    private var quickActionFillOpacity: Double {
        if #available(iOS 26.0, *) {
            return colorScheme == .dark ? 0.76 : 0.86
        }
        return colorScheme == .dark ? 0.86 : 0.96
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
                        .font(.caption2.weight(.bold))
                        .tracking(1.1)
                        .foregroundStyle(NeoAppColors.tomato)
                }

                Text(LocalizedStringKey(title))
                    .font(.system(.largeTitle, design: .serif, weight: .bold))
                    .foregroundStyle(NeoAppColors.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)

                if let subtitle {
                    Text(LocalizedStringKey(subtitle))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(NeoAppColors.mutedInk)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 4)
            trailing()
        }
        .padding(16)
        .padding(.leading, 4)
        .kitchenTableSurface(
            fill: NeoAppColors.paper,
            border: KitchenTablePalette.rule,
            cornerRadius: 22,
            shadowRadius: 8,
            shadowY: 4
        )
        .overlay(alignment: .leading) {
            Capsule()
                .fill(NeoAppColors.tomato)
                .frame(width: 5)
                .padding(.vertical, 16)
                .padding(.leading, 7)
                .accessibilityHidden(true)
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
                .font(.subheadline.weight(.bold))
                .tracking(0.7)
            Spacer(minLength: 8)
            if let detail {
                Text(LocalizedStringKey(detail))
                    .textCase(.uppercase)
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(foreground.opacity(0.12), in: Capsule())
            }
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, 12)
        .frame(minHeight: 42)
        .kitchenTableSurface(
            fill: background,
            border: KitchenTablePalette.strongRule,
            cornerRadius: 14,
            shadowRadius: 3,
            shadowY: 2
        )
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
        case .acid: KitchenTablePalette.onBrass
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
            .kitchenTableSurface(
                fill: fill,
                border: ruleColor.opacity(0.28),
                cornerRadius: NeoAppMetrics.cornerRadius,
                lineWidth: NeoAppMetrics.rule
            )
    }
}

struct NeoMetricTag: View {
    let label: String
    var color: Color = NeoAppColors.cobalt

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
                .accessibilityHidden(true)
            Text(LocalizedStringKey(label))
                .textCase(.uppercase)
                .font(.caption2.weight(.bold))
        }
        .foregroundStyle(NeoAppColors.ink)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(NeoAppColors.subtleSurface, in: Capsule())
        .overlay {
            Capsule().stroke(color.opacity(0.55), lineWidth: NeoAppMetrics.compactRule)
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
            .background(NeoAppColors.paper.opacity(colorScheme == .dark ? 0.94 : 0.98))
            .clipShape(panelShape)
            .overlay {
                panelShape
                    .stroke(KitchenTablePalette.strongRule, lineWidth: NeoAppMetrics.rule)
            }
            .shadow(color: KitchenTablePalette.shadow, radius: 12, x: 0, y: 6)
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
                        .background(NeoAppColors.brass, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                        .foregroundStyle(KitchenTablePalette.onBrass)
                        .overlay {
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .stroke(KitchenTablePalette.onBrass.opacity(0.30), lineWidth: NeoAppMetrics.compactRule)
                        }
                }
                .buttonStyle(KitchenTablePressableButtonStyle())
                .accessibilityLabel("Back")
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(LocalizedStringKey(eyebrow))
                    .font(.caption2.weight(.bold))
                    .textCase(.uppercase)
                    .tracking(0.9)
                    .foregroundStyle(KitchenTablePalette.brass)

                Text(LocalizedStringKey(title))
                    .font(.system(.title3, design: .serif, weight: .bold))
                    .foregroundStyle(KitchenTablePalette.onStrongAccent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Spacer(minLength: 4)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .black))
                    .frame(width: 38, height: 38)
                    .background(KitchenTablePalette.onStrongAccent.opacity(0.10), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .foregroundStyle(KitchenTablePalette.onStrongAccent)
                    .overlay {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .stroke(KitchenTablePalette.onStrongAccent.opacity(0.38), lineWidth: NeoAppMetrics.compactRule)
                    }
            }
            .buttonStyle(KitchenTablePressableButtonStyle())
            .accessibilityLabel("Close")
        }
        .padding(10)
        .background(KitchenTablePalette.espresso)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(KitchenTablePalette.brass.opacity(0.65))
                .frame(height: NeoAppMetrics.compactRule)
        }
    }

    private var panelShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
    }

    @ViewBuilder
    private func themedGlass<GlassContent: View>(@ViewBuilder content: () -> GlassContent) -> some View {
        let glassContent = content()
        if #available(iOS 26.0, *) {
            glassContent
                .glassEffect(
                    .regular.tint(NeoAppColors.paper.opacity(colorScheme == .dark ? 0.40 : 0.68)),
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
                    .background(iconBackground, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .stroke(NeoAppColors.ink.opacity(0.22), lineWidth: NeoAppMetrics.compactRule)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey(item.title))
                        .font(.body.weight(.semibold))
                        .foregroundStyle(titleColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)

                    if let subtitle = item.subtitle {
                        Text(LocalizedStringKey(subtitle))
                            .font(.caption)
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
            .background(rowBackground, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(NeoAppColors.ink.opacity(0.18), lineWidth: NeoAppMetrics.compactRule)
            }
            .contentShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        }
        .buttonStyle(KitchenTablePressableButtonStyle())
        .accessibilityLabel(Text(LocalizedStringKey(item.title)))
        .accessibilityValue(item.isSelected ? "Selected" : "")
        .accessibilityAddTraits(item.isSelected ? .isSelected : [])
        .accessibilityIdentifier("neo.glassChoice.\(item.id)")
    }

    private var rowBackground: Color {
        if item.isSelected { return NeoAppColors.brass.opacity(0.88) }
        if item.isDestructive { return NeoAppColors.warning.opacity(0.16) }
        return NeoAppColors.surface.opacity(0.90)
    }

    private var iconBackground: Color {
        if item.isSelected { return NeoAppColors.cobalt }
        if item.isDestructive { return NeoAppColors.warning }
        return NeoAppColors.subtleSurface
    }

    private var iconColor: Color {
        item.isSelected ? NeoAppColors.onCobalt : NeoAppColors.ink
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

extension View {
    func neoScreen() -> some View {
        background(KitchenTableBackdrop())
            .scrollContentBackground(.hidden)
    }

    func neoPanel(
        fill: Color = NeoAppColors.surface,
        ruleColor: Color = NeoAppColors.ink,
        lineWidth: CGFloat = NeoAppMetrics.rule
    ) -> some View {
        kitchenTableSurface(
            fill: fill,
            border: ruleColor.opacity(0.28),
            cornerRadius: NeoAppMetrics.cornerRadius,
            lineWidth: lineWidth
        )
    }

    @ViewBuilder
    func neoInteractiveSurface(cornerRadius: CGFloat = NeoAppMetrics.cornerRadius) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(iOS 26.0, *) {
            self
                .glassEffect(.regular.tint(NeoAppColors.paper.opacity(0.48)).interactive(), in: shape)
                .overlay(shape.stroke(KitchenTablePalette.strongRule, lineWidth: NeoAppMetrics.compactRule))
        } else {
            self.kitchenTableSurface(
                fill: NeoAppColors.paper,
                border: KitchenTablePalette.strongRule,
                cornerRadius: cornerRadius,
                lineWidth: NeoAppMetrics.compactRule,
                shadowRadius: 3,
                shadowY: 2
            )
        }
    }

    func neoListRow() -> some View {
        listRowBackground(NeoAppColors.surface)
            .listRowSeparatorTint(KitchenTablePalette.rule)
    }
}
