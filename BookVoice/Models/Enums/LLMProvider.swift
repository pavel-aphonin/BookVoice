//
//  LLMProvider.swift
//  BookVoice
//

import Foundation

enum LLMProvider: String, Codable, CaseIterable {
    case openai
    case claude
    case local

    var displayName: String {
        switch self {
        case .openai: "OpenAI GPT"
        case .claude: "Claude (Anthropic)"
        case .local: "Локальная модель"
        }
    }

    var requiresAPIKey: Bool {
        switch self {
        case .openai, .claude: true
        case .local: false
        }
    }

    var defaultModel: String {
        switch self {
        case .openai: "gpt-4o-mini"
        case .claude: "claude-sonnet-4-20250514"
        case .local: ""
        }
    }

    var apiKeySettingsKey: String? {
        switch self {
        case .openai: "openaiAPIKey"
        case .claude: "claudeAPIKey"
        case .local: nil
        }
    }

    var isLocal: Bool {
        self == .local
    }
}
