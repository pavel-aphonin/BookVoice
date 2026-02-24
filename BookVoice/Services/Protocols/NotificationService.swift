//
//  NotificationService.swift
//  BookVoice
//

import Foundation

protocol NotificationService: Sendable {
    func requestPermission() async -> Bool
    func send(title: String, body: String) async
}
