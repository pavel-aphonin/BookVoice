//
//  LLMModelCatalog.swift
//  BookVoice
//
//  Каталог локальных LLM-моделей для подготовки текста.
//  13 моделей в 4 категориях RAM.
//

import Foundation
import Darwin.Mach

// MARK: - Model Definition

struct LLMModelDefinition: Identifiable, Equatable, Sendable {
    let id: String
    let displayName: String
    let parameterCount: String       // e.g. "1B", "4B", "12B"
    let repoId: String               // HuggingFace repo
    let filename: String             // GGUF filename
    let sizeGB: Double               // File size on disk
    let category: LLMModelCategory
    let languageCount: Int           // Number of supported languages
    let isMultilingual: Bool

    /// Human-readable file size
    var formattedSize: String {
        if sizeGB < 1.0 {
            return String(format: "%.0f МБ", sizeGB * 1000)
        }
        return String(format: "%.1f ГБ", sizeGB)
    }
}

// MARK: - Categories

enum LLMModelCategory: String, CaseIterable, Sendable, Comparable {
    case minimal   // ≤4 GB RAM
    case compact   // ~8 GB RAM
    case advanced  // ~16 GB RAM
    case maximum   // ≥32 GB RAM

    var displayName: String {
        switch self {
        case .minimal:  "Минимальные"
        case .compact:  "Компактные"
        case .advanced: "Продвинутые"
        case .maximum:  "Максимальные"
        }
    }

    var subtitle: String {
        switch self {
        case .minimal:  "до 4 ГБ ОЗУ"
        case .compact:  "~8 ГБ ОЗУ"
        case .advanced: "~16 ГБ ОЗУ"
        case .maximum:  "32+ ГБ ОЗУ"
        }
    }

    var icon: String {
        switch self {
        case .minimal:  "leaf"
        case .compact:  "cube"
        case .advanced: "bolt"
        case .maximum:  "flame"
        }
    }

    static func < (lhs: LLMModelCategory, rhs: LLMModelCategory) -> Bool {
        let order: [LLMModelCategory] = [.minimal, .compact, .advanced, .maximum]
        return (order.firstIndex(of: lhs) ?? 0) < (order.firstIndex(of: rhs) ?? 0)
    }
}

// MARK: - Model Catalog

enum LLMModelCatalog {

    /// All available models, grouped by category.
    static let allModels: [LLMModelDefinition] = [

        // ── Minimal ──────────────────────────────────────────

        LLMModelDefinition(
            id: "qwen3-0.6b",
            displayName: "Qwen 3 0.6B",
            parameterCount: "0.6B",
            repoId: "unsloth/Qwen3-0.6B-GGUF",
            filename: "Qwen3-0.6B-Q4_K_M.gguf",
            sizeGB: 0.5,
            category: .minimal,
            languageCount: 119,
            isMultilingual: true
        ),
        LLMModelDefinition(
            id: "gemma3-1b",
            displayName: "Gemma 3 1B",
            parameterCount: "1B",
            repoId: "bartowski/google_gemma-3-1b-it-GGUF",
            filename: "google_gemma-3-1b-it-Q4_K_M.gguf",
            sizeGB: 0.8,
            category: .minimal,
            languageCount: 35,
            isMultilingual: true
        ),
        LLMModelDefinition(
            id: "qwen3-1.7b",
            displayName: "Qwen 3 1.7B",
            parameterCount: "1.7B",
            repoId: "unsloth/Qwen3-1.7B-GGUF",
            filename: "Qwen3-1.7B-Q4_K_M.gguf",
            sizeGB: 1.2,
            category: .minimal,
            languageCount: 119,
            isMultilingual: true
        ),

        // ── Compact (8 GB RAM) ───────────────────────────────

        LLMModelDefinition(
            id: "phi4-mini",
            displayName: "Phi-4 Mini",
            parameterCount: "3.8B",
            repoId: "bartowski/phi-4-mini-instruct-GGUF",
            filename: "phi-4-mini-instruct-Q4_K_M.gguf",
            sizeGB: 2.4,
            category: .compact,
            languageCount: 20,
            isMultilingual: true
        ),
        LLMModelDefinition(
            id: "gemma3-4b",
            displayName: "Gemma 3 4B",
            parameterCount: "4B",
            repoId: "bartowski/google_gemma-3-4b-it-GGUF",
            filename: "google_gemma-3-4b-it-Q4_K_M.gguf",
            sizeGB: 2.8,
            category: .compact,
            languageCount: 35,
            isMultilingual: true
        ),
        LLMModelDefinition(
            id: "qwen3-4b",
            displayName: "Qwen 3 4B",
            parameterCount: "4B",
            repoId: "unsloth/Qwen3-4B-GGUF",
            filename: "Qwen3-4B-Q4_K_M.gguf",
            sizeGB: 2.7,
            category: .compact,
            languageCount: 119,
            isMultilingual: true
        ),

        // ── Advanced (16 GB RAM) ─────────────────────────────

        LLMModelDefinition(
            id: "qwen3-8b",
            displayName: "Qwen 3 8B",
            parameterCount: "8B",
            repoId: "unsloth/Qwen3-8B-GGUF",
            filename: "Qwen3-8B-Q4_K_M.gguf",
            sizeGB: 5.0,
            category: .advanced,
            languageCount: 119,
            isMultilingual: true
        ),
        LLMModelDefinition(
            id: "mistral-nemo-12b",
            displayName: "Mistral NeMo 12B",
            parameterCount: "12B",
            repoId: "bartowski/Mistral-Nemo-Instruct-2407-GGUF",
            filename: "Mistral-Nemo-Instruct-2407-Q4_K_M.gguf",
            sizeGB: 7.3,
            category: .advanced,
            languageCount: 12,
            isMultilingual: true
        ),
        LLMModelDefinition(
            id: "gemma3-12b",
            displayName: "Gemma 3 12B",
            parameterCount: "12B",
            repoId: "bartowski/google_gemma-3-12b-it-GGUF",
            filename: "google_gemma-3-12b-it-Q4_K_M.gguf",
            sizeGB: 7.5,
            category: .advanced,
            languageCount: 35,
            isMultilingual: true
        ),

        // ── Maximum (32+ GB RAM) ─────────────────────────────

        LLMModelDefinition(
            id: "mistral-small-24b",
            displayName: "Mistral Small 3.1 24B",
            parameterCount: "24B",
            repoId: "bartowski/Mistral-Small-3.1-24B-Instruct-2503-GGUF",
            filename: "Mistral-Small-3.1-24B-Instruct-2503-Q4_K_M.gguf",
            sizeGB: 14.5,
            category: .maximum,
            languageCount: 24,
            isMultilingual: true
        ),
        LLMModelDefinition(
            id: "gemma3-27b",
            displayName: "Gemma 3 27B",
            parameterCount: "27B",
            repoId: "bartowski/google_gemma-3-27b-it-GGUF",
            filename: "google_gemma-3-27b-it-Q4_K_M.gguf",
            sizeGB: 17.0,
            category: .maximum,
            languageCount: 35,
            isMultilingual: true
        ),
    ]

    /// Models grouped by category, sorted.
    static var groupedModels: [(category: LLMModelCategory, models: [LLMModelDefinition])] {
        let grouped = Dictionary(grouping: allModels, by: \.category)
        return LLMModelCategory.allCases
            .compactMap { cat in
                guard let models = grouped[cat], !models.isEmpty else { return nil }
                return (category: cat, models: models)
            }
    }

    /// Find a model definition by its catalog ID.
    static func model(byId id: String) -> LLMModelDefinition? {
        allModels.first { $0.id == id }
    }

    /// Find a model definition by its GGUF filename.
    static func model(byFilename filename: String) -> LLMModelDefinition? {
        allModels.first { $0.filename.lowercased() == filename.lowercased() }
    }

    // MARK: - RAM-Based Recommendation

    /// Available system memory in bytes (free + inactive via Mach VM stats).
    static var availableMemoryBytes: UInt64 {
        getAvailableMemoryBytes()
    }

    /// Available system memory in GB.
    static var availableMemoryGB: Double {
        Double(availableMemoryBytes) / 1_073_741_824
    }

    /// Recommend a model based on available RAM.
    /// Model file should not exceed ~60% of free RAM for comfortable inference.
    static func recommendedModel() -> LLMModelDefinition {
        let freeGB = availableMemoryGB
        let maxModelSize = freeGB * 0.6

        if maxModelSize >= 17.0 {
            return allModels.first { $0.id == "gemma3-27b" }!
        } else if maxModelSize >= 7.5 {
            return allModels.first { $0.id == "gemma3-12b" }!
        } else if maxModelSize >= 5.0 {
            return allModels.first { $0.id == "qwen3-8b" }!
        } else if maxModelSize >= 2.8 {
            return allModels.first { $0.id == "gemma3-4b" }!
        } else if maxModelSize >= 1.2 {
            return allModels.first { $0.id == "qwen3-1.7b" }!
        } else {
            return allModels.first { $0.id == "qwen3-0.6b" }!
        }
    }

    /// Check which category the user can comfortably run.
    static func maxComfortableCategory() -> LLMModelCategory {
        let freeGB = availableMemoryGB
        if freeGB >= 24 { return .maximum }
        if freeGB >= 12 { return .advanced }
        if freeGB >= 6 { return .compact }
        return .minimal
    }

    // MARK: - Default Inference Parameters

    /// Default inference parameters optimized for text preprocessing.
    static let defaultTemperature: Double = 0.2
    static let defaultTopP: Double = 0.9
    static let defaultTopK: Int = 20
    static let defaultRepeatPenalty: Double = 1.1
    static let defaultMaxTokens: Int = 512
}

// MARK: - Available Memory

/// Returns the available (free + inactive) memory in bytes using Mach VM statistics.
private func getAvailableMemoryBytes() -> UInt64 {
    var stats = vm_statistics64()
    var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)

    let result = withUnsafeMutablePointer(to: &stats) { statsPtr in
        statsPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { ptr in
            host_statistics64(mach_host_self(), HOST_VM_INFO64, ptr, &count)
        }
    }

    guard result == KERN_SUCCESS else {
        // Fallback: use total physical memory as rough estimate
        return ProcessInfo.processInfo.physicalMemory
    }

    let pageSize = UInt64(vm_kernel_page_size)
    let free = UInt64(stats.free_count) * pageSize
    let inactive = UInt64(stats.inactive_count) * pageSize
    return free + inactive
}
