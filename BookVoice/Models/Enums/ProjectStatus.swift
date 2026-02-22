//
//  ProjectStatus.swift
//  BookVoice
//

import SwiftUI

enum ProjectStatus: String, Codable, CaseIterable {
    case draft
    case textLoaded
    case synthesizing
    case converting
    case postProcessing
    case completed
    case failed

    var displayName: String {
        switch self {
        case .draft: "Draft"
        case .textLoaded: "Text Loaded"
        case .synthesizing: "Synthesizing"
        case .converting: "Converting"
        case .postProcessing: "Processing"
        case .completed: "Completed"
        case .failed: "Failed"
        }
    }

    var icon: String {
        switch self {
        case .draft: "doc"
        case .textLoaded: "doc.text"
        case .synthesizing: "waveform"
        case .converting: "waveform.path.ecg"
        case .postProcessing: "gearshape.2"
        case .completed: "checkmark.circle"
        case .failed: "exclamationmark.triangle"
        }
    }

    var color: Color {
        switch self {
        case .draft: .statusDraft
        case .textLoaded: .blue
        case .synthesizing, .converting, .postProcessing: .statusInProgress
        case .completed: .statusCompleted
        case .failed: .statusFailed
        }
    }
}
