import SwiftUI
import AppKit

// MARK: - Theme & Design System (macOS Tahoe / Liquid Glass HIG)
public struct Theme {
    
    // MARK: - Colors & Semantic Tokens
    public struct Colors {
        // App Core Accents
        public static let blue = Color(nsColor: NSColor(named: "AppleBlue") ?? NSColor(red: 0/255, green: 122/255, blue: 255/255, alpha: 1.0))
        public static let green = Color(nsColor: NSColor(named: "AppleGreen") ?? NSColor(red: 52/255, green: 199/255, blue: 89/255, alpha: 1.0))
        public static let amber = Color(nsColor: NSColor(named: "AppleAmber") ?? NSColor(red: 255/255, green: 149/255, blue: 0/255, alpha: 1.0))
        public static let orange = amber
        public static let purple = Color(red: 175/255, green: 82/255, blue: 222/255)
        public static let red = Color(red: 255/255, green: 59/255, blue: 48/255)
        public static let teal = Color(red: 90/255, green: 200/255, blue: 250/255)
        public static let gray = Color(red: 142/255, green: 142/255, blue: 147/255)

        // Semantic Tints
        public static func blueTint(for scheme: ColorScheme) -> Color {
            blue.opacity(scheme == .dark ? 0.16 : 0.10)
        }
        public static func greenTint(for scheme: ColorScheme) -> Color {
            green.opacity(scheme == .dark ? 0.16 : 0.14)
        }
        public static func orangeTint(for scheme: ColorScheme) -> Color {
            orange.opacity(scheme == .dark ? 0.16 : 0.14)
        }
        public static func redTint(for scheme: ColorScheme) -> Color {
            red.opacity(scheme == .dark ? 0.14 : 0.12)
        }
        public static func purpleTint(for scheme: ColorScheme) -> Color {
            purple.opacity(scheme == .dark ? 0.16 : 0.12)
        }
        
        // Window & Canvas Backgrounds
        public static func windowBackground(for scheme: ColorScheme) -> Color {
            scheme == .dark ? Color(red: 14/255, green: 15/255, blue: 20/255) : Color(red: 234/255, green: 236/255, blue: 242/255)
        }
        public static func windowFrostedTint(for scheme: ColorScheme) -> Color {
            scheme == .dark
                ? Color(red: 16/255, green: 17/255, blue: 23/255).opacity(0.72)
                : Color(red: 240/255, green: 242/255, blue: 248/255).opacity(0.68)
        }
        public static func windowBorder(for scheme: ColorScheme) -> Color {
            scheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.10)
        }
        public static func sidebarBackground(for scheme: ColorScheme) -> Color {
            scheme == .dark ? Color(red: 34/255, green: 34/255, blue: 42/255, opacity: 0.82) : Color(red: 255/255, green: 255/255, blue: 255/255, opacity: 0.68)
        }
        public static func sidebarBorder(for scheme: ColorScheme) -> Color {
            scheme == .dark ? Color.white.opacity(0.10) : Color.white.opacity(0.85)
        }
        public static func canvasBackground(for scheme: ColorScheme) -> Color {
            scheme == .dark ? Color(red: 22/255, green: 22/255, blue: 26/255, opacity: 0.88) : Color(red: 246/255, green: 246/255, blue: 250/255, opacity: 0.85)
        }

        // Cards & Sections
        public static func cardBackground(for scheme: ColorScheme) -> Color {
            scheme == .dark ? Color.white.opacity(0.055) : Color.white.opacity(0.80)
        }
        public static func cardBackgroundHover(for scheme: ColorScheme) -> Color {
            scheme == .dark ? Color.white.opacity(0.085) : Color.white.opacity(0.95)
        }
        public static func cardBorder(for scheme: ColorScheme) -> Color {
            scheme == .dark ? Color.white.opacity(0.085) : Color.black.opacity(0.07)
        }
        public static func cardShadow(for scheme: ColorScheme) -> Color {
            scheme == .dark ? Color.black.opacity(0.25) : Color.black.opacity(0.04)
        }

        // Controls (Liquid Glass)
        public static func ctrlBackground(for scheme: ColorScheme) -> Color {
            scheme == .dark ? Color.white.opacity(0.09) : Color.white.opacity(0.60)
        }
        public static func ctrlBackgroundHover(for scheme: ColorScheme) -> Color {
            scheme == .dark ? Color.white.opacity(0.14) : Color.white.opacity(0.85)
        }
        public static func ctrlBorder(for scheme: ColorScheme) -> Color {
            scheme == .dark ? Color.white.opacity(0.12) : Color.white.opacity(0.90)
        }
        public static func ctrlHighlight(for scheme: ColorScheme) -> Color {
            scheme == .dark ? Color.white.opacity(0.22) : Color.white.opacity(0.95)
        }

        // Input Fields
        public static func fieldBackground(for scheme: ColorScheme) -> Color {
            scheme == .dark ? Color.white.opacity(0.065) : Color.black.opacity(0.045)
        }
        public static func fieldBorder(for scheme: ColorScheme) -> Color {
            scheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.07)
        }

        // Dividers & Hairlines
        public static func hairline(for scheme: ColorScheme) -> Color {
            scheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.07)
        }
        public static func separator(for scheme: ColorScheme) -> Color {
            hairline(for: scheme)
        }

        // Sheets
        public static func sheetBackground(for scheme: ColorScheme) -> Color {
            scheme == .dark ? Color(red: 32/255, green: 32/255, blue: 38/255, opacity: 0.96) : Color(red: 246/255, green: 246/255, blue: 250/255, opacity: 0.96)
        }
        public static func sheetBorder(for scheme: ColorScheme) -> Color {
            scheme == .dark ? Color.white.opacity(0.12) : Color.white.opacity(0.90)
        }

        // Text Colors
        public static func textPrimary(for scheme: ColorScheme) -> Color {
            scheme == .dark ? Color(red: 245/255, green: 247/255, blue: 250/255) : Color(red: 12/255, green: 17/255, blue: 29/255)
        }
        public static func textSecondary(for scheme: ColorScheme) -> Color {
            scheme == .dark ? Color(red: 245/255, green: 247/255, blue: 250/255).opacity(0.70) : Color(red: 12/255, green: 17/255, blue: 29/255).opacity(0.65)
        }
        public static func textTertiary(for scheme: ColorScheme) -> Color {
            scheme == .dark ? Color(red: 245/255, green: 247/255, blue: 250/255).opacity(0.44) : Color(red: 12/255, green: 17/255, blue: 29/255).opacity(0.42)
        }
        public static func textQuaternary(for scheme: ColorScheme) -> Color {
            scheme == .dark ? Color(red: 245/255, green: 247/255, blue: 250/255).opacity(0.26) : Color(red: 12/255, green: 17/255, blue: 29/255).opacity(0.26)
        }

        // Control Background & Border aliases
        public static func controlBackground(for scheme: ColorScheme) -> Color {
            ctrlBackground(for: scheme)
        }
        public static func controlBorder(for scheme: ColorScheme) -> Color {
            ctrlBorder(for: scheme)
        }
    }
    
    // MARK: - Typography (SF Pro Hierarchy)
    public struct Typography {
        public static let hero = Font.system(size: 22, weight: .bold, design: .default)
        public static let pageTitle = Font.system(size: 17, weight: .bold, design: .default)
        public static let pageSubtitle = Font.system(size: 11.5, weight: .regular, design: .default)
        public static let sectionHeader = Font.system(size: 10.5, weight: .bold, design: .default)
        public static let cardTitle = Font.system(size: 14, weight: .semibold, design: .default)
        public static let subtitle = Font.system(size: 12, weight: .regular, design: .default)
        public static let aux = Font.system(size: 11, weight: .medium, design: .default)
        public static let pill = Font.system(size: 11, weight: .bold, design: .default)
        public static let pillSmall = Font.system(size: 10, weight: .bold, design: .default)
        public static let mono = Font.system(size: 12, weight: .semibold, design: .monospaced)
    }
    
    // MARK: - Geometry Metrics (macOS Tahoe Spec)
    public struct Metrics {
        public static let radiusWindow: CGFloat = 34.0
        public static let radiusPanel: CGFloat = 26.0
        public static let radiusSheet: CGFloat = 22.0
        public static let radiusSection: CGFloat = 16.0
        public static let radiusCard: CGFloat = 14.0
        public static let radiusButton: CGFloat = 12.0
        public static let radiusIcon: CGFloat = 10.0
        public static let radiusPill: CGFloat = 10.0
        public static let radiusBadge: CGFloat = 6.0
        
        public static let sidebarWidth: CGFloat = 300.0
        public static let windowPadding: CGFloat = 8.0
        public static let panelSpacing: CGFloat = 8.0
        
        // 4px Grid Spacing
        public static let padding4: CGFloat = 4.0
        public static let padding8: CGFloat = 8.0
        public static let padding10: CGFloat = 10.0
        public static let padding12: CGFloat = 12.0
        public static let padding14: CGFloat = 14.0
        public static let padding16: CGFloat = 16.0
        public static let padding20: CGFloat = 20.0
        public static let padding24: CGFloat = 24.0
        
        // Icon Sizes
        public static let iconSizeLarge: CGFloat = 40.0
        public static let iconSizeSmall: CGFloat = 36.0
        public static let iconSizeHero: CGFloat = 72.0
    }
}

// MARK: - Liquid Glass Button Style
public enum LiquidGlassVariant {
    case glass
    case primary
    case destructive
    case orange
    case green
    case blueTint
}

public enum LiquidGlassSize {
    case sm // height 28
    case md // height 30
    case lg // height 36
    
    var height: CGFloat {
        switch self {
        case .sm: return 28
        case .md: return 30
        case .lg: return 36
        }
    }
    
    var horizontalPadding: CGFloat {
        switch self {
        case .sm: return 12
        case .md: return 14
        case .lg: return 18
        }
    }
    
    var fontSize: CGFloat {
        switch self {
        case .sm: return 12
        case .md: return 13
        case .lg: return 13.5
        }
    }
}

public struct LiquidGlassButtonStyle: ButtonStyle {
    public var variant: LiquidGlassVariant = .glass
    public var size: LiquidGlassSize = .md
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled

    public init(variant: LiquidGlassVariant = .glass, size: LiquidGlassSize = .md) {
        self.variant = variant
        self.size = size
    }

    public func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 5) {
            configuration.label
                .font(.system(size: size.fontSize, weight: variant == .primary ? .semibold : .medium))
        }
        .padding(.horizontal, size.horizontalPadding)
        .frame(height: size.height)
        .foregroundColor(foregroundColor(isPressed: configuration.isPressed))
        .background(
            ZStack {
                backgroundShape(isPressed: configuration.isPressed)
                
                // Specular sheen top gradient
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.14 : 0.35),
                                Color.white.opacity(colorScheme == .dark ? 0.02 : 0.05),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                    .allowsHitTesting(false)
            }
        )
        .overlay(
            Capsule()
                .stroke(borderStroke(isPressed: configuration.isPressed), lineWidth: 1)
        )
        .shadow(
            color: shadowColor(isPressed: configuration.isPressed),
            radius: configuration.isPressed ? 1 : (variant == .primary ? 5 : 2),
            x: 0,
            y: configuration.isPressed ? 0 : 1
        )
        .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
        .opacity(isEnabled ? 1.0 : 0.45)
        .animation(.easeInOut(duration: 0.14), value: configuration.isPressed)
    }

    @ViewBuilder
    private func backgroundShape(isPressed: Bool) -> some View {
        switch variant {
        case .primary:
            LinearGradient(
                colors: [
                    Color(red: 45/255, green: 145/255, blue: 255/255),
                    Theme.Colors.blue
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .clipShape(Capsule())
        case .destructive:
            Color.red.opacity(colorScheme == .dark ? 0.16 : 0.12)
                .clipShape(Capsule())
        case .orange:
            Color.orange.opacity(colorScheme == .dark ? 0.18 : 0.14)
                .clipShape(Capsule())
        case .green:
            Color.green.opacity(colorScheme == .dark ? 0.18 : 0.14)
                .clipShape(Capsule())
        case .blueTint:
            Color.blue.opacity(colorScheme == .dark ? 0.18 : 0.12)
                .clipShape(Capsule())
        case .glass:
            if isPressed {
                Theme.Colors.ctrlBackgroundHover(for: colorScheme)
                    .clipShape(Capsule())
            } else {
                Theme.Colors.ctrlBackground(for: colorScheme)
                    .clipShape(Capsule())
            }
        }
    }

    private func foregroundColor(isPressed: Bool) -> Color {
        switch variant {
        case .primary:
            return .white
        case .destructive:
            return Theme.Colors.red
        case .orange:
            return Theme.Colors.orange
        case .green:
            return Theme.Colors.green
        case .blueTint:
            return Theme.Colors.blue
        case .glass:
            return .primary
        }
    }

    private func borderStroke(isPressed: Bool) -> Color {
        switch variant {
        case .primary:
            return Color.white.opacity(colorScheme == .dark ? 0.35 : 0.50)
        case .destructive:
            return Color.red.opacity(0.30)
        case .orange:
            return Color.orange.opacity(0.35)
        case .green:
            return Color.green.opacity(0.35)
        case .blueTint:
            return Color.blue.opacity(0.35)
        case .glass:
            return Theme.Colors.ctrlBorder(for: colorScheme)
        }
    }

    private func shadowColor(isPressed: Bool) -> Color {
        if variant == .primary {
            return Theme.Colors.blue.opacity(colorScheme == .dark ? 0.35 : 0.25)
        }
        return colorScheme == .dark ? Color.black.opacity(0.25) : Color.black.opacity(0.04)
    }
}

// MARK: - Legacy View Helpers for Compatibility
public extension View {
    func themeSectionHeader() -> some View {
        self.font(Theme.Typography.sectionHeader)
            .textCase(.uppercase)
            .kerning(0.5)
            .foregroundColor(.secondary.opacity(0.50))
    }
    func themeCardTitle() -> some View {
        self.font(Theme.Typography.cardTitle)
            .foregroundColor(.primary)
    }
    func themeSubtitle() -> some View {
        self.font(Theme.Typography.subtitle)
            .foregroundColor(.secondary)
            .opacity(0.8)
    }
    func themeAux() -> some View {
        self.font(Theme.Typography.aux)
            .foregroundColor(.secondary)
    }
    
    func themeCardBackground(scheme: ColorScheme) -> some View {
        self.background(Theme.Colors.cardBackground(for: scheme))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Metrics.radiusCard, style: .continuous)
                    .stroke(Theme.Colors.cardBorder(for: scheme), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.radiusCard, style: .continuous))
    }

    func themeSidebarCard(scheme: ColorScheme) -> some View {
        self.background(
            RoundedRectangle(cornerRadius: Theme.Metrics.radiusCard, style: .continuous)
                .fill(Theme.Colors.sidebarBackground(for: scheme))
                .shadow(color: scheme == .dark ? Color.clear : Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Metrics.radiusCard, style: .continuous)
                .stroke(Theme.Colors.sidebarBorder(for: scheme), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.radiusCard, style: .continuous))
    }

    func liquidGlass(variant: LiquidGlassVariant = .glass, size: LiquidGlassSize = .md) -> some View {
        self.buttonStyle(LiquidGlassButtonStyle(variant: variant, size: size))
    }
}
