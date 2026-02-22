//
//  WindowConfigurator.swift
//  BookVoice
//

import SwiftUI
import AppKit

/// Скрывает текстовый заголовок окна и делает тайтл-бар прозрачным.
struct WindowTitleHider: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        TitleHiderView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private class TitleHiderView: NSView {
    private var configured = false

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window, !configured else { return }
        configured = true
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)
    }
}
