//
//  MockNotificationService.swift
//  BookVoice
//

import Foundation

final class MockNotificationService: NotificationService, @unchecked Sendable {
    func requestPermission() async -> Bool { true }
    func send(title: String, body: String) async {}
}
