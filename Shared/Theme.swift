import SwiftUI
import UIKit

/// "Desert dawn / ink and lamp" palette. See docs/ux.md.
enum Theme {
    static let background = color(light: 0xF7F3EC, dark: 0x0E1116)
    static let surface = color(light: 0xFFFFFF, dark: 0x171B22)
    static let focus = color(light: 0x0F6E6A, dark: 0x3FB8AE)
    static let gold = color(light: 0xC8902E, dark: 0xE2B45A)
    static let pass = color(light: 0xD9822B, dark: 0xF0A04B)
    static let night = color(light: 0x2B3A67, dark: 0x7F8FD1)
    static let text = color(light: 0x1C1B19, dark: 0xECE8E1)
    static let secondaryText = color(light: 0x6B665E, dark: 0x9AA0A9)

    static let uiFocus = uiColor(light: 0x0F6E6A, dark: 0x3FB8AE)
    static let uiNight = uiColor(light: 0x2B3A67, dark: 0x7F8FD1)
    static let uiPass = uiColor(light: 0xD9822B, dark: 0xF0A04B)

    static func uiColor(light: UInt32, dark: UInt32) -> UIColor {
        UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        }
    }

    static func color(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: uiColor(light: light, dark: dark))
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}
