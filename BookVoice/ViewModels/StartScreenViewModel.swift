//
//  StartScreenViewModel.swift
//  BookVoice
//

import Foundation
import SwiftData

@Observable
final class StartScreenViewModel {
    var showDeleteConfirmation = false
    var projectToDelete: VoiceoverProject?

    func createNewProject(in context: ModelContext) -> VoiceoverProject {
        let project = VoiceoverProject(title: "Untitled Project")
        context.insert(project)
        AppLogger.shared.info("Created new project: \(project.id)")
        return project
    }

    func confirmDelete(_ project: VoiceoverProject) {
        projectToDelete = project
        showDeleteConfirmation = true
    }

    func deleteProject(in context: ModelContext) {
        guard let project = projectToDelete else { return }
        AppLogger.shared.info("Deleting project: \(project.title)")
        context.delete(project)
        projectToDelete = nil
    }
}
