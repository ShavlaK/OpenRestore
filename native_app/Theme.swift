import SwiftUI

// MARK: - Theme & Design System (macOS HIG)
public struct Theme {
    
    // MARK: - Colors
    public struct Colors {
        // App Accents
        public static let blue = Color(nsColor: NSColor(named: "AppleBlue") ?? NSColor(red: 0/255, green: 122/255, blue: 255/255, alpha: 1.0)) // #007AFF light / #0A84FF dark
        public static let green = Color(nsColor: NSColor(named: "AppleGreen") ?? NSColor(red: 52/255, green: 199/255, blue: 89/255, alpha: 1.0)) // #34C759
        public static let amber = Color(nsColor: NSColor(named: "AppleAmber") ?? NSColor(red: 255/255, green: 149/255, blue: 0/255, alpha: 1.0)) // #FF9500
        
        // Backgrounds & Cards (Adaptive)
        public static let windowBackground = Color(nsColor: .windowBackgroundColor)
        
        // Border colors
        public static let borderLight = Color.black.opacity(0.06)
        public static let borderDark = Color.white.opacity(0.08)
        
        // Semantic dynamic border based on color scheme
        public static func cardBorder(for scheme: ColorScheme) -> Color {
            scheme == .dark ? borderDark : borderLight
        }
        
        // Semantic dynamic background for cards based on color scheme
        public static func cardBackground(for scheme: ColorScheme) -> Color {
            scheme == .dark ? Color.white.opacity(0.05) : Color.white
        }
        
        public static func cardHover(for scheme: ColorScheme) -> Color {
            scheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.03)
        }
    }
    
    // MARK: - Typography
    public struct Typography {
        // Section headers: 13px (Semibold, Uppercase, Tracking +0.5px, Muted)
        public static let sectionHeader = Font.system(size: 13, weight: .semibold).width(.standard)
        
        // Card/App Titles: 14px (Medium/Semibold)
        public static let cardTitle = Font.system(size: 14, weight: .semibold)
        
        // Subtitles/Meta (Bundle ID, size): 12px (Regular, Opacity 60%)
        public static let subtitle = Font.system(size: 12, weight: .regular)
        
        // Aux/Indicators: 11px
        public static let aux = Font.system(size: 11, weight: .medium)
    }
    
    // MARK: - Geometry (Radii & Spacing)
    public struct Metrics {
        // Radii
        public static let radiusWindow: CGFloat = 16.0
        public static let radiusCard: CGFloat = 10.0
        public static let radiusButton: CGFloat = 8.0
        public static let radiusIcon: CGFloat = 8.0
        
        // 4px Grid Spacing
        public static let padding4: CGFloat = 4.0
        public static let padding8: CGFloat = 8.0
        public static let padding12: CGFloat = 12.0
        public static let padding16: CGFloat = 16.0
        public static let padding20: CGFloat = 20.0
        public static let padding24: CGFloat = 24.0
        
        // Icon Sizes
        public static let iconSizeLarge: CGFloat = 40.0
        public static let iconSizeSmall: CGFloat = 36.0
    }
}

// MARK: - Theme ViewModifiers
public struct SectionHeaderModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .font(Theme.Typography.sectionHeader)
            .textCase(.uppercase)
            .kerning(0.5)
            .foregroundColor(.secondary)
    }
}

public struct CardTitleModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .font(Theme.Typography.cardTitle)
            .foregroundColor(.primary)
    }
}

public struct SubtitleModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .font(Theme.Typography.subtitle)
            .foregroundColor(.secondary)
            .opacity(0.8) // Adjusted since foregroundColor(.secondary) already reduces opacity, but we can fine-tune it
    }
}

public struct AuxModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .font(Theme.Typography.aux)
            .foregroundColor(.secondary)
    }
}

public extension View {
    func themeSectionHeader() -> some View {
        self.modifier(SectionHeaderModifier())
    }
    func themeCardTitle() -> some View {
        self.modifier(CardTitleModifier())
    }
    func themeSubtitle() -> some View {
        self.modifier(SubtitleModifier())
    }
    func themeAux() -> some View {
        self.modifier(AuxModifier())
    }
    
    func themeCardBackground(scheme: ColorScheme) -> some View {
        self.background(Theme.Colors.cardBackground(for: scheme))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Metrics.radiusCard, style: .continuous)
                    .stroke(Theme.Colors.cardBorder(for: scheme), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.radiusCard, style: .continuous))
    }
}
