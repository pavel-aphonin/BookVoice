//
//  AudioPlayerViewModel.swift
//  BookVoice
//

import Foundation

@Observable
final class AudioPlayerViewModel {
    var isPlaying = false
    var currentTime: Double = 0
    var duration: Double = 0
    var currentTitle: String = ""
    var isVisible = false

    private var audioEngine: any AudioEngineService
    private var timerTask: Task<Void, Never>?

    init(audioEngine: any AudioEngineService) {
        self.audioEngine = audioEngine
    }

    func play(url: URL, title: String) async {
        do {
            currentTitle = title
            try await audioEngine.play(url: url)
            duration = await audioEngine.duration
            isPlaying = true
            isVisible = true
            startTimer()
        } catch {
            AppLogger.shared.error("Playback failed: \(error.localizedDescription)")
        }
    }

    func togglePlayPause() async {
        if isPlaying {
            await audioEngine.pause()
            isPlaying = false
            timerTask?.cancel()
        } else {
            // Resume would need the URL again; simplified for mock
            isPlaying = true
            startTimer()
        }
    }

    func stop() async {
        await audioEngine.stop()
        isPlaying = false
        currentTime = 0
        isVisible = false
        timerTask?.cancel()
    }

    func seek(to time: Double) {
        currentTime = time
    }

    private func startTimer() {
        timerTask?.cancel()
        timerTask = Task {
            while !Task.isCancelled && isPlaying {
                try? await Task.sleep(for: .milliseconds(100))
                if isPlaying {
                    currentTime = await audioEngine.currentTime
                }
            }
        }
    }
}
