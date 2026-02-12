import Foundation
import UserNotifications

final class NotificationManager {
    enum Tone {
        case success
        case failure
        case none
    }

    func requestPermission() {
        guard Bundle.main.bundleIdentifier != nil else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func send(title: String, subtitle: String, message: String, tone: Tone) {
        guard Bundle.main.bundleIdentifier != nil else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.subtitle = subtitle
        content.body = message
        content.sound = sound(for: tone)

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    private func sound(for tone: Tone) -> UNNotificationSound? {
        switch tone {
        case .success:
            return UNNotificationSound(named: UNNotificationSoundName("Purr.aiff"))
        case .failure:
            return UNNotificationSound(named: UNNotificationSoundName("Basso.aiff"))
        case .none:
            return nil
        }
    }
}
