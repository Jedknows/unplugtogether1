import Foundation
import FamilyControls
import Combine
import SwiftUI
import CloudKit

/// Central ViewModel that coordinates between ScreenTime, CloudKit, and the UI
@MainActor
class AppViewModel: ObservableObject {

    // MARK: - State
    enum AppState {
        case setup              // First launch — enter your name
        case avatarPicker       // Choose your avatar character
        case pairing            // Create or join couple
        case waitingForPartner  // Creator waits for partner to join (cute screen)
        case pickMyLimits       // Each user picks their OWN limits independently
        case waitingForBothLimits // Wait until both partners have submitted limits
        case reviewPartnerLimits  // Review partner's limits — confirm or suggest changes
        case home               // Main dashboard
    }

    @Published var state: AppState = .setup
    @Published var myName = ""
    @Published var partnerName = "Partner"  // Filled from CloudKit when partner joins
    @Published var appLimits: [AppLimitConfig] = []       // MY limits used for monitoring
    @Published var isCreator = false                        // Whether this user created the couple
    @Published var checkInFrequency: CheckInFrequency = .weekly
    @Published var myLimitsSubmitted = false                // Whether I've submitted my limits during setup
    @Published var partnerLimitsSubmitted = false            // Whether partner has submitted their limits
    @Published var iConfirmedPartner = false                 // Whether I confirmed partner's limits
    @Published var partnerConfirmedMe = false                // Whether partner confirmed my limits
    @Published var myUsage: [String: Int] = [:]      // bundleId: minutes
    @Published var partnerUsage: [String: Int] = [:]
    @Published var streak = 0
    @Published var gardenPlants: [GardenPlant] = []   // completed plants
    @Published var activePlant: GardenPlant?            // currently growing (only one at a time)
    @Published var dayHistory: [DayResult] = []
    @Published var showApprovalModal = false
    @Published var currentApproval: ApprovalRequest?
    @Published var pairingCode = ""
    @Published var isPaired = false
    @Published var isLoading = false
    @Published var selectedTab: Tab = .home
    @Published var showPlantShop = false
    @Published var deepLinkCode: String?  // Auto-filled from URL scheme
    @Published var extensionUsedToday = false  // True if extra time was approved today — breaks streak
    @Published var errorMessage: String?  // User-facing error (shown as alert)
    var suppressErrors = false             // Suppress error alerts during retries
    @Published var myAvatarId: String = "avatar_01"      // My selected avatar
    @Published var partnerAvatarId: String = "avatar_02"  // Partner's avatar (from CloudKit)

    // Limit change proposal
    @Published var pendingLimitProposal: LimitProposal?
    @Published var showLimitProposal = false

    // Per-partner limits & suggestions
    @Published var partnerLimits: [AppLimitConfig] = []
    @Published var pendingLimitSuggestion: LimitSuggestion? = nil
    @Published var unlockedPlantTypes: [String] = ["daisy", "tulip"]

    // Family Activity Picker selection
    @Published var activitySelection = FamilyActivitySelection()

    // (Setup suggestions reuse the existing LimitSuggestion + pendingLimitSuggestion system)

    enum Tab: String, CaseIterable {
        case home = "Home"
        case garden = "Garden"
        case limits = "Limits"
    }

    // MARK: - Managers
    private let screenTime = ScreenTimeManager.shared
    private let cloudKit = CloudKitManager.shared
    private let notifications = NotificationManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var syncTimer: Timer?
    private var dayEndObserver: NSObjectProtocol?
    private var foregroundObserver: NSObjectProtocol?
    private var cloudKitPushObserver: NSObjectProtocol?

    // Debounce & sync health tracking
    private var lastForegroundSyncTime: Date = .distantPast
    private var syncFailureCount = 0
    private let maxConsecutiveFailures = 5
    private var isJoiningCouple = false  // Re-entrancy guard for joinCouple

    // App Group for reading extension flags
    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: "group.com.unplugtogether.shared")
    }

    // MARK: - Local Persistence Keys
    private enum StorageKey {
        static let gardenPlants = "gardenPlants"
        static let activePlant = "activePlant"
        static let streak = "streak"
        static let dayHistory = "dayHistory"
        static let unlockedPlantTypes = "unlockedPlantTypes"
    }

    // MARK: - Init

    init() {
        // Observe CloudKit changes
        cloudKit.$partnerUsage
            .assign(to: &$partnerUsage)

        cloudKit.$pendingApproval
            .compactMap { $0 }
            .sink { [weak self] approval in
                self?.currentApproval = approval
                self?.showApprovalModal = true
            }
            .store(in: &cancellables)

        cloudKit.$isPaired
            .assign(to: &$isPaired)

        // Surface CloudKit connection errors to the UI (unless suppressed during retries)
        cloudKit.$connectionError
            .compactMap { $0 }
            .sink { [weak self] error in
                guard let self = self, !self.suppressErrors else { return }
                self.errorMessage = error
            }
            .store(in: &cancellables)

        // Watch for partner updates from CloudKit
        cloudKit.$remotePartner
            .compactMap { $0 }
            .sink { [weak self] partner in
                self?.partnerName = partner.displayName
                self?.partnerAvatarId = partner.avatarId
                UserDefaults.standard.set(partner.displayName, forKey: "partnerName")
                UserDefaults.standard.set(partner.avatarId, forKey: "partnerAvatarId")
            }
            .store(in: &cancellables)

        // Check if returning user
        if let savedName = UserDefaults.standard.string(forKey: "myName") {
            myName = savedName
            partnerName = UserDefaults.standard.string(forKey: "partnerName") ?? "Partner"
            myAvatarId = UserDefaults.standard.string(forKey: "myAvatarId") ?? "avatar_01"
            partnerAvatarId = UserDefaults.standard.string(forKey: "partnerAvatarId") ?? "avatar_02"
            isCreator = UserDefaults.standard.bool(forKey: "isCreator")

            // Restore check-in frequency
            if let freqStr = UserDefaults.standard.string(forKey: "checkInFrequency"),
               let freq = CheckInFrequency(rawValue: freqStr) {
                checkInFrequency = freq
            }

            // Restore garden state from local storage immediately
            loadGardenLocally()

            // Restore extension-used flag from shared storage
            extensionUsedToday = sharedDefaults?.bool(forKey: "extensionUsedToday") ?? false

            let savedLimits = screenTime.loadAppLimits()
            if !savedLimits.isEmpty {
                appLimits = savedLimits
                state = .home
                Task { await reconnect() }
            }
        }

        // Listen for day changes (midnight rollover)
        setupDayChangeObserver()

        // Listen for app coming to foreground (to check shield flags + approval responses)
        setupForegroundObserver()

        // Listen for CloudKit silent push notifications to trigger immediate sync
        setupCloudKitPushObserver()

        // Check if we missed an end-of-day while app was closed
        checkForMissedDayEnd()

        // Check for any pending shield flags right now
        checkShieldApprovalFlags()
    }

    deinit {
        if let observer = dayEndObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = foregroundObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = cloudKitPushObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - CloudKit Push Observer

    /// Listen for silent push notifications from CloudKit subscriptions
    /// to trigger an immediate sync instead of waiting for the 30s timer.
    private func setupCloudKitPushObserver() {
        cloudKitPushObserver = NotificationCenter.default.addObserver(
            forName: .cloudKitDataChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                // Debounce: skip if we already synced within the last 500ms
                let now = Date()
                guard now.timeIntervalSince(self.lastForegroundSyncTime) > 0.5 else {
                    print("[AppVM] CloudKit push debounced — recent sync already ran")
                    return
                }
                self.lastForegroundSyncTime = now

                print("[AppVM] CloudKit push received — state: \(self.state)")

                switch self.state {
                case .home:
                    // Full sync when on main screen
                    await self.syncData()

                case .waitingForBothLimits:
                    // Check for partner's limits or approval
                    if let pLimits = await CloudKitManager.shared.fetchPartnerLimits() {
                        self.partnerLimits = pLimits
                        self.partnerLimitsSubmitted = true
                        if !self.iConfirmedPartner {
                            self.state = .reviewPartnerLimits
                            return
                        }
                    }
                    if self.iConfirmedPartner {
                        let partnerApproved = await CloudKitManager.shared.fetchPartnerApproval()
                        if partnerApproved {
                            self.partnerConfirmedMe = true
                            self.beginMonitoring()
                        }
                    }

                case .waitingForPartner:
                    // Check if partner joined
                    let joined = await CloudKitManager.shared.checkForPartnerJoin()
                    if joined {
                        self.onPartnerJoined()
                    }

                default:
                    break
                }
            }
        }
    }

    // MARK: - Foreground Monitoring (bridge between extensions and CloudKit)

    /// Watch for the app returning to foreground so we can check extension flags
    /// Debounced to prevent races with push notifications arriving at the same time.
    private func setupForegroundObserver() {
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                // Debounce: skip if we synced within the last 500ms (e.g. push arrived first)
                let now = Date()
                guard now.timeIntervalSince(self.lastForegroundSyncTime) > 0.5 else {
                    print("[AppVM] Foreground sync debounced — recent sync already ran")
                    return
                }
                self.lastForegroundSyncTime = now

                self.checkShieldApprovalFlags()
                await self.checkMyApprovalResponses()

                // If still waiting for partner to join, check on foreground return
                if !self.isPaired && self.state == .waitingForPartner {
                    let joined = await CloudKitManager.shared.checkForPartnerJoin()
                    if joined {
                        self.onPartnerJoined()
                    }
                }

                // If waiting for partner's limits or approval during setup
                if self.state == .waitingForBothLimits {
                    if let pLimits = await CloudKitManager.shared.fetchPartnerLimits() {
                        self.partnerLimits = pLimits
                        self.partnerLimitsSubmitted = true
                        if !self.iConfirmedPartner {
                            self.state = .reviewPartnerLimits
                        }
                    }
                    if self.iConfirmedPartner {
                        let partnerApproved = await CloudKitManager.shared.fetchPartnerApproval()
                        if partnerApproved {
                            self.partnerConfirmedMe = true
                            self.beginMonitoring()
                        }
                    }
                }
            }
        }
    }

    /// Check if the ShieldAction extension wrote a "needs approval" flag
    /// This bridges: shield button tap → main app → CloudKit approval request
    private func checkShieldApprovalFlags() {
        guard let defaults = sharedDefaults else { return }

        // Check if shield "Ask Partner" button was tapped
        let needsApproval = defaults.bool(forKey: "needsApprovalFromShield")
        guard needsApproval else { return }

        // Get which app triggered the block.
        // Try pendingApprovalApp first (set by DeviceActivityMonitor),
        // then fall back to the most recently blocked app from the blockedApps list
        // (ShieldActionExtension can't write a bundle ID because ApplicationToken is opaque).
        var blockedApp = defaults.string(forKey: "pendingApprovalApp") ?? ""
        if blockedApp.isEmpty {
            blockedApp = defaults.stringArray(forKey: "blockedApps")?.last ?? ""
        }
        guard !blockedApp.isEmpty else {
            print("[AppVM] Shield approval flag set but no blocked app found — clearing flag")
            defaults.removeObject(forKey: "needsApprovalFromShield")
            return
        }

        // Clear the flag so we don't re-send
        defaults.removeObject(forKey: "needsApprovalFromShield")

        // Send the approval request via CloudKit
        let app = appLimits.first { $0.bundleIdentifier == blockedApp }
        Task {
            await cloudKit.sendApprovalRequest(
                appBundleId: blockedApp,
                appDisplayName: app?.appName ?? "an app"
            )
        }

        print("[AppVM] Shield approval flag detected — sent CloudKit request for \(blockedApp)")
    }

    /// Check if any approval request THIS user sent has been responded to
    /// This bridges: partner approves on their device → CloudKit → this device unblocks
    private func checkMyApprovalResponses() async {
        guard let partner = cloudKit.currentPartner,
              let code = cloudKit.pairingCode else { return }

        let publicDB = CKContainer(identifier: "iCloud.com.unplugtogether.shared").publicCloudDatabase
        let predicate = NSPredicate(
            format: "pairingCode == %@ AND requesterId == %@ AND status == %@",
            code, partner.id, ApprovalStatus.approved.rawValue
        )
        let query = CKQuery(recordType: "ApprovalRequest", predicate: predicate)

        do {
            let (results, _) = try await publicDB.records(matching: query)

            for (_, result) in results {
                guard let record = try? result.get() else { continue }
                let bundleId = record["appBundleId"] as? String ?? ""
                let extraMinutes = record["extraMinutesGranted"] as? Int ?? 15

                // Unblock and grant extension
                screenTime.grantExtension(minutes: extraMinutes, forApp: bundleId)

                // Extension was used — streak will be broken at day end
                extensionUsedToday = true
                sharedDefaults?.set(true, forKey: "extensionUsedToday")

                // Mark as processed by deleting from pending
                let recordID = record.recordID
                try? await publicDB.deleteRecord(withID: recordID)

                print("[AppVM] Auto-unblocked \(bundleId) — partner approved \(extraMinutes) min")
            }
        } catch {
            print("[AppVM] Failed to check approval responses: \(error)")
        }
    }

    // MARK: - Local Persistence

    /// Save all garden state to UserDefaults as JSON
    private func saveGardenLocally() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        if let data = try? encoder.encode(gardenPlants) {
            UserDefaults.standard.set(data, forKey: StorageKey.gardenPlants)
        }
        if let data = try? encoder.encode(activePlant) {
            UserDefaults.standard.set(data, forKey: StorageKey.activePlant)
        } else {
            UserDefaults.standard.removeObject(forKey: StorageKey.activePlant)
        }
        UserDefaults.standard.set(streak, forKey: StorageKey.streak)
        if let data = try? encoder.encode(dayHistory) {
            UserDefaults.standard.set(data, forKey: StorageKey.dayHistory)
        }
        UserDefaults.standard.set(unlockedPlantTypes, forKey: StorageKey.unlockedPlantTypes)
    }

    /// Load garden state from UserDefaults
    private func loadGardenLocally() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let data = UserDefaults.standard.data(forKey: StorageKey.gardenPlants),
           let plants = try? decoder.decode([GardenPlant].self, from: data) {
            gardenPlants = plants
        }
        if let data = UserDefaults.standard.data(forKey: StorageKey.activePlant),
           let plant = try? decoder.decode(GardenPlant.self, from: data) {
            activePlant = plant
        }
        streak = UserDefaults.standard.integer(forKey: StorageKey.streak)
        if let data = UserDefaults.standard.data(forKey: StorageKey.dayHistory),
           let history = try? decoder.decode([DayResult].self, from: data) {
            dayHistory = history
        }
        if let saved = UserDefaults.standard.stringArray(forKey: StorageKey.unlockedPlantTypes), !saved.isEmpty {
            unlockedPlantTypes = saved
        }
    }

    // MARK: - Setup Flow

    /// Only takes the user's own name now — partner name comes from CloudKit
    func completeNameSetup(myName: String) {
        self.myName = myName
        UserDefaults.standard.set(myName, forKey: "myName")
        state = .avatarPicker  // Pick avatar, then pair
    }

    /// Save avatar selection and move to pairing
    func completeAvatarSetup(avatarId: String) {
        self.myAvatarId = avatarId
        UserDefaults.standard.set(avatarId, forKey: "myAvatarId")
        state = .pairing
    }

    /// Go back from pairing to avatar picker
    func goBackFromPairing() {
        state = .avatarPicker
    }

    /// Submit MY OWN limits during setup — each partner does this independently
    func submitMyLimits(limits: [AppLimitConfig], frequency: CheckInFrequency) async {
        appLimits = limits
        checkInFrequency = frequency
        myLimitsSubmitted = true

        // Save locally
        screenTime.saveAppLimits(limits)
        screenTime.saveSelection(activitySelection)
        UserDefaults.standard.set(frequency.rawValue, forKey: "checkInFrequency")

        // Sync MY limits to CloudKit so partner can see them
        // Retry up to 3 times with backoff
        var syncSucceeded = false
        for attempt in 1...3 {
            await cloudKit.syncMyLimits(limits)
            await cloudKit.syncCheckInFrequency(frequency)

            // Verify sync by fetching back
            if let fetched = await cloudKit.fetchMyLimits(), !fetched.isEmpty {
                syncSucceeded = true
                break
            }

            if attempt < 3 {
                try? await Task.sleep(nanoseconds: UInt64(attempt) * 1_000_000_000)
            }
        }

        if !syncSucceeded {
            errorMessage = "Failed to save your limits. Please check your connection and try again."
            myLimitsSubmitted = false
            return
        }

        // Move to waiting screen — polls until partner also submits
        state = .waitingForBothLimits
    }

    /// Confirm partner's limits — record approval in CloudKit
    func confirmPartnerLimits() async {
        iConfirmedPartner = true
        await cloudKit.setApprovalStatus(approved: true)

        // Always move to waiting state — let polling handle partner confirmation
        state = .waitingForBothLimits

        // Do a quick background check, but don't block the transition
        let partnerApproved = await cloudKit.fetchPartnerApproval()
        if partnerApproved {
            partnerConfirmedMe = true
            beginMonitoring()
        }
    }

    /// Go back to edit my own limits (during setup)
    func goBackToEditMyLimits() {
        state = .pickMyLimits
    }

    /// Both sides confirmed — start monitoring and go home
    func beginMonitoring() {
        guard state != .home else { return }

        screenTime.saveAppLimits(appLimits)
        state = .home
        screenTime.startMonitoring(limits: appLimits)
        startSyncLoop()

        Task {
            await cloudKit.syncMyLimits(appLimits)
            await cloudKit.subscribeToChanges()
        }
    }

    // MARK: - Pairing

    /// Create a new couple and get pairing code (retries silently up to 3 times)
    func createCouple() async {
        isLoading = true
        errorMessage = nil

        await screenTime.requestAuthorization()
        await notifications.requestAuthorization()

        let _ = await cloudKit.createProfile(name: myName, colorHex: "#FF6B6B", avatarId: myAvatarId)

        // Retry up to 3 times silently before showing an error
        suppressErrors = true
        var code = ""
        for attempt in 1...3 {
            cloudKit.connectionError = nil
            code = await cloudKit.createCouple()
            if !code.isEmpty { break }
            if attempt < 3 {
                print("[AppVM] Couple creation attempt \(attempt) failed, retrying...")
                try? await Task.sleep(nanoseconds: 1_500_000_000)
            }
        }
        suppressErrors = false

        // If all retries failed, show a friendly error
        if code.isEmpty {
            errorMessage = cloudKit.connectionError ?? "Couldn't connect to iCloud. Please check your internet connection and try again."
            isLoading = false
            return
        }

        // Clear any transient errors from failed attempts
        errorMessage = nil
        cloudKit.connectionError = nil

        pairingCode = code
        isCreator = true
        UserDefaults.standard.set(true, forKey: "isCreator")

        // Subscribe to Couple record changes so we get a push when partner joins
        await cloudKit.subscribeToCoupleChanges()

        isLoading = false
    }

    /// Transition to the cute waiting screen after sharing the code
    func moveToWaitingForPartner() {
        state = .waitingForPartner
    }

    /// Join existing couple with code
    func joinCouple(code: String) async {
        // Prevent double calls (deep link + manual entry racing)
        guard !isJoiningCouple else {
            print("[AppVM] joinCouple already in progress — ignoring duplicate call")
            return
        }
        isJoiningCouple = true
        defer { isJoiningCouple = false }

        isLoading = true

        // Suppress transient CloudKit errors during the join process
        suppressErrors = true

        await screenTime.requestAuthorization()
        await notifications.requestAuthorization()

        let _ = await cloudKit.createProfile(name: myName, colorHex: "#6C5CE7", avatarId: myAvatarId)
        await cloudKit.joinCouple(code: code)

        suppressErrors = false

        // If join failed (already paired, couple full, etc.), stop here
        if !cloudKit.isPaired {
            // Surface the error now that suppression is off
            if let err = cloudKit.connectionError {
                errorMessage = err
            }
            isLoading = false
            return
        }

        // Clear any transient errors from retries
        errorMessage = nil
        cloudKit.connectionError = nil

        // Get partner's name from CloudKit
        if let remote = cloudKit.remotePartner {
            partnerName = remote.displayName
            partnerAvatarId = remote.avatarId
            UserDefaults.standard.set(partnerName, forKey: "partnerName")
            UserDefaults.standard.set(partnerAvatarId, forKey: "partnerAvatarId")
        }

        isPaired = true
        isCreator = false
        UserDefaults.standard.set(false, forKey: "isCreator")

        // Subscribe to real-time updates
        await cloudKit.subscribeToChanges()

        // Joiner goes to pick their own limits
        state = .pickMyLimits

        isLoading = false
    }

    /// Called when partner joins (creator side) — both go to pick their own limits
    func onPartnerJoined() {
        isPaired = true

        // Get partner's info from CloudKit
        if let remote = cloudKit.remotePartner {
            partnerName = remote.displayName
            partnerAvatarId = remote.avatarId
            UserDefaults.standard.set(partnerName, forKey: "partnerName")
            UserDefaults.standard.set(partnerAvatarId, forKey: "partnerAvatarId")
        }

        // Subscribe to all real-time updates now that we're paired
        Task {
            await cloudKit.subscribeToChanges()
        }

        // Each person picks their own limits
        state = .pickMyLimits
    }

    // MARK: - Reconnect (returning user)

    private func reconnect() async {
        await cloudKit.setup()
        if cloudKit.isPaired {
            isPaired = true

            if let remote = cloudKit.remotePartner {
                partnerName = remote.displayName
                partnerAvatarId = remote.avatarId
                UserDefaults.standard.set(partnerName, forKey: "partnerName")
                UserDefaults.standard.set(partnerAvatarId, forKey: "partnerAvatarId")
            }

            screenTime.startMonitoring(limits: appLimits)
            startSyncLoop()

            // Subscribe to real-time CloudKit changes
            await cloudKit.subscribeToChanges()

            // CloudKit takes priority over local storage when available
            if let garden = await cloudKit.fetchGarden() {
                gardenPlants = garden.plants.filter { $0.isComplete }
                activePlant = garden.plants.first { !$0.isComplete }
                streak = garden.streak
                unlockedPlantTypes = garden.unlockedPlantTypes
                saveGardenLocally()  // Update local cache with fresh cloud data
            }
            // If CloudKit fetch fails, we already loaded local data in init()

            // Fetch partner's per-partner limits
            if let pLimits = await cloudKit.fetchPartnerLimits() {
                partnerLimits = pLimits
            }

            // Fetch pending limit suggestions
            let suggestions = await cloudKit.fetchPendingLimitSuggestions()
            if let first = suggestions.first {
                pendingLimitSuggestion = first
            }
        }
    }

    // MARK: - Real-time Sync Loop

    func startSyncLoop() {
        syncTimer?.invalidate()
        syncTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.syncData()
            }
        }
        Task { await syncData() }
    }

    private func syncData() async {
        var hadErrors = false

        for (bundleId, minutes) in myUsage {
            await cloudKit.syncUsage(appBundleId: bundleId, minutesUsed: minutes)
        }

        // Check if any sync error occurred
        if cloudKit.connectionError != nil {
            hadErrors = true
        }

        await cloudKit.fetchPartnerUsage()
        await cloudKit.checkPendingApprovals()

        // Check if shield extension flagged an approval request
        checkShieldApprovalFlags()

        // Check if partner responded to our approval requests
        await checkMyApprovalResponses()

        // Fetch partner's per-partner limits periodically
        if let pLimits = await cloudKit.fetchPartnerLimits() {
            partnerLimits = pLimits
        }

        // Check for pending limit suggestions from partner
        let suggestions = await cloudKit.fetchPendingLimitSuggestions()
        if let first = suggestions.first, pendingLimitSuggestion == nil {
            pendingLimitSuggestion = first
        }

        // Check for incoming limit change proposals from partner
        await checkIncomingLimitProposals()

        // Check if partner approved our new-app add proposals
        await checkAcceptedAddProposals()

        // Track consecutive failures and surface to UI if persistent
        if hadErrors {
            syncFailureCount += 1
            if syncFailureCount >= maxConsecutiveFailures {
                errorMessage = "Having trouble syncing with your partner. Please check your internet connection."
            }
        } else {
            syncFailureCount = 0
        }
    }

    // MARK: - Automatic Day End

    /// Watch for the calendar day changing (midnight rollover)
    private func setupDayChangeObserver() {
        dayEndObserver = NotificationCenter.default.addObserver(
            forName: .NSCalendarDayChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleDayEnd()
            }
        }
    }

    /// Check if the last recorded day is before today (app was closed overnight)
    private func checkForMissedDayEnd() {
        let lastDayKey = UserDefaults.standard.string(forKey: "lastRecordedDay") ?? ""
        let todayKey = ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: Date()))

        if !lastDayKey.isEmpty && lastDayKey != todayKey {
            // We missed a day end — evaluate now
            handleDayEnd()
        }

        // Record today
        UserDefaults.standard.set(todayKey, forKey: "lastRecordedDay")
    }

    /// Automatically evaluate the day and grow the garden
    private func handleDayEnd() {
        // Fetch latest partner usage before evaluating (in case sync loop hasn't run recently)
        Task {
            await cloudKit.fetchPartnerUsage()
        }

        // Check if an extension was used (either from in-memory flag or shared storage)
        let extensionWasUsed = extensionUsedToday || (sharedDefaults?.bool(forKey: "extensionUsedToday") ?? false)

        let myGoalsMet = appLimits.allSatisfy { limit in
            (myUsage[limit.bundleIdentifier] ?? 0) <= limit.dailyLimitMinutes
        }
        let partnerLimitsToCheck = partnerLimits.isEmpty ? appLimits : partnerLimits
        let partnerGoalsMet = partnerLimitsToCheck.allSatisfy { limit in
            (partnerUsage[limit.bundleIdentifier] ?? 0) <= limit.dailyLimitMinutes
        }

        // If an extension was approved, the day counts as failed — streak breaks
        let effectiveGoalsMet = myGoalsMet && partnerGoalsMet && !extensionWasUsed

        let result = DayResult(
            date: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
            partner1Met: myGoalsMet && !extensionWasUsed,
            partner2Met: partnerGoalsMet && !extensionWasUsed
        )
        dayHistory.append(result)

        if effectiveGoalsMet {
            let oldStreak = streak
            streak += 1
            checkMilestones(oldStreak: oldStreak, newStreak: streak)
            advanceActivePlant()
            // Good day — completed plants recover from weathering
            tickWeatheringRecovery()
        } else {
            streak = 0
        }

        // Reset for new day
        extensionUsedToday = false
        sharedDefaults?.set(false, forKey: "extensionUsedToday")
        screenTime.resetDailyExtensions()
        screenTime.unblockAllApps()
        myUsage = [:]

        // Save today's key
        let todayKey = ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: Date()))
        UserDefaults.standard.set(todayKey, forKey: "lastRecordedDay")

        saveGardenLocally()
        syncGardenToCloud()
        screenTime.startMonitoring(limits: appLimits)
    }

    // MARK: - Screen Time Events

    func onWarningThreshold(appBundleId: String) {
        let appName = appLimits.first { $0.bundleIdentifier == appBundleId }?.appName ?? "an app"
        let limit = appLimits.first { $0.bundleIdentifier == appBundleId }?.dailyLimitMinutes ?? 0
        let remaining = Int(Double(limit) * 0.2)
        notifications.scheduleWarning(appName: appName, minutesRemaining: remaining)
    }

    func onLimitReached(appBundleId: String) {
        let app = appLimits.first { $0.bundleIdentifier == appBundleId }
        screenTime.blockApps()

        Task {
            await cloudKit.sendApprovalRequest(
                appBundleId: appBundleId,
                appDisplayName: app?.appName ?? "an app"
            )
        }
    }

    // MARK: - Approval Handling

    func approveRequest(extraMinutes: Int = 15) {
        guard let request = currentApproval else { return }

        Task {
            await cloudKit.respondToApproval(
                requestId: request.id.uuidString,
                approved: true,
                extraMinutes: extraMinutes
            )
            // Do NOT call grantExtension() here — this runs on the APPROVER's
            // device. The REQUESTER's device will detect the approval via
            // checkMyApprovalResponses() and unblock apps on their own side.
        }

        // Penalty: add 2 penalty days to ALL plants (active + completed) + break streak
        applyPenaltyToAllPlants()
        penalizeActivePlant(days: 2)
        extensionUsedToday = true
        sharedDefaults?.set(true, forKey: "extensionUsedToday")

        showApprovalModal = false
        currentApproval = nil
    }

    func denyRequest() {
        guard let request = currentApproval else { return }

        Task {
            await cloudKit.respondToApproval(
                requestId: request.id.uuidString,
                approved: false
            )
        }

        showApprovalModal = false
        currentApproval = nil
    }

    // MARK: - Propose Limit Change

    /// Send a limit change proposal to partner for approval
    func proposeLimitChange(appId: String, newLimit: Int) {
        guard let app = appLimits.first(where: { $0.bundleIdentifier == appId }) else { return }

        pendingLimitChangeProposals.insert(appId)

        let proposal = LimitProposal(
            appBundleId: appId,
            appName: app.appName,
            currentLimit: app.dailyLimitMinutes,
            proposedLimit: newLimit,
            proposerId: cloudKit.currentPartner?.id ?? ""
        )

        Task {
            await cloudKit.sendLimitProposal(proposal)
        }

        // Show a confirmation that the proposal was sent
        notifications.scheduleWarning(
            appName: app.appName,
            minutesRemaining: newLimit
        )
    }

    /// Accept a limit change proposal from partner
    func acceptLimitProposal() {
        guard let proposal = pendingLimitProposal else { return }

        if proposal.currentLimit == 0 {
            // New app being added by PARTNER — just approve in CloudKit.
            // The proposer's device will detect the acceptance via
            // checkAcceptedAddProposals() and add it to their own limits.
        } else if proposal.proposedLimit == 0 {
            // Partner wants to REMOVE an app — just approve in CloudKit.
            // The proposer's device will detect acceptance and remove locally.
        } else {
            // Partner wants to CHANGE their limit — just approve in CloudKit.
            // The proposer's device will detect acceptance and update locally.
        }

        // Mark as accepted in CloudKit
        Task {
            await cloudKit.respondToLimitProposal(proposalId: proposal.id.uuidString, accepted: true)
        }

        pendingLimitProposal = nil
        showLimitProposal = false
    }

    /// Reject a limit change proposal from partner
    func rejectLimitProposal() {
        guard let proposal = pendingLimitProposal else { return }

        // Mark as rejected in CloudKit
        Task {
            await cloudKit.respondToLimitProposal(proposalId: proposal.id.uuidString, accepted: false)
        }

        pendingLimitProposal = nil
        showLimitProposal = false
    }

    // Track which apps have a pending "add" proposal so the UI can show feedback
    @Published var pendingAddProposals: Set<String> = []

    // Track which apps have a pending limit-change proposal awaiting partner review
    @Published var pendingLimitChangeProposals: Set<String> = []

    // Track which apps have a pending removal proposal awaiting partner review
    @Published var pendingRemovalProposals: Set<String> = []

    /// Add a new app — sends a proposal to partner for approval (does NOT activate until approved)
    func addAppWithApproval(app: TrackedApp, limitMinutes: Int) {
        // Check if app is already tracked
        if appLimits.contains(where: { $0.bundleIdentifier == app.rawValue }) {
            // Already tracked — propose a limit change instead
            proposeLimitChange(appId: app.rawValue, newLimit: limitMinutes)
            return
        }

        // Prevent duplicate adds
        guard !pendingAddProposals.contains(app.rawValue) else { return }

        // Mark as pending — will be added to appLimits only when partner approves
        pendingAddProposals.insert(app.rawValue)

        // Send the proposal to partner for approval + push notification
        let proposal = LimitProposal(
            appBundleId: app.rawValue,
            appName: app.displayName,
            currentLimit: 0,
            proposedLimit: limitMinutes,
            proposerId: cloudKit.currentPartner?.id ?? ""
        )

        Task {
            await cloudKit.sendLimitProposal(proposal)
        }
    }

    /// Request to remove an app — sends a proposal to partner for approval
    func removeAppLimit(appId: String) {
        guard let app = appLimits.first(where: { $0.bundleIdentifier == appId }) else { return }
        guard !pendingRemovalProposals.contains(appId) else { return }

        pendingRemovalProposals.insert(appId)

        // Send a removal proposal (proposedLimit = 0 means removal)
        let proposal = LimitProposal(
            appBundleId: appId,
            appName: app.appName,
            currentLimit: app.dailyLimitMinutes,
            proposedLimit: 0,
            proposerId: cloudKit.currentPartner?.id ?? ""
        )

        Task {
            await cloudKit.sendLimitProposal(proposal)
        }
    }

    /// Actually remove an app after partner approves the removal
    func executeRemoveAppLimit(appId: String) {
        appLimits.removeAll(where: { $0.bundleIdentifier == appId })
        pendingRemovalProposals.remove(appId)
        screenTime.saveAppLimits(appLimits)
        screenTime.startMonitoring(limits: appLimits)

        Task {
            await cloudKit.syncMyLimits(appLimits)
        }
    }

    /// Check if partner accepted our proposals (adds, changes, removals) and apply locally.
    /// Always checks CloudKit — pending sets may be empty after app restart but accepted
    /// proposals can still be waiting in CloudKit.
    func checkAcceptedAddProposals() async {
        let accepted = await cloudKit.fetchAcceptedProposals()
        guard !accepted.isEmpty else { return }
        var changed = false

        for proposal in accepted {
            if proposal.currentLimit == 0 {
                // New app add — partner approved
                if let trackedApp = TrackedApp(rawValue: proposal.appBundleId),
                   !appLimits.contains(where: { $0.bundleIdentifier == proposal.appBundleId }) {
                    let config = trackedApp.toConfig(limitMinutes: proposal.proposedLimit)
                    appLimits.append(config)
                    changed = true
                }
                pendingAddProposals.remove(proposal.appBundleId)

            } else if proposal.proposedLimit == 0 {
                // Removal — partner approved
                appLimits.removeAll(where: { $0.bundleIdentifier == proposal.appBundleId })
                pendingRemovalProposals.remove(proposal.appBundleId)
                changed = true

            } else {
                // Limit change — partner approved
                if let idx = appLimits.firstIndex(where: { $0.bundleIdentifier == proposal.appBundleId }) {
                    appLimits[idx] = AppLimitConfig(
                        appName: appLimits[idx].appName,
                        bundleIdentifier: appLimits[idx].bundleIdentifier,
                        dailyLimitMinutes: proposal.proposedLimit,
                        iconName: appLimits[idx].iconName,
                        colorHex: appLimits[idx].colorHex
                    )
                    changed = true
                }
                pendingLimitChangeProposals.remove(proposal.appBundleId)
            }
        }

        if changed {
            screenTime.saveAppLimits(appLimits)
            screenTime.startMonitoring(limits: appLimits)
            Task { await cloudKit.syncMyLimits(appLimits) }
        }
    }

    /// Poll CloudKit for incoming limit change proposals from partner
    func checkIncomingLimitProposals() async {
        guard let proposal = await cloudKit.fetchPendingLimitProposals() else { return }

        // Only update if we don't already have this proposal displayed
        if pendingLimitProposal == nil || pendingLimitProposal?.appBundleId != proposal.appBundleId {
            pendingLimitProposal = proposal
            showLimitProposal = true
        }
    }

    // MARK: - Shop-Based Garden

    /// Whether the user can select a new plant (no active plant currently growing)
    var canSelectPlant: Bool {
        activePlant == nil
    }

    /// Select a plant from the shop to start growing (must be unlocked)
    func selectPlantFromShop(shopPlantId: String) {
        guard canSelectPlant else { return }
        guard unlockedPlantTypes.contains(shopPlantId) else { return }
        guard let shopPlant = plantShop.first(where: { $0.id == shopPlantId }) else { return }

        let newPlant = GardenPlant(
            shopPlantId: shopPlantId,
            daysRequired: shopPlant.daysToGrow,
            gridX: Int.random(in: 2...18),
            gridY: Int.random(in: 4...12),
            plantedBy: cloudKit.currentPartner?.id ?? "me"
        )
        activePlant = newPlant
        saveGardenLocally()
        syncGardenToCloud()
    }

    /// Advance the active plant by 1 day (called at day end when goals are met)
    private func advanceActivePlant() {
        guard var plant = activePlant else {
            // No active plant — still notify about the streak
            notifications.showGardenGrowth(plantName: "garden", streak: streak)
            return
        }

        // Build today's contributions
        let contributions = appLimits.map { limit in
            PlantAppContribution(
                appName: limit.appName,
                iconName: limit.iconName,
                colorHex: limit.colorHex,
                limitMinutes: limit.dailyLimitMinutes,
                usedMinutes: myUsage[limit.bundleIdentifier] ?? 0
            )
        }
        plant.appContributions.append(contentsOf: contributions)

        plant.daysProgress += 1

        // Check if plant is complete
        if plant.daysProgress >= plant.daysRequired {
            plant.isComplete = true
            plant.completedDate = Date()
            gardenPlants.append(plant)
            activePlant = nil
            notifications.showGardenGrowth(
                plantName: plant.shopPlant?.name ?? "plant",
                streak: streak
            )
        } else {
            activePlant = plant
            notifications.showGardenGrowth(
                plantName: plant.shopPlant?.name ?? "plant",
                streak: streak
            )
        }

        saveGardenLocally()
    }

    /// Deduct days from the active plant's progress (penalty for approving more screen time)
    func penalizeActivePlant(days: Int) {
        guard var plant = activePlant else { return }
        plant.daysProgress = max(0, plant.daysProgress - days)
        activePlant = plant
        saveGardenLocally()
        syncGardenToCloud()
    }

    /// Sync all garden data (completed + active) to CloudKit
    private func syncGardenToCloud() {
        var allPlants = gardenPlants
        if let active = activePlant {
            allPlants.append(active)
        }
        Task {
            await cloudKit.syncGarden(plants: allPlants, streak: streak, unlockedPlantTypes: unlockedPlantTypes)
        }
    }

    // MARK: - Penalty System (applied to ALL plants)

    /// Apply penalty when an extension is granted:
    /// - Growing plants: +2 penalty days (slows growth)
    /// - Completed plants: weathering damage (+2 days, 2 days to recover; dies at 70%)
    func applyPenaltyToAllPlants() {
        var deadPlantNames: [String] = []

        // Completed plants get weathering
        for i in gardenPlants.indices {
            if gardenPlants[i].isComplete && !gardenPlants[i].isDead {
                let died = gardenPlants[i].applyWeathering()
                if died {
                    let name = gardenPlants[i].shopPlant?.name ?? gardenPlants[i].shopPlantId
                    deadPlantNames.append(name)
                }
            }
        }

        // Active (growing) plant gets penalty days
        if var plant = activePlant {
            plant.penaltyDays += 2
            activePlant = plant
        }

        saveGardenLocally()

        // Notify about dead plants
        for name in deadPlantNames {
            notifications.showPlantDeathNotification(plantName: name)
        }
    }

    /// Tick recovery for all completed plants at day end (called when no penalty happened)
    func tickWeatheringRecovery() {
        for i in gardenPlants.indices {
            gardenPlants[i].tickRecovery()
        }
        saveGardenLocally()
    }

    // MARK: - Plant Unlock System

    /// Check streak milestones and unlock new plant types
    func checkMilestones(oldStreak: Int, newStreak: Int) {
        let milestones = PlantType.allCases
        for plant in milestones {
            let threshold = plant.unlockStreakDays
            guard threshold > 0 else { continue }
            if oldStreak < threshold && newStreak >= threshold {
                let key = plant.rawValue
                if !unlockedPlantTypes.contains(key) {
                    unlockedPlantTypes.append(key)
                    notifications.showUnlockNotification(plantName: plant.displayName)
                }
            }
        }
    }

    // MARK: - Limit Suggestions (per-partner)

    /// Suggest a limit change for partner's app
    func suggestLimitChange(appBundleId: String, appDisplayName: String, suggestedMinutes: Int, currentMinutes: Int) {
        guard let remotePartner = cloudKit.remotePartner,
              let myId = cloudKit.myPartnerId else { return }
        let suggestion = LimitSuggestion(
            fromPartnerId: myId,
            toPartnerId: remotePartner.id,
            appBundleId: appBundleId,
            appDisplayName: appDisplayName,
            suggestedMinutes: suggestedMinutes,
            currentMinutes: currentMinutes
        )
        Task { await cloudKit.syncLimitSuggestion(suggestion) }
    }

    /// Accept a limit suggestion from partner
    func acceptLimitSuggestion(_ suggestion: LimitSuggestion) {
        // Update the limit in my own limits
        if let idx = appLimits.firstIndex(where: { $0.bundleIdentifier == suggestion.appBundleId }) {
            appLimits[idx].dailyLimitMinutes = suggestion.suggestedMinutes
            screenTime.saveAppLimits(appLimits)
            screenTime.startMonitoring(limits: appLimits)
            Task { await cloudKit.syncAppLimits(appLimits) }
        }
        pendingLimitSuggestion = nil
        Task { await cloudKit.respondToLimitSuggestion(id: suggestion.id.uuidString, accepted: true) }
    }

    /// Reject a limit suggestion from partner
    func rejectLimitSuggestion(_ suggestion: LimitSuggestion) {
        pendingLimitSuggestion = nil
        Task { await cloudKit.respondToLimitSuggestion(id: suggestion.id.uuidString, accepted: false) }
    }

    // MARK: - Deep Link Handling

    /// Handle incoming URL — supports both:
    ///   Custom scheme:  unplugtogether://join?code=ABC123
    ///   Universal Link: https://unplugtogether.app/join?code=ABC123
    func handleDeepLink(_ url: URL) {
        var code: String?

        if url.scheme == "unplugtogether" {
            // Custom URL scheme: unplugtogether://join?code=ABC123
            guard url.host == "join" else { return }
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            code = components?.queryItems?.first(where: { $0.name == "code" })?.value
        } else if url.scheme == "https" {
            // Universal Link: https://unplugtogether.app/join?code=ABC123
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            code = components?.queryItems?.first(where: { $0.name == "code" })?.value

            // Also support path-based: /unplugtogether/join/ABC123
            if code == nil {
                let path = url.path
                if let match = path.range(of: #"/join/([A-Z0-9]+)"#, options: .regularExpression) {
                    let segment = path[match]
                    let parts = segment.split(separator: "/")
                    if let last = parts.last { code = String(last) }
                }
            }
        }

        guard let joinCode = code?.uppercased(), !joinCode.isEmpty else { return }

        deepLinkCode = joinCode

        // If user hasn't done setup yet, save the code for later and fast-track them
        // If they're at the pairing step already, auto-join
        if state == .pairing {
            Task { await joinCouple(code: joinCode) }
        }
        // If they're already home and paired, ignore
        // If they're in setup/limits, the code will be waiting when they reach pairing
    }

    // MARK: - Avatar Helpers

    var myAvatar: AvatarConfig {
        avatarCatalog.first { $0.id == myAvatarId } ?? avatarCatalog[0]
    }

    var partnerAvatar: AvatarConfig {
        avatarCatalog.first { $0.id == partnerAvatarId } ?? avatarCatalog[1]
    }

    // MARK: - Update Limits

    func updateLimit(appId: String, newLimit: Int) {
        if let idx = appLimits.firstIndex(where: { $0.bundleIdentifier == appId }) {
            appLimits[idx].dailyLimitMinutes = newLimit
            screenTime.saveAppLimits(appLimits)
            screenTime.startMonitoring(limits: appLimits)
            Task {
                await cloudKit.syncAppLimits(appLimits)
                await cloudKit.syncMyLimits(appLimits)
            }
        }
    }
}

// MARK: - Limit Proposal Model
struct LimitProposal: Codable, Identifiable {
    let id: UUID
    let appBundleId: String
    let appName: String
    let currentLimit: Int
    let proposedLimit: Int
    let proposerId: String

    init(appBundleId: String, appName: String, currentLimit: Int, proposedLimit: Int, proposerId: String) {
        self.id = UUID()
        self.appBundleId = appBundleId
        self.appName = appName
        self.currentLimit = currentLimit
        self.proposedLimit = proposedLimit
        self.proposerId = proposerId
    }
}
