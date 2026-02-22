//
//  AudioPlayerBar.swift
//  BookVoice
//

import SwiftUI

struct AudioPlayerBar: View {
    var title: String
    var isPlaying: Bool
    var currentTime: Double
    var duration: Double
    var onPlayPause: () -> Void
    var onStop: () -> Void
    var onSeek: (Double) -> Void

    private var progress: Double {
        guard duration > 0 else { return 0 }
        return currentTime / duration
    }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onPlayPause) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.body)
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)

            Button(action: onStop) {
                Image(systemName: "stop.fill")
                    .font(.caption)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)

            Text(title)
                .font(.caption)
                .lineLimit(1)
                .frame(maxWidth: 120)

            Slider(
                value: Binding(
                    get: { progress },
                    set: { newValue in onSeek(newValue * duration) }
                ),
                in: 0...1
            )
            .tint(.accentColor)

            Text(formatTime(currentTime))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)

            Text("/")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Text(formatTime(duration))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: .rect)
    }

    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

#Preview {
    VStack {
        Spacer()
        AudioPlayerBar(
            title: "Сегмент 3",
            isPlaying: true,
            currentTime: 45,
            duration: 120,
            onPlayPause: {},
            onStop: {},
            onSeek: { _ in }
        )
    }
    .frame(width: 600, height: 300)
    .background(
        LinearGradient(
            colors: [.blue, .purple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )
}
