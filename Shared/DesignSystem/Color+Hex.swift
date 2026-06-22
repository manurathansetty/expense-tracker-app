import SwiftUI

extension Color {
    /// Create a color from a hex string like "FF9F0A" or "#FF9F0A".
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "# ")).uppercased()
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let r, g, b, a: Double
        switch cleaned.count {
        case 8: // RRGGBBAA
            r = Double((value >> 24) & 0xFF) / 255
            g = Double((value >> 16) & 0xFF) / 255
            b = Double((value >> 8) & 0xFF) / 255
            a = Double(value & 0xFF) / 255
        case 6: // RRGGBB
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
            a = 1
        default:
            r = 0.37; g = 0.36; b = 0.90; a = 1 // fallback indigo
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    /// A small curated palette used by the color pickers for themes and people.
    static let tallyPalette: [String] = [
        "FF6B6B", "FF9F0A", "FFD60A", "34C759", "30B0C7",
        "0A84FF", "5E5CE6", "BF5AF2", "FF2D55", "FF375F",
        "8E8E93", "AF52DE", "64D2FF", "30D158", "FF9500",
    ]
}
