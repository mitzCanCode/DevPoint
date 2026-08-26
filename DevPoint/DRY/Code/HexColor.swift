//
//  HexColor.swift
//  SoloLift
//
//  Created by Dimitris Chatzigeorgiou on 3/10/25.
//

import SwiftUI



// MARK: Extension used for using hex codes with colors
extension Color {
    init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        
        let red = Double((rgb & 0xFF0000) >> 16) / 255.0
        let green = Double((rgb & 0x00FF00) >> 8) / 255.0
        let blue = Double(rgb & 0x0000FF) / 255.0
        
        self.init(red: red, green: green, blue: blue)
    }
    
    static let crimsonRed = Color(hex: "DC143C")
    static let deepCharcoal = Color(hex: "1C1C1C")
    static let fieryOrange = Color(hex: "FF4500")
    static let bloodRed = Color(hex: "8B0000")
    static let hotPink = Color(hex: "FF1493")
    static let smokyGray = Color(hex: "2F2F2F")
    static let obsidianBlack = Color(hex: "0B0B0B")
    static let burnishedSteel = Color(hex: "F5F5F5")
}

public enum ThemeColor: String, CaseIterable, Identifiable {
    case accent = "AccentColor"
    case blueAccent = "BlueAccent"
    case brownAccent = "BrownAccent"
    case greenAccent = "GreenAccent"
    case purpleAccent = "PurpleAccent"
    case yellowAccent = "YellowAccent"

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .accent: return "Solo Red"
        case .blueAccent: return "Deep blue"
        case .brownAccent: return "Chocolate"
        case .greenAccent: return "Emerald"
        case .purpleAccent: return "Amethyst"
        case .yellowAccent: return "Lightning"
        }
    }
    
    /// SwiftUI Color backed by an asset with the same name
    public var color: Color { Color(rawValue) }
}

