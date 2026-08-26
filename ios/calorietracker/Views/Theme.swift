import SwiftUI
import UIKit

enum AppThemeColor: String, CaseIterable, Identifiable {
    case fudPink
    case red
    case orange
    case green
    case mint
    case teal
    case blue
    case purple
    case yellow
    case coral
    case roseGold
    case mochaBrown
    case indigo
    case lavender
    case skyCyan
    case graphite
    case babyPink
    case lime

    static let storageKey = "appThemeColor"
    static let defaultColor: AppThemeColor = .fudPink

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fudPink: return LocalizedDisplayText.text("Fud Pink", polish: "Róż Fud")
        case .red: return LocalizedDisplayText.text("Red", polish: "Czerwony")
        case .orange: return LocalizedDisplayText.text("Orange", polish: "Pomarańczowy")
        case .green: return LocalizedDisplayText.text("Green", polish: "Zielony")
        case .mint: return LocalizedDisplayText.text("Mint", polish: "Miętowy")
        case .teal: return LocalizedDisplayText.text("Teal", polish: "Turkusowy")
        case .blue: return LocalizedDisplayText.text("Blue", polish: "Niebieski")
        case .purple: return LocalizedDisplayText.text("Purple", polish: "Fioletowy")
        case .yellow: return LocalizedDisplayText.text("Yellow", polish: "Żółty")
        case .coral: return LocalizedDisplayText.text("Coral", polish: "Koralowy")
        case .roseGold: return LocalizedDisplayText.text("Rose Gold", polish: "Różowe złoto")
        case .mochaBrown: return LocalizedDisplayText.text("Mocha Brown", polish: "Brąz mokka")
        case .indigo: return LocalizedDisplayText.text("Indigo", polish: "Indygo")
        case .lavender: return LocalizedDisplayText.text("Lavender", polish: "Lawendowy")
        case .skyCyan: return LocalizedDisplayText.text("Sky Cyan", polish: "Błękit")
        case .graphite: return LocalizedDisplayText.text("Graphite", polish: "Grafitowy")
        case .babyPink: return LocalizedDisplayText.text("Baby Pink", polish: "Pastelowy róż")
        case .lime: return LocalizedDisplayText.text("Lime", polish: "Limonkowy")
        }
    }

    var color: Color {
        Color(hex: startHex)
    }

    var gradientColors: [Color] {
        [Color(hex: startHex), Color(hex: endHex)]
    }

    var alternateIconName: String? {
        switch self {
        case .fudPink: return nil
        case .red: return "AppIconRed"
        case .orange: return "AppIconOrange"
        case .green: return "AppIconGreen"
        case .mint: return "AppIconMint"
        case .teal: return "AppIconTeal"
        case .blue: return "AppIconBlue"
        case .purple: return "AppIconPurple"
        case .yellow: return "AppIconYellow"
        case .coral: return "AppIconCoral"
        case .roseGold: return "AppIconRoseGold"
        case .mochaBrown: return "AppIconMochaBrown"
        case .indigo: return "AppIconIndigo"
        case .lavender: return "AppIconLavender"
        case .skyCyan: return "AppIconSkyCyan"
        case .graphite: return "AppIconGraphite"
        case .babyPink: return "AppIconBabyPink"
        case .lime: return "AppIconLime"
        }
    }

    static var current: AppThemeColor {
        guard let rawValue = UserDefaults.standard.string(forKey: storageKey),
              let themeColor = AppThemeColor(rawValue: rawValue) else {
            return defaultColor
        }
        return themeColor
    }

    static func color(for rawValue: String) -> AppThemeColor {
        AppThemeColor(rawValue: rawValue) ?? defaultColor
    }

    // Menu (dropdown) rows render SwiftUI colors as monochrome templates, so the
    // swatch has to be a pre-rendered UIImage marked alwaysOriginal to keep its color.
    var menuSwatchImage: UIImage {
        let size = CGSize(width: 22, height: 22)
        let image = UIGraphicsImageRenderer(size: size).image { context in
            let rect = CGRect(origin: .zero, size: size)
            UIBezierPath(ovalIn: rect).addClip()
            let colors = [UIColor(color), UIColor(gradientColors.last ?? color)].map(\.cgColor)
            if let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors as CFArray,
                locations: [0, 1]
            ) {
                context.cgContext.drawLinearGradient(
                    gradient,
                    start: .zero,
                    end: CGPoint(x: size.width, y: size.height),
                    options: []
                )
            }
        }
        return image.withRenderingMode(.alwaysOriginal)
    }

    @MainActor
    static func applyAppIconIfNeeded(for themeColor: AppThemeColor) {
        let application = UIApplication.shared
        guard application.supportsAlternateIcons,
              application.alternateIconName != themeColor.alternateIconName else {
            return
        }

        application.setAlternateIconName(themeColor.alternateIconName)
    }

    // Internal (not private) so WidgetSnapshotWriter can ship the raw hexes to
    // the Watch, which has no AppThemeColor and rebuilds Colors from the values.
    var startHex: UInt {
        switch self {
        case .fudPink: return 0xFF375F
        case .red: return 0xFF3B30
        case .orange: return 0xFF9500
        case .green: return 0x34C759
        case .mint: return 0x00C7BE
        case .teal: return 0x30B0C7
        case .blue: return 0x0A84FF
        case .purple: return 0xAF52DE
        case .yellow: return 0xFFCC00
        case .coral: return 0xFF7F50
        case .roseGold: return 0xC9807C
        case .mochaBrown: return 0xA2845E
        case .indigo: return 0x5856D6
        case .lavender: return 0xB57EDC
        case .skyCyan: return 0x32ADE6
        case .graphite: return 0x8E8E93
        case .babyPink: return 0xFF8FAB
        case .lime: return 0xA0D911
        }
    }

    var endHex: UInt {
        switch self {
        case .fudPink: return 0xFF6B8A
        case .red: return 0xFF6961
        case .orange: return 0xFFB340
        case .green: return 0x62D46F
        case .mint: return 0x66D4CF
        case .teal: return 0x64D2FF
        case .blue: return 0x5EAEFF
        case .purple: return 0xBF5AF2
        case .yellow: return 0xFFD60A
        case .coral: return 0xFFA382
        case .roseGold: return 0xE8B4B0
        case .mochaBrown: return 0xC9A57E
        case .indigo: return 0x7D7AFF
        case .lavender: return 0xD0A9F5
        case .skyCyan: return 0x70CFFF
        case .graphite: return 0xB8B8BE
        case .babyPink: return 0xFFB3C6
        case .lime: return 0xC3E956
        }
    }
}

enum AppColors {
    // Version 7 keeps the saved theme preference intact for alternate icons,
    // widgets, Watch, and migration compatibility. The in-app Kitchen Table
    // palette uses distinct, accessible food-led accents for quick scanning.
    static var calorieGradient: [Color] { [KitchenTablePalette.tomatoDeep, KitchenTablePalette.tomato] }
    static var calorie: Color { KitchenTablePalette.tomato }
    static var userAccent: Color { AppThemeColor.current.color }

    // Protein
    static var proteinGradient: [Color] { [KitchenTablePalette.herbDeep, KitchenTablePalette.herb] }
    static var protein: Color { KitchenTablePalette.herb }

    // Carbs
    static var carbsGradient: [Color] { [KitchenTablePalette.brassDeep, KitchenTablePalette.brass] }
    static var carbs: Color { KitchenTablePalette.brass }

    // Fat
    static var fatGradient: [Color] { [KitchenTablePalette.cobaltDeep, KitchenTablePalette.cobalt] }
    static var fat: Color { KitchenTablePalette.cobalt }

    // App-wide surfaces follow the 7.0 Neo-Brutalist system. Keeping these
    // semantic entry points means every legacy/secondary screen inherits the
    // redesign without changing its storage or behavior wiring.
    static let appBackground = KitchenTablePalette.canvas
    static let appCard = KitchenTablePalette.paper
}

/// Warm, tactile colors shared by every app-owned surface. Values adapt for Dark
/// Mode and Increase Contrast while keeping color roles stable: tomato for the
/// primary food action, cobalt for navigation/data, herb for success/protein,
/// and brass for secondary highlights.
enum KitchenTablePalette {
    private static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }

    static let canvas = adaptive(
        light: UIColor(red: 0.967, green: 0.944, blue: 0.895, alpha: 1),
        dark: UIColor(red: 0.075, green: 0.052, blue: 0.036, alpha: 1)
    )
    static let paper = adaptive(
        light: UIColor(red: 0.997, green: 0.982, blue: 0.941, alpha: 1),
        dark: UIColor(red: 0.145, green: 0.111, blue: 0.079, alpha: 1)
    )
    static let paperRaised = adaptive(
        light: UIColor(red: 1.0, green: 0.994, blue: 0.971, alpha: 1),
        dark: UIColor(red: 0.190, green: 0.148, blue: 0.105, alpha: 1)
    )
    static let paperMuted = adaptive(
        light: UIColor(red: 0.925, green: 0.886, blue: 0.805, alpha: 1),
        dark: UIColor(red: 0.255, green: 0.198, blue: 0.137, alpha: 1)
    )

    static let espresso = Color(uiColor: UIColor { traits in
        if traits.userInterfaceStyle == .dark {
            return traits.accessibilityContrast == .high
                ? UIColor(red: 1.0, green: 0.978, blue: 0.925, alpha: 1)
                : UIColor(red: 0.949, green: 0.906, blue: 0.821, alpha: 1)
        }
        let value: CGFloat = traits.accessibilityContrast == .high ? 0.045 : 0.075
        return UIColor(red: value + 0.085, green: value + 0.040, blue: value, alpha: 1)
    })
    static let mutedEspresso = adaptive(
        light: UIColor(red: 0.365, green: 0.296, blue: 0.235, alpha: 1),
        dark: UIColor(red: 0.760, green: 0.698, blue: 0.598, alpha: 1)
    )
    static let tomato = adaptive(
        light: UIColor(red: 0.874, green: 0.231, blue: 0.126, alpha: 1),
        dark: UIColor(red: 0.745, green: 0.245, blue: 0.160, alpha: 1)
    )
    static let tomatoDeep = adaptive(
        light: UIColor(red: 0.655, green: 0.128, blue: 0.072, alpha: 1),
        dark: UIColor(red: 0.965, green: 0.430, blue: 0.310, alpha: 1)
    )
    static let cobalt = adaptive(
        light: UIColor(red: 0.075, green: 0.245, blue: 0.650, alpha: 1),
        dark: UIColor(red: 0.210, green: 0.355, blue: 0.675, alpha: 1)
    )
    static let cobaltDeep = adaptive(
        light: UIColor(red: 0.040, green: 0.145, blue: 0.430, alpha: 1),
        dark: UIColor(red: 0.505, green: 0.635, blue: 0.905, alpha: 1)
    )
    static let herb = adaptive(
        light: UIColor(red: 0.245, green: 0.425, blue: 0.220, alpha: 1),
        dark: UIColor(red: 0.285, green: 0.480, blue: 0.285, alpha: 1)
    )
    static let herbDeep = adaptive(
        light: UIColor(red: 0.115, green: 0.280, blue: 0.125, alpha: 1),
        dark: UIColor(red: 0.560, green: 0.735, blue: 0.520, alpha: 1)
    )
    static let brass = adaptive(
        light: UIColor(red: 0.770, green: 0.555, blue: 0.205, alpha: 1),
        dark: UIColor(red: 0.815, green: 0.620, blue: 0.285, alpha: 1)
    )
    static let brassDeep = adaptive(
        light: UIColor(red: 0.550, green: 0.330, blue: 0.085, alpha: 1),
        dark: UIColor(red: 0.930, green: 0.755, blue: 0.405, alpha: 1)
    )
    static let onStrongAccent = adaptive(
        light: UIColor(red: 1.0, green: 0.977, blue: 0.920, alpha: 1),
        dark: UIColor(red: 1.0, green: 0.960, blue: 0.875, alpha: 1)
    )
    static let onBrass = Color(red: 0.155, green: 0.095, blue: 0.055)
    static let rule = espresso.opacity(0.20)
    static let strongRule = espresso.opacity(0.42)
    static let shadow = Color(uiColor: UIColor { traits in
        UIColor.black.withAlphaComponent(traits.userInterfaceStyle == .dark ? 0.34 : 0.12)
    })
}

/// A restrained shared paper grain. It is decorative, ignores interaction, and
/// disappears when Reduce Transparency is enabled. Keeping it here prevents
/// every card or list row from decoding and layering its own texture.
struct KitchenTableBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        ZStack {
            KitchenTablePalette.canvas

            LinearGradient(
                colors: [
                    KitchenTablePalette.paper.opacity(colorScheme == .dark ? 0.22 : 0.38),
                    KitchenTablePalette.canvas,
                    (colorScheme == .dark ? KitchenTablePalette.brass : KitchenTablePalette.tomato)
                        .opacity(colorScheme == .dark ? 0.025 : 0.025)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if !reduceTransparency {
                Image(decorative: "KitchenPaper")
                    .resizable()
                    .scaledToFill()
                    .blendMode(colorScheme == .dark ? .softLight : .multiply)
                    .opacity(colorScheme == .dark ? 0.075 : 0.10)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .ignoresSafeArea()
    }
}

private struct KitchenTableSurfaceModifier: ViewModifier {
    let fill: Color
    let border: Color
    let cornerRadius: CGFloat
    let lineWidth: CGFloat
    let shadowRadius: CGFloat
    let shadowY: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background(fill, in: shape)
            .clipShape(shape)
            .overlay {
                shape.strokeBorder(border, lineWidth: lineWidth)
            }
            .shadow(color: KitchenTablePalette.shadow, radius: shadowRadius, x: 0, y: shadowY)
    }
}

struct KitchenTablePressableButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let isPressed = configuration.isPressed && isEnabled
        configuration.label
            .scaleEffect(reduceMotion ? 1 : (isPressed ? 0.985 : 1))
            .opacity(isEnabled ? (isPressed ? 0.78 : 1) : 0.46)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: isPressed)
    }
}

extension View {
    func kitchenTableSurface(
        fill: Color = KitchenTablePalette.paper,
        border: Color = KitchenTablePalette.rule,
        cornerRadius: CGFloat = 18,
        lineWidth: CGFloat = 1,
        shadowRadius: CGFloat = 7,
        shadowY: CGFloat = 3
    ) -> some View {
        modifier(
            KitchenTableSurfaceModifier(
                fill: fill,
                border: border,
                cornerRadius: cornerRadius,
                lineWidth: lineWidth,
                shadowRadius: shadowRadius,
                shadowY: shadowY
            )
        )
    }

    func kitchenTableIconTile(
        fill: Color,
        border: Color = KitchenTablePalette.rule,
        cornerRadius: CGFloat = 14
    ) -> some View {
        background(fill, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(border, lineWidth: 1)
            }
            .shadow(color: KitchenTablePalette.shadow, radius: 3, x: 0, y: 2)
    }
}

/// Compatibility names retained so the v7 screen structure and all call sites
/// stay unchanged while their visual values resolve through Kitchen Table.
enum NeoHomeColors {
    static let canvas = KitchenTablePalette.canvas
    static let surface = KitchenTablePalette.paper
    static let ink = KitchenTablePalette.espresso
    static let mutedInk = KitchenTablePalette.mutedEspresso
    static let cobalt = KitchenTablePalette.cobalt
    static let onCobalt = KitchenTablePalette.onStrongAccent
    static let cobaltDeep = KitchenTablePalette.cobaltDeep
    static let acidYellow = KitchenTablePalette.brass
    static let paperWhite = KitchenTablePalette.paperRaised
    static let tomato = KitchenTablePalette.tomato
    static let herb = KitchenTablePalette.herb
    static let brass = KitchenTablePalette.brass
}

enum NeoHomeMetrics {
    static let rule: CGFloat = 1
    static let compactRule: CGFloat = 0.75
    static let cornerRadius: CGFloat = 18
    static let horizontalInset: CGFloat = 16
}

extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
