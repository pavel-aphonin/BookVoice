//
//  Color+BookVoice.swift
//  BookVoice
//

import SwiftUI

extension Color {
    static let glassTint = Color.white.opacity(0.08)
    static let glassBackground = Color.black.opacity(0.3)
    static let glassStroke = Color.white.opacity(0.2)
    static let glassHighlight = Color.white.opacity(0.15)
    static let accentGlow = Color.accentColor.opacity(0.4)

    static let statusDraft = Color.gray
    static let statusInProgress = Color.orange
    static let statusCompleted = Color.green
    static let statusFailed = Color.red
}
