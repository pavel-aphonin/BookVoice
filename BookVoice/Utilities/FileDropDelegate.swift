//
//  FileDropDelegate.swift
//  BookVoice
//

import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let epub = UTType(filenameExtension: "epub") ?? .data
}
