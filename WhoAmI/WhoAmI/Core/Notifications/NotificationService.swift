import Foundation
import UserNotifications

/// Local-notification scaffold. The real "your gist is ready" push is delivered server-side
/// (an Edge Function → APNs), which requires the Push Notifications capability + an Apple
/// Developer account; that is out of scope for the local build. This covers authorization
/// and local delivery so the surface exists.
protocol NotificationService: Sendable {
    func requestAuthorization() async
    func notifyGistReady(prompt: String) async
}

final class LocalNotificationService: NotificationService {
    func requestAuthorization() async {
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])
    }

    func notifyGistReady(prompt: String) async {
        let content = UNMutableNotificationContent()
        content.title = "Your gist is ready 👀"
        content.body = "“\(prompt)” just graduated."
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }
}
