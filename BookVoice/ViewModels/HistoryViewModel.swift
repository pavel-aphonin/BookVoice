//
//  HistoryViewModel.swift
//  BookVoice
//

import Foundation

@Observable
final class HistoryViewModel {
    var searchText: String = ""
    var selectedStatus: ProjectStatus?

    func filteredProjects(_ projects: [VoiceoverProject]) -> [VoiceoverProject] {
        var result = projects

        if !searchText.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.author.localizedCaseInsensitiveContains(searchText)
            }
        }

        if let status = selectedStatus {
            result = result.filter { $0.status == status }
        }

        return result
    }
}
