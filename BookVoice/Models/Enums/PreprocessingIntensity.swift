//
//  PreprocessingIntensity.swift
//  BookVoice
//

import Foundation

enum PreprocessingIntensity: String, Codable, CaseIterable {
    case minimal
    case moderate
    case maximal

    var displayName: String {
        switch self {
        case .minimal:  "Минимальная"
        case .moderate: "Умеренная"
        case .maximal:  "Максимальная"
        }
    }
}
