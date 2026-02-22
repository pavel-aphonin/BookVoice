//
//  WindowConfigurator.swift
//  BookVoice
//

import SwiftUI
import AppKit

/// Настраивает NSWindow: скрывает светофор и показывает при наведении.
struct TrafficLightAutoHide: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        TrafficLightConfigView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private class TrafficLightConfigView: NSView {
    private var configured = false

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window, !configured else { return }
        configured = true

        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true

        // Скрыть кнопки светофора
        for type: NSWindow.ButtonType in [.closeButton, .miniaturizeButton, .zoomButton] {
            window.standardWindowButton(type)?.alphaValue = 0
        }

        // Добавить трекер наведения в область заголовка
        guard let contentView = window.contentView else { return }
        let tracker = TitleBarHoverTracker(targetWindow: window)
        tracker.frame = NSRect(
            x: 0,
            y: contentView.bounds.height - 52,
            width: 80,
            height: 52
        )
        tracker.autoresizingMask = [.minYMargin]
        contentView.addSubview(tracker)
    }
}

private class TitleBarHoverTracker: NSView {
    private weak var targetWindow: NSWindow?

    init(targetWindow: NSWindow) {
        self.targetWindow = targetWindow
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError()
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil // Пропускать клики к кнопкам под трекером
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self
        ))
    }

    override func mouseEntered(with event: NSEvent) {
        animateButtons(alpha: 1, duration: 0.15)
    }

    override func mouseExited(with event: NSEvent) {
        animateButtons(alpha: 0, duration: 0.25)
    }

    private func animateButtons(alpha: CGFloat, duration: TimeInterval) {
        guard let window = targetWindow else { return }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = duration
            for type: NSWindow.ButtonType in [.closeButton, .miniaturizeButton, .zoomButton] {
                window.standardWindowButton(type)?.animator().alphaValue = alpha
            }
        }
    }
}
