import DeviceActivity
import ManagedSettings
import FamilyControls
import Foundation
import UserNotifications

/// This extension runs in the BACKGROUND and fires when screen time thresholds are hit.
/// It's the core engine that enforces limits — even when the main app isn't open.
///
/// When a user's screen time for a monitored app crosses the configured threshold:
/// 1. The `eventDidReachThreshold` method fires
/// 2. We shield (block) the app using ManagedSettingsStore
/// 3. We write a flag to shared App Group storage
/// 4. The main app reads this flag and sends an approval request to the partner via CloudKit
///
/// When the partner approves/denies (handled in main app):
/// - Approved: main app calls ScreenTimeManager.grantExtension() → removes shield, restarts with higher threshold
/// - Denied: shield stays, garden grows

@main
class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    static func main() {}

    private let store = ManagedSettingsStore()
    private let appGroupId = "group.com.unplugtogether.shared"

    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupId)
    }

    // MARK: - Schedule Callbacks

    /// Called when the daily monitoring interval starts (midnight)
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)

        // Reset daily state
        sharedDefaults?.removeObject(forKey: "timeExtensions")
        sharedDefaults?.removeObject(forKey: "blockedApps")
        sharedDefaults?.removeObject(forKey: "pendingApprovalApp")
        sharedDefaults?.removeObject(forKey: "needsApprovalFromShield")
        sharedDefaults?.set(false, forKey: "appsCurrentlyBlocked")

        // Clear any blocks from yesterday
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil

        print("[Monitor] Daily interval started — reset all blocks")
    }

    /// Called when the daily monitoring interval ends (11:59 PM)
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)

        // Record end-of-day results
        recordDayResults()

        // Clear shields
        store.shield.applications = nil
        store.shield.applicationCategories = nil

        print("[Monitor] Daily interval ended")
    }

    // MARK: - Threshold Events

    /// CRITICAL: Called when usage reaches a configured threshold
    /// This is where we block the app and trigger the approval flow
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)

        let eventName = event.rawValue

        if eventName.hasPrefix("warning_") {
            // 80% warning — notify but don't block
            handleWarning(eventName: eventName)
        } else if eventName.hasPrefix("limit_") {
            // Full limit reached — block the app!
            handleLimitReached(eventName: eventName)
        }
    }

    /// Called when usage drops below a threshold (e.g., new day)
    override func eventWillReachThresholdWarning(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventWillReachThresholdWarning(event, activity: activity)
        // Can be used for pre-warning at 5 min before limit
    }

    // MARK: - Warning Handler (80% of limit)

    private func handleWarning(eventName: String) {
        let bundleId = String(eventName.dropFirst("warning_".count))

        // Write warning flag for main app to read
        sharedDefaults?.set(true, forKey: "warning_\(bundleId)")
        sharedDefaults?.set(Date().timeIntervalSince1970, forKey: "warningTime_\(bundleId)")

        // Schedule a local notification
        let limits = loadAppLimits()
        let appName = limits.first { $0.bundleIdentifier == bundleId }?.appName ?? "an app"
        let limit = limits.first { $0.bundleIdentifier == bundleId }?.dailyLimitMinutes ?? 0
        let remaining = limit - Int(Double(limit) * 0.8)

        scheduleNotification(
            title: "Almost at your \(appName) limit",
            body: "\(remaining) minutes remaining. Your partner will be asked to approve if you go over.",
            identifier: "warning_\(bundleId)"
        )

        print("[Monitor] Warning threshold hit for \(bundleId)")
    }

    // MARK: - Limit Handler (100% — BLOCK!)

    private func handleLimitReached(eventName: String) {
        let bundleId = String(eventName.dropFirst("limit_".count))

        // Check if there's an active extension (partner already approved extra time)
        let extensions = loadExtensions()
        if let ext = extensions[bundleId], ext > 0 {
            // Extension exists — don't block yet, the monitoring should have been
            // restarted with the higher threshold. If we get here, the extension
            // has also been exceeded.
            print("[Monitor] Extension expired for \(bundleId)")
        }

        // BLOCK THE APP using ManagedSettings shield with saved FamilyActivitySelection tokens
        let selection = loadSavedSelection()
        if let appTokens = selection?.applicationTokens, !appTokens.isEmpty {
            store.shield.applications = appTokens
        }
        if let catTokens = selection?.categoryTokens, !catTokens.isEmpty {
            store.shield.applicationCategories = ShieldSettings.ActivityCategoryPolicy.specific(catTokens)
        }
        if let webTokens = selection?.webDomainTokens, !webTokens.isEmpty {
            store.shield.webDomains = webTokens
        }

        // Write block flag for main app to handle
        var blockedApps = sharedDefaults?.stringArray(forKey: "blockedApps") ?? []
        if !blockedApps.contains(bundleId) {
            blockedApps.append(bundleId)
        }
        sharedDefaults?.set(blockedApps, forKey: "blockedApps")
        sharedDefaults?.set(Date().timeIntervalSince1970, forKey: "blockTime_\(bundleId)")
        sharedDefaults?.set(true, forKey: "appsCurrentlyBlocked")

        // Flag that an approval is needed — main app reads this on foreground
        sharedDefaults?.set(bundleId, forKey: "pendingApprovalApp")
        sharedDefaults?.set(Date().timeIntervalSince1970, forKey: "pendingApprovalTime")
        sharedDefaults?.set(true, forKey: "needsApprovalFromShield")

        // Notify the user that they're blocked
        let limits = loadAppLimits()
        let appName = limits.first { $0.bundleIdentifier == bundleId }?.appName ?? "an app"

        scheduleNotification(
            title: "\(appName) limit reached!",
            body: "Your partner needs to approve more time. Put the phone down and grow your garden! 🌱",
            identifier: "block_\(bundleId)"
        )

        print("[Monitor] LIMIT REACHED — blocked \(bundleId) with \(selection?.applicationTokens.count ?? 0) app tokens")
    }

    // MARK: - End of Day

    private func recordDayResults() {
        let blockedApps = sharedDefaults?.stringArray(forKey: "blockedApps") ?? []
        let extensionUsed = sharedDefaults?.bool(forKey: "extensionUsedToday") ?? false

        // If no apps were blocked today and no extensions were used, it's a successful day
        let success = blockedApps.isEmpty && !extensionUsed

        let dateKey = ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: Date()))
        sharedDefaults?.set(success, forKey: "dayResult_\(dateKey)")

        // Note: The authoritative streak is managed by AppViewModel and synced to CloudKit.
        // This extension only records the day result flag and sends a notification.
        if success {
            scheduleNotification(
                title: "Great day!",
                body: "You both stayed under your limits! Your garden is growing.",
                identifier: "daySuccess"
            )
        } else {
            scheduleNotification(
                title: "Streak broken",
                body: "One of you went over today. Tomorrow is a new day — try again together!",
                identifier: "dayFail"
            )
        }
    }

    // MARK: - Helpers

    private func loadAppLimits() -> [AppLimitConfig] {
        guard let data = sharedDefaults?.data(forKey: "appLimits"),
              let limits = try? JSONDecoder().decode([AppLimitConfig].self, from: data) else {
            return []
        }
        return limits
    }

    private func loadExtensions() -> [String: Int] {
        guard let data = sharedDefaults?.data(forKey: "timeExtensions"),
              let ext = try? JSONDecoder().decode([String: Int].self, from: data) else {
            return [:]
        }
        return ext
    }

    /// Load the FamilyActivitySelection saved by the main app
    private func loadSavedSelection() -> FamilyActivitySelection? {
        guard let data = sharedDefaults?.data(forKey: "familyActivitySelection") else { return nil }
        return try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data)
    }

    private func scheduleNotification(title: String, body: String, identifier: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[Monitor] Notification error: \(error)")
            }
        }
    }
}
