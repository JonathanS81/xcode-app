//
//  ColorCodable.swift
//  YamSheet
//
//  Created by Jonathan Sportiche  on 28/09/2025.
//

import SwiftUI
import UIKit   // ✅ nécessaire pour UIColor

/// Helper pour rendre Color Codable (RGBA)
struct ColorCodable: Codable {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
    let alpha: CGFloat

    init(_ color: Color) {
        let uiColor = UIColor(color)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        self.red = r
        self.green = g
        self.blue = b
        self.alpha = a
    }

    var color: Color {
        Color(
            red: Double(red),
            green: Double(green),
            blue: Double(blue),
            opacity: Double(alpha)
        )
    }
}
