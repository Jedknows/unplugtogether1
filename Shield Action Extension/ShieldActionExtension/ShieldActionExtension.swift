import ManagedSettings
import ManagedSettingsUI
import Foundation
import UserNotifications

/// Handles button taps on the shield (blocking) screen.
/// When a user taps "Ask Partner for More Time", this extension
/// writes a flag to shared storage that the main app reads to
/// trigger the CloudKit approval flow.

@main
class ShieldActionExtension: ShieldActionDelegate {

    static func main() {}

    private let appGroupId = "group.com.unplugtogether.shared"

    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupId)
    }

    // Handle the primary button ("Ask Partner for More Time")
    override func handle(
        action: ShieldAction,
        for application: ApplicationToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        switch action {
        case .primaryButtonPressed:
            // Write a flag so the main app sends an approval request via CloudKit
            sharedDefaults?.set(Date().timeIntervalSince1970, forKey: "shieldApprovalRequested")
            sharedDefaults?.set(true, forKey: "needsApprovalFromShield")

            // Schedule a notification to prompt opening the main app
            let content = UNMutableNotificationContent()
            content.title = "Approval Requested"
            content.body = "Open Unplug Together to send the request to your partner."
            content.sound = .default

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(
                identifier: "shieldApproval_\(Date().timeIntervalSince1970)",
                content: content,
                trigger: trigger
            )
            UNUserNotificationCenter.current().add(request)

            // Don't dismiss the shield — keep app blocked until partner responds
            completionHandler(.defer)

        case .secondaryButtonPressed:
            // "Close app" — dismiss the shield and close the app
            completionHandler(.close)

        @unknown default:
            completionHandler(.close)
        }
    }

    // Handle shield actions for web domains
    override func handle(
        action: ShieldAction,
        for webDomain: WebDomainToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        switch action {
        case .primaryButtonPressed:
            sharedDefaults?.set(true, forKey: "needsApprovalFromShield")
            completionHandler(.defer)
        case .secondaryButtonPressed:
            completionHandler(.close)
        @unknown default:
            completionHandler(.close)
        }
    }

    // Handle shield actions for app categories
    override func handle(
        action: ShieldAction,
        for category: ActivityCategoryToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        switch action {
        case .primaryButtonPressed:
            sharedDefaults?.set(true, forKey: "needsApprovalFromShield")
            completionHandler(.defer)
        case .secondaryButtonPressed:
            completionHandler(.close)
        @unknown default:
            completionHandler(.close)
        }
    }
}
