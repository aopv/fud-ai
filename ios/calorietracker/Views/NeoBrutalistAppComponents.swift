import SwiftUI
import UIKit

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
    static let bottomBarHeight: CGFloat = 50
    static let bottomBarCornerRadius: CGFloat = 8
    static let quickActionSize: CGFloat = 50
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

    var kitchenAssetName: String {
        switch self {
        case .home: "KitchenNavHome"
        case .progress: "KitchenNavProgress"
        case .coach: "KitchenNavCoach"
        case .settings: "KitchenNavSettings"
        case .workouts: "KitchenNavWorkouts"
        }
    }

    var kitchenAccent: Color {
        switch self {
        case .home: KitchenTablePalette.herb
        case .progress: KitchenTablePalette.brassDeep
        case .coach: KitchenTablePalette.cobalt
        case .settings: KitchenTablePalette.tomato
        case .workouts: KitchenTablePalette.espresso
        }
    }
}

struct NeoAppBottomNavigationBar: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Binding var selection: NeoAppTab
    let workoutsIcon: String
    let updateAvailable: Bool
    let onQuickAdd: () -> Void
    @State private var selectionFeedbackTrigger = 0

    var body: some View {
        HStack(spacing: 0) {
            ForEach(NeoAppTab.allCases) { tab in
                navigationButton(for: tab)
            }
            quickActionButton
        }
            .frame(height: NeoAppMetrics.bottomBarHeight)
            .padding(.horizontal, 5)
            .padding(.top, 3)
            .padding(.bottom, 2)
            .background(KitchenTablePalette.paperRaised)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(KitchenTablePalette.strongRule)
                    .frame(height: NeoAppMetrics.compactRule)
                    .accessibilityHidden(true)
            }
            .shadow(color: KitchenTablePalette.espresso.opacity(0.12), radius: 5, x: 0, y: -2)
            .sensoryFeedback(.selection, trigger: selectionFeedbackTrigger)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("App navigation")
            .accessibilityAddTraits(.isTabBar)
    }

    private var quickActionButton: some View {
        Button(action: onQuickAdd) {
            VStack(spacing: 0) {
                kitchenNavigationIcon(
                    assetName: "KitchenNavQuickAdd",
                    systemImage: "camera.fill",
                    accent: KitchenTablePalette.tomato,
                    size: 26
                )
                if !dynamicTypeSize.isAccessibilitySize {
                    Text("ADD")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .tracking(0.2)
                }
                Capsule()
                    .fill(Color.clear)
                    .frame(width: 17, height: 2)
                    .accessibilityHidden(true)
            }
            .foregroundStyle(KitchenTablePalette.tomatoDeep)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityHidden(true)
        }
        .buttonStyle(KitchenTablePressableButtonStyle())
        .frame(maxWidth: .infinity)
        .frame(height: NeoAppMetrics.bottomBarHeight)
        .accessibilityLabel("Camera and note")
        .accessibilityIdentifier("nav.quickAdd")
    }

    private func navigationButton(for tab: NeoAppTab) -> some View {
        let isSelected = selection == tab
        let icon = tab == .workouts ? workoutsIcon : tab.systemImage
        let badgeFill = isSelected ? tab.kitchenAccent : NeoAppColors.tomato
        let updateAccessibilityValue = tab == .settings && updateAvailable
            ? Text("Update Available")
            : Text(verbatim: "")

        return Button {
            guard !isSelected else { return }
            selection = tab
            selectionFeedbackTrigger += 1
        } label: {
            VStack(spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    kitchenNavigationIcon(
                        assetName: tab.kitchenAssetName,
                        systemImage: icon,
                        accent: tab.kitchenAccent,
                        size: 26
                    )
                    .frame(width: 29, height: 27)

                    if tab == .workouts, UIImage(named: tab.kitchenAssetName) != nil {
                        Image(systemName: workoutsIcon)
                            .font(.system(size: 7, weight: .black))
                            .symbolRenderingMode(.monochrome)
                            .foregroundStyle(KitchenTablePalette.espresso)
                            .frame(width: 14, height: 14)
                            .background(KitchenTablePalette.paperRaised, in: Circle())
                            .overlay {
                                Circle()
                                    .stroke(KitchenTablePalette.espresso.opacity(0.45), lineWidth: 0.7)
                            }
                            .offset(x: 5, y: 14)
                            .accessibilityHidden(true)
                    }

                    if tab == .settings && updateAvailable {
                        Text("!")
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .foregroundStyle(KitchenTablePalette.onStrongAccent)
                            .frame(width: 15, height: 15)
                            .background(badgeFill)
                            .clipShape(Circle())
                            .offset(x: 7, y: -5)
                            .accessibilityHidden(true)
                    }
                }

                if !dynamicTypeSize.isAccessibilitySize {
                    Text(tab.title)
                        .font(.system(size: 7, weight: isSelected ? .bold : .medium, design: .monospaced))
                        .textCase(.uppercase)
                        .tracking(isSelected ? 0.15 : 0)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }

                Capsule()
                    .fill(isSelected ? tab.kitchenAccent : Color.clear)
                    .frame(width: 17, height: 2)
                    .accessibilityHidden(true)
            }
            .foregroundStyle(isSelected ? tab.kitchenAccent : NeoAppColors.ink)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityHidden(true)
        }
        .buttonStyle(KitchenTablePressableButtonStyle())
        .frame(maxWidth: .infinity)
        .frame(height: NeoAppMetrics.bottomBarHeight)
        .accessibilityLabel(Text(tab.title))
        .accessibilityValue(updateAccessibilityValue)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("nav.\(tab.rawValue)")
    }

    @ViewBuilder
    private func kitchenNavigationIcon(
        assetName: String,
        systemImage: String,
        accent: Color,
        size: CGFloat
    ) -> some View {
        if UIImage(named: assetName) != nil {
            Image(decorative: assetName)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            Image(systemName: systemImage)
                .font(.system(size: size * 0.68, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(accent)
                .frame(width: size, height: size)
                .background(KitchenTablePalette.paperMuted.opacity(0.54), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(KitchenTablePalette.rule, lineWidth: NeoAppMetrics.compactRule)
                }
                .rotationEffect(.degrees(assetName == "KitchenNavCoach" ? -3 : 0))
        }
    }
}

struct NeoScreenHeader<Trailing: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                if let eyebrow {
                    Text(LocalizedStringKey(eyebrow))
                        .textCase(.uppercase)
                        .font(.system(.caption2, design: .monospaced, weight: .bold))
                        .tracking(0.65)
                        .foregroundStyle(KitchenTablePalette.tomatoDeep)
                }

                Text(LocalizedStringKey(title))
                    .font(.system(.title2, design: .serif, weight: .bold))
                    .foregroundStyle(NeoAppColors.ink)
                    .fixedSize(horizontal: false, vertical: true)

                if let subtitle {
                    Text(LocalizedStringKey(subtitle))
                        .font(.system(.caption, design: .serif, weight: .regular))
                        .foregroundStyle(NeoAppColors.mutedInk)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 2)
            trailing()
                .scaleEffect(dynamicTypeSize.isAccessibilitySize ? 1 : 0.82)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
                .accessibilitySortPriority(1)
        }
        .padding(.vertical, 9)
        .padding(.trailing, 10)
        .padding(.leading, 14)
        .kitchenTableSurface(
            fill: KitchenTablePalette.paperRaised,
            border: KitchenTablePalette.rule,
            cornerRadius: 5,
            shadowRadius: 2,
            shadowY: 1
        )
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(KitchenTablePalette.tomato)
                .frame(width: 3)
                .padding(.vertical, 5)
                .padding(.leading, 4)
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
        HStack(spacing: 9) {
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(accent)
                .frame(width: 3, height: 24)
                .accessibilityHidden(true)

            Text(LocalizedStringKey(title))
                .textCase(.uppercase)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(0.55)
                .foregroundStyle(accent)
            Spacer(minLength: 8)
            if let detail {
                Text(LocalizedStringKey(detail))
                    .textCase(.uppercase)
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(accent)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .overlay {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(
                                accent.opacity(0.62),
                                style: StrokeStyle(lineWidth: 1, dash: [3, 2])
                            )
                    }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(minHeight: 38)
        .kitchenTableSurface(
            fill: KitchenTablePalette.paperRaised,
            border: KitchenTablePalette.rule,
            cornerRadius: 6,
            shadowRadius: 3,
            shadowY: 2
        )
    }

    private var accent: Color {
        switch style {
        case .cobalt: KitchenTablePalette.cobaltDeep
        case .acid: KitchenTablePalette.brassDeep
        case .ink: KitchenTablePalette.espresso
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
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
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
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
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
