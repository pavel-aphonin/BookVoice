//
//  PreprocessingOptions.swift
//  BookVoice
//

import Foundation

struct PreprocessingOptions: Codable, Equatable {
    var stressMarks: Bool = true          // Ударения (U+0301)
    var emotionMarkup: Bool = true        // Эмоции/интонация
    var pauseInsertion: Bool = true       // Паузы
    var numberExpansion: Bool = true      // Числительные → слова
    var abbreviationExpansion: Bool = true // Аббревиатуры → полные формы
    var audioRephrasing: Bool = false     // Перефразирование для аудиовосприятия
    var intensity: PreprocessingIntensity = .moderate

    static let `default` = PreprocessingOptions()
}
