//
//  LiveNotificationService.swift
//  BookVoice
//

import Foundation
import UserNotifications

final class LiveNotificationService: NotificationService, @unchecked Sendable {
    private var permissionGranted = false

    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            permissionGranted = try await center.requestAuthorization(options: [.alert, .sound])
            return permissionGranted
        } catch {
            return false
        }
    }

    func send(title: String, body: String) async {
        if !permissionGranted {
            let granted = await requestPermission()
            guard granted else { return }
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        try? await UNUserNotificationCenter.current().add(request)
    }
}
