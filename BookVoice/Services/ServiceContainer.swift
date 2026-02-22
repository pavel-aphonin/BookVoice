//
//  ServiceContainer.swift
//  BookVoice
//

import SwiftUI

@Observable
final class ServiceContainer {
    let textProcessing: any TextProcessingService
    let tts: any TTSService
    let rvc: any RVCService
    let audioEngine: any AudioEngineService
    let modelManager: any ModelManagerService

    static let shared = ServiceContainer()

    static let mock = ServiceContainer(useMocks: true)

    init(useMocks: Bool = false) {
        if useMocks {
            self.textProcessing = MockTextProcessingService()
            self.tts = MockTTSService()
            self.rvc = MockRVCService()
            self.audioEngine = MockAudioEngineService()
            self.modelManager = MockModelManagerService()
            return
        }

        // For now, use mocks everywhere until live implementations are ready
        self.textProcessing = MockTextProcessingService()
        self.tts = MockTTSService()
        self.rvc = MockRVCService()
        self.audioEngine = MockAudioEngineService()
        self.modelManager = MockModelManagerService()
    }
}

extension EnvironmentValues {
    @Entry var services: ServiceContainer = .shared
}
