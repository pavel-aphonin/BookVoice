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
        case .draft: "Черновик"
        case .textLoaded: "Текст загружен"
        case .synthesizing: "Синтез"
        case .converting: "Конвертация"
        case .postProcessing: "Обработка"
        case .completed: "Завершён"
        case .failed: "Ошибка"
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
