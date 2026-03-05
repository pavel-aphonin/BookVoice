//
//  ServiceContainer.swift
//  BookVoice
//

import SwiftUI

@Observable
final class ServiceContainer {
    let textProcessing: any TextProcessingService
    let llm: any LLMService
    let tts: any TTSService
    let rvc: any RVCService
    let audioEngine: any AudioEngineService
    let modelManager: any ModelManagerService
    let notification: any NotificationService

    static let shared = ServiceContainer()

    static let mock = ServiceContainer(useMocks: true)

    init(useMocks: Bool = false) {
        if useMocks {
            self.textProcessing = MockTextProcessingService()
            self.llm = MockLLMService()
            self.tts = MockTTSService()
            self.rvc = MockRVCService()
            self.audioEngine = MockAudioEngineService()
            self.modelManager = MockModelManagerService()
            self.notification = MockNotificationService()
            return
        }

        self.textProcessing = LiveTextProcessingService()
        self.llm = LiveLLMService()
        self.tts = LiveTTSService()
        self.rvc = LiveRVCService()
        self.audioEngine = LiveAudioEngineService()
        self.modelManager = LiveModelManagerService()
        self.notification = LiveNotificationService()
    }
}

extension EnvironmentValues {
    @Entry var services: ServiceContainer = .shared
}
