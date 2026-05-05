import Foundation
import FamilyControls
import DeviceActivity
import ManagedSettings
import Combine

/// Manages all Screen Time API interactions:
/// - Authorization (FamilyControls)
/// - Monitoring schedules (DeviceActivity)
/// - Blocking/shielding apps (ManagedSettings)
@MainActor
class ScreenTimeManager: ObservableObject {

    static let shared = ScreenTimeManager()

    // MARK: - Published State
    @Published var isAuthorized = false
    @Published var authorizationError: String?
    @Published var selectedApps = FamilyActivitySelection()
    @Published var isMonitoring = false

    // MARK: - Private
    private let authCenter = AuthorizationCenter.shared
    private let store = ManagedSettingsStore()
    private let deviceActivityCenter = DeviceActivityCenter()

    // App Group suite for sharing data with extensions
    private let appGroupId = "group.com.unplugtogether.shared"
    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupId)
    }

    private init() {
        // Check existing authorization
        checkAuthorization()
        // Restore saved app selection
        loadSavedSelection()
    }

    // MARK: - Persist FamilyActivitySelection

    /// Save FamilyActivitySelection to App Group so extensions can use it
    func saveSelection(_ selection: FamilyActivitySelection) {
        selectedApps = selection
        guard let defaults = sharedDefaults else { return }
        do {
            let data = try PropertyListEncoder().encode(selection)
            defaults.set(data, forKey: "familyActivitySelection")
            print("[ScreenTime] Saved FamilyActivitySelection (\(selection.applicationTokens.count) apps, \(selection.categoryTokens.count) categories)")
        } catch {
            print("[ScreenTime] Failed to save selection: \(error)")
        }
    }

    /// Load FamilyActivitySelection from App Group
    private func loadSavedSelection() {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: "familyActivitySelection") else { return }
        do {
            let selection = try PropertyListDecoder().decode(FamilyActivitySelection.self, from: data)
            selectedApps = selection
            print("[ScreenTime] Restored FamilyActivitySelection (\(selection.applicationTokens.count) apps)")
        } catch {
            print("[ScreenTime] Failed to load selection: \(error)")
        }
    }

    /// Static helper for extensions to load the selection (non-MainActor)
    static func loadSelectionFromAppGroup() -> FamilyActivitySelection? {
        guard let defaults = UserDefaults(suiteName: "group.com.unplugtogether.shared"),
              let data = defaults.data(forKey: "familyActivitySelection") else { return nil }
        return try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data)
    }

    // MARK: - Authorization

    /// Request Screen Time authorization from the user
    /// This presents the system dialog asking for Family Controls permission
    func requestAuthorization() async {
        do {
            // .individual = personal device (not parent/child)
            try await authCenter.requestAuthorization(for: .individual)
            isAuthorized = true
            authorizationError = nil
            print("[ScreenTime] Authorization granted")
        } catch {
            isAuthorized = false
            authorizationError = error.localizedDescription
            print("[ScreenTime] Authorization failed: \(error)")
        }
    }

    /// Check if we already have authorization
    func checkAuthorization() {
        switch authCenter.authorizationStatus {
        case .approved:
            isAuthorized = true
        case .denied, .notDetermined:
            isAuthorized = false
        @unknown default:
            isAuthorized = false
        }
    }

    // MARK: - App Selection

    /// Save the user's selected apps and their limits to shared storage
    func saveAppLimits(_ limits: [AppLimitConfig]) {
        guard let defaults = sharedDefaults else { return }
        if let data = try? JSONEncoder().encode(limits) {
            defaults.set(data, forKey: "appLimits")
        }
        print("[ScreenTime] Saved \(limits.count) app limits to shared storage")
    }

    /// Load app limits from shared storage
    func loadAppLimits() -> [AppLimitConfig] {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: "appLimits"),
              let limits = try? JSONDecoder().decode([AppLimitConfig].self, from: data) else {
            return []
        }
        return limits
    }

    // MARK: - Monitoring (DeviceActivity)

    /// Start monitoring screen time for all configured apps
    /// The DeviceActivityMonitor extension will fire events when limits are hit
    func startMonitoring(limits: [AppLimitConfig]) {
        guard isAuthorized else {
            print("[ScreenTime] Cannot monitor — not authorized")
            return
        }

        // Ensure we have a saved selection
        if selectedApps.applicationTokens.isEmpty && selectedApps.categoryTokens.isEmpty {
            loadSavedSelection()
        }

        // Save limits so the extension can read them
        saveAppLimits(limits)

        // Create a daily monitoring schedule: midnight to midnight
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let startComponents = calendar.dateComponents([.hour, .minute, .second], from: startOfDay)
        let endComponents = DateComponents(hour: 23, minute: 59, second: 59)

        let schedule = DeviceActivitySchedule(
            intervalStart: startComponents,
            intervalEnd: endComponents,
            repeats: true  // Repeats daily
        )

        // Build per-app activity events (thresholds)
        // When usage crosses the threshold, DeviceActivityMonitor fires
        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]

        // Find the max limit to determine how many usage checkpoints we need
        let maxLimit = limits.map { $0.dailyLimitMinutes }.max() ?? 60

        // Add usage tracking checkpoints every 5 minutes up to the max limit
        // The DeviceActivityMonitor extension writes the reached checkpoint to shared storage
        // so the main app can read approximate usage
        let checkpointInterval = 5
        for minutes in stride(from: checkpointInterval, through: maxLimit, by: checkpointInterval) {
            let eventName = DeviceActivityEvent.Name("usage_\(minutes)")
            let threshold = DateComponents(minute: minutes)
            let event = DeviceActivityEvent(
                applications: selectedApps.applicationTokens,
                categories: selectedApps.categoryTokens,
                webDomains: selectedApps.webDomainTokens,
                threshold: threshold
            )
            events[eventName] = event
        }

        for limit in limits {
            // Create an event that fires when the app hits its limit
            let eventName = DeviceActivityEvent.Name("limit_\(limit.bundleIdentifier)")
            let threshold = DateComponents(minute: limit.dailyLimitMinutes)

            // Use the FamilyActivitySelection to target specific apps
            let event = DeviceActivityEvent(
                applications: selectedApps.applicationTokens,
                categories: selectedApps.categoryTokens,
                webDomains: selectedApps.webDomainTokens,
                threshold: threshold
            )
            events[eventName] = event
        }

        // Also add warning events at 80% of limit
        for limit in limits {
            let warningMinutes = Int(Double(limit.dailyLimitMinutes) * 0.8)
            let warningName = DeviceActivityEvent.Name("warning_\(limit.bundleIdentifier)")
            let warningThreshold = DateComponents(minute: warningMinutes)

            let warningEvent = DeviceActivityEvent(
                applications: selectedApps.applicationTokens,
                categories: selectedApps.categoryTokens,
                webDomains: selectedApps.webDomainTokens,
                threshold: warningThreshold
            )
            events[warningName] = warningEvent
        }

        do {
            let activityName = DeviceActivityName("daily_screen_time")

            // Stop any existing monitoring first
            deviceActivityCenter.stopMonitoring([activityName])

            // Start fresh monitoring
            try deviceActivityCenter.startMonitoring(
                activityName,
                during: schedule,
                events: events
            )
            isMonitoring = true
            print("[ScreenTime] Started monitoring with \(events.count) events")
        } catch {
            print("[ScreenTime] Failed to start monitoring: \(error)")
            isMonitoring = false
        }
    }

    /// Stop all monitoring
    func stopMonitoring() {
        deviceActivityCenter.stopMonitoring()
        isMonitoring = false
        print("[ScreenTime] Stopped all monitoring")
    }

    // MARK: - App Blocking (ManagedSettings)

    /// Block (shield) specified apps — called when a limit is hit and partner denies approval
    func blockApps() {
        // Ensure we have the selection loaded
        if selectedApps.applicationTokens.isEmpty && selectedApps.categoryTokens.isEmpty {
            loadSavedSelection()
        }

        store.shield.applications = selectedApps.applicationTokens.isEmpty ? nil : selectedApps.applicationTokens
        store.shield.applicationCategories = selectedApps.categoryTokens.isEmpty
            ? nil
            : ShieldSettings.ActivityCategoryPolicy.specific(selectedApps.categoryTokens)
        store.shield.webDomains = selectedApps.webDomainTokens.isEmpty ? nil : selectedApps.webDomainTokens

        // Also save block state to shared storage for extensions
        sharedDefaults?.set(true, forKey: "appsCurrentlyBlocked")

        print("[ScreenTime] Apps blocked/shielded")
    }

    /// Block a specific set of apps by their tokens
    func blockSpecificApps(applicationTokens: Set<ApplicationToken>) {
        store.shield.applications = applicationTokens
        print("[ScreenTime] Blocked \(applicationTokens.count) specific apps")
    }

    /// Unblock all apps — called when partner approves more time, or new day starts
    func unblockAllApps() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
        sharedDefaults?.set(false, forKey: "appsCurrentlyBlocked")
        sharedDefaults?.removeObject(forKey: "pendingApprovalApp")
        sharedDefaults?.removeObject(forKey: "needsApprovalFromShield")
        print("[ScreenTime] All apps unblocked")
    }

    /// Grant temporary extension (partner approved more time)
    func grantExtension(minutes: Int, forApp bundleId: String) {
        guard let defaults = sharedDefaults else { return }

        // Store the extension so the DeviceActivityMonitor knows about it
        var extensions = loadExtensions()
        extensions[bundleId] = (extensions[bundleId] ?? 0) + minutes
        if let data = try? JSONEncoder().encode(extensions) {
            defaults.set(data, forKey: "timeExtensions")
        }

        // Unblock the app
        unblockAllApps()

        // Restart monitoring with extended limits
        var limits = loadAppLimits()
        if let idx = limits.firstIndex(where: { $0.bundleIdentifier == bundleId }) {
            limits[idx].dailyLimitMinutes += minutes
            saveAppLimits(limits)
            startMonitoring(limits: limits)
        }

        print("[ScreenTime] Granted \(minutes)m extension for \(bundleId)")
    }

    /// Load any time extensions granted today
    func loadExtensions() -> [String: Int] {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: "timeExtensions"),
              let ext = try? JSONDecoder().decode([String: Int].self, from: data) else {
            return [:]
        }
        return ext
    }

    /// Reset extensions at start of new day
    func resetDailyExtensions() {
        sharedDefaults?.removeObject(forKey: "timeExtensions")
        print("[ScreenTime] Daily extensions reset")
    }

    // MARK: - Usage Reporting

    /// Read the current usage minutes from shared storage (written by DeviceActivityMonitor extension)
    /// The extension writes the highest checkpoint reached, giving us ~5-minute accuracy
    func readCurrentUsageMinutes() -> Int {
        guard let defaults = sharedDefaults else { return 0 }
        let dateKey = ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: Date()))
        return defaults.integer(forKey: "currentUsageMinutes_\(dateKey)")
    }

    /// Save current usage data to shared storage (called periodically)
    func saveUsageData(appBundleId: String, minutesUsed: Int, partnerId: String) {
        guard let defaults = sharedDefaults else { return }

        let dateKey = ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: Date()))
        let key = "usage_\(dateKey)_\(partnerId)_\(appBundleId)"
        defaults.set(minutesUsed, forKey: key)
    }

    /// Read usage for a specific app/partner/day
    func getUsage(appBundleId: String, partnerId: String, date: Date = Date()) -> Int {
        guard let defaults = sharedDefaults else { return 0 }

        let dateKey = ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: date))
        let key = "usage_\(dateKey)_\(partnerId)_\(appBundleId)"
        return defaults.integer(forKey: key)
    }
}
