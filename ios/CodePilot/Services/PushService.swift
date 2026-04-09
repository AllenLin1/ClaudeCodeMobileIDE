import Foundation
import UserNotifications

@MainActor
final class PushService: ObservableObject {
    @Published var isRegistered = false
    @Published var deviceToken: String?

    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            if granted {
                // In production, register for remote notifications:
                // await UIApplication.shared.registerForRemoteNotifications()
                isRegistered = true
            }
            return granted
        } catch {
            return false
        }
    }

    func handleDeviceToken(_ token: Data) {
        let tokenString = token.map { String(format: "%02x", $0) }.joined()
        deviceToken = tokenString
        isRegistered = true
    }
}
