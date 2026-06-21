import SwiftUI

// MARK: — No Fomo Design System
// Pixel-matched to the design prototype (No Fomo.html)

enum DS {

    // MARK: Colors
    enum Color {
        static let background     = SwiftUI.Color(hex: "#0A0A0F")
        static let card           = SwiftUI.Color(hex: "#12121A")
        static let elevated       = SwiftUI.Color(hex: "#1A1A26")
        static let ringTrack      = SwiftUI.Color.white.opacity(0.07)

        static let bull           = SwiftUI.Color(hex: "#00FF88")  // electric mint
        static let bear           = SwiftUI.Color(hex: "#FF3B5C")  // clean red

        static let tier1          = SwiftUI.Color(hex: "#FFD700")  // gold
        static let tier2          = SwiftUI.Color(hex: "#00BFFF")  // electric blue

        static let accent         = SwiftUI.Color(hex: "#7B61FF")  // purple — AI/intelligence
        static let neutral        = SwiftUI.Color(hex: "#8888AA")  // deprecated — use contextual colors

        static let textPrimary    = SwiftUI.Color.white
        static let textSecondary  = SwiftUI.Color(hex: "#8888AA")
        static let textMuted      = SwiftUI.Color(hex: "#565676")

        // Borders — barely there, cards defined by depth not lines
        static let border         = SwiftUI.Color.white.opacity(0.06)
        static let borderStrong   = SwiftUI.Color.white.opacity(0.14)
    }

    // MARK: Typography — system fonts that map to SF Pro / SF Mono on iOS
    enum Font {
        // Display/headlines — geometric sans
        static func displayBold(_ size: CGFloat) -> SwiftUI.Font {
            .system(size: size, weight: .bold, design: .default)
        }
        static func displayMedium(_ size: CGFloat) -> SwiftUI.Font {
            .system(size: size, weight: .medium, design: .default)
        }
        // Monospaced for all financial figures — this is data, treat it as data
        static func mono(_ size: CGFloat) -> SwiftUI.Font {
            .system(size: size, weight: .semibold, design: .monospaced)
        }
        static func monoRegular(_ size: CGFloat) -> SwiftUI.Font {
            .system(size: size, weight: .regular, design: .monospaced)
        }
        // Body — same family, regular weight, readable
        static func body(_ size: CGFloat = 15) -> SwiftUI.Font {
            .system(size: size, weight: .regular)
        }
        // Caption / labels
        static func caption(_ size: CGFloat = 12) -> SwiftUI.Font {
            .system(size: size, weight: .medium)
        }
    }

    // MARK: Radius / Spacing
    static let radiusCard: CGFloat = 18
    static let radiusSmall: CGFloat = 8
    static let radiusPill: CGFloat = 99
    static let paddingCard: CGFloat = 17
    static let paddingCompact: CGFloat = 14
    static let paddingScreen: CGFloat = 20

    // MARK: Touch targets
    /// Minimum tap area per HIG (44 × 44 pt)
    static let minTouchTarget: CGFloat = 44

    // MARK: Vertical rhythm — section separators
    /// Vertical gap above a section's content (after the header label)
    static let sectionTopPad: CGFloat = 16
    /// Vertical gap below a section's content
    static let sectionBottomPad: CGFloat = 18

    // MARK: Animation — centralised so every state change matches
    enum Animation {
        static let micro  = SwiftUI.Animation.easeInOut(duration: 0.15)   // pressed states
        static let quick  = SwiftUI.Animation.easeInOut(duration: 0.20)   // toggles, chips
        static let spring = SwiftUI.Animation.spring(response: 0.28, dampingFraction: 0.75)
    }
}

// MARK: — Color hex init

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted))
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255
        let g = Double((rgb >> 8) & 0xFF) / 255
        let b = Double(rgb & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: — Verdict helpers (BULL / BEAR only, no neutral)

enum Verdict: String, Codable {
    case bull = "BULL"
    case bear = "BEAR"

    var color: Color {
        switch self {
        case .bull: return DS.Color.bull
        case .bear: return DS.Color.bear
        }
    }
    var label: String {
        switch self {
        case .bull: return "BULL"
        case .bear: return "BEAR"
        }
    }
}

// MARK: — Tier helpers

extension Int {
    var tierColor: Color {
        switch self {
        case 1: return DS.Color.tier1
        case 2: return DS.Color.tier2
        default: return DS.Color.textMuted
        }
    }
    var tierLabel: String {
        switch self {
        case 1: return "EXCEPTIONAL"
        case 2: return "HIGH CONVICTION"
        default: return ""
        }
    }
    var tierShort: String { "T\(self)" }
}
