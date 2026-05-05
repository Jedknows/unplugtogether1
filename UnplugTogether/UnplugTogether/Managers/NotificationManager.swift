import Foundation
import UserNotifications
import UIKit
import Combine

/// Manages local and remote push notifications for approval requests
@MainActor
class NotificationManager: ObservableObject {

    static let shared = NotificationManager()

    @Published var isAuthorized = false

    private init() {}

    /// Request notification permissions
    func requestAuthorization() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound, .criticalAlert])
            isAuthorized = granted
            if granted {
                // Register for remote notifications (APNs → CloudKit)
                UIApplication.shared.registerForRemoteNotifications()
            }
            print("[Notifications] Authorization: \(granted)")
        } catch {
            print("[Notifications] Auth error: \(error)")
        }
    }

    /// Schedule a local notification (e.g., approaching limit warning)
    func scheduleWarning(appName: String, minutesRemaining: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Almost at your limit!"
        content.body = "You have \(minutesRemaining) minutes left on \(appName). Your partner will be notified soon."
        content.sound = .default
        content.categoryIdentifier = "LIMIT_WARNING"

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "warning_\(appName)_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    /// Show approval request notification
    func showApprovalRequest(from partnerName: String, appName: String, requestId: String, appBundleId: String = "") {
        let content = UNMutableNotificationContent()
        content.title = "\(partnerName) needs your approval"
        content.body = "\(partnerName) wants your approval for more time on \(appName)."
        content.sound = .defaultCritical
        content.categoryIdentifier = "APPROVAL_REQUEST"
        content.userInfo = ["requestId": requestId, "appName": appName, "appBundleId": appBundleId]

        // Add action buttons directly in the notification
        let approveAction = UNNotificationAction(
            identifier: "APPROVE",
            title: "Allow 15 min",
            options: []
        )
        let denyAction = UNNotificationAction(
            identifier: "DENY",
            title: "Deny (Grow Garden!)",
            options: [.destructive]
        )
        let category = UNNotificationCategory(
            identifier: "APPROVAL_REQUEST",
            actions: [approveAction, denyAction],
            intentIdentifiers: [],
            options: .customDismissAction
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "approval_\(requestId)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    /// Show celebration notification when garden grows
    func showGardenGrowth(plantName: String, streak: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Your garden grew!"
        content.body = "A new \(plantName) sprouted! \(streak) day streak together."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "garden_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    /// Show notification when a new plant type is unlocked via streak milestone
    func showUnlockNotification(plantName: String) {
        let content = UNMutableNotificationContent()
        content.title = "New plant unlocked!"
        content.body = "You unlocked the \(plantName)! Keep growing your streak."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "unlock_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    /// Notify the user that a plant has died from too much weathering
    func showPlantDeathNotification(plantName: String) {
        let content = UNMutableNotificationContent()
        content.title = "A plant has withered away..."
        content.body = "Your \(plantName) couldn't survive all the screen time extensions. Take care of your garden!"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "plantDeath_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }
}
