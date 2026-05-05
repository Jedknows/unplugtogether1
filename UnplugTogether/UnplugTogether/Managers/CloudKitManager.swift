import Foundation
import CloudKit
import Combine

/// Handles all CloudKit operations for partner syncing:
/// - Creating/joining a couple via pairing code
/// - Syncing app limits, usage data, and approval requests in real time
/// - Push notifications for approval requests
@MainActor
class CloudKitManager: ObservableObject {

    static let shared = CloudKitManager()

    // MARK: - Published State
    @Published var currentPartner: PartnerProfile?
    @Published var remotePartner: PartnerProfile?
    @Published var couple: Couple?
    @Published var isPaired = false
    @Published var pairingCode: String?
    @Published var pendingApproval: ApprovalRequest?
    @Published var partnerUsage: [String: Int] = [:]  // bundleId: minutes
    @Published var connectionError: String?

    /// Convenience accessor for the current user's partner ID
    var myPartnerId: String? { currentPartner?.id }

    // MARK: - CloudKit
    private let container = CKContainer(identifier: "iCloud.com.unplugtogether.shared")
    private var privateDB: CKDatabase { container.privateCloudDatabase }
    private var sharedDB: CKDatabase { container.sharedCloudDatabase }

    // Use a custom zone for couple data
    private let coupleZone = CKRecordZone(zoneName: "CoupleZone")
    private var subscription: CKSubscription?

    private init() {}

    // MARK: - Setup

    /// Initialize CloudKit and check for existing couple
    func setup() async {
        // Try to create custom zone (don't block on failure — public DB still works)
        do {
            try await privateDB.save(coupleZone)
        } catch {
            print("[CloudKit] Zone creation failed (non-blocking): \(error)")
        }

        // Check for existing profile
        if let profile = loadLocalProfile() {
            currentPartner = profile
            // Try to reconnect to existing couple (without re-running join validation)
            if let code = UserDefaults.standard.string(forKey: "pairingCode") {
                pairingCode = code
                await reconnectToCouple(code: code)
            }
        }

        // Subscribe to changes
        await subscribeToChanges()
    }

    /// Reconnect to an existing couple without re-running join validation.
    /// This is for returning users who already have a saved pairing code.
    private func reconnectToCouple(code: String) async {
        guard let partner = currentPartner else { return }

        let publicDB = container.publicCloudDatabase
        let predicate = NSPredicate(format: "pairingCode == %@", code)
        let query = CKQuery(recordType: "Couple", predicate: predicate)

        do {
            let (results, _) = try await publicDB.records(matching: query)

            guard let (_, result) = results.first,
                  let record = try? result.get() else {
                print("[CloudKit] Reconnect: no couple found for code \(code)")
                return
            }

            let partner1Id = record["partner1Id"] as? String ?? ""
            let partner2Id = record["partner2Id"] as? String ?? ""

            // Verify this user is actually part of this couple
            guard partner1Id == partner.id || partner2Id == partner.id else {
                print("[CloudKit] Reconnect: user not part of this couple")
                return
            }

            // Build local couple object
            var newCouple = Couple(pairingCode: code, partner1Id: partner1Id)
            newCouple.partner2Id = partner2Id.isEmpty ? nil : partner2Id
            couple = newCouple

            // Only mark as paired if both partners are present
            isPaired = !partner2Id.isEmpty

            // Fetch the other partner's profile
            let otherPartnerId = (partner1Id == partner.id) ? partner2Id : partner1Id
            if !otherPartnerId.isEmpty {
                let otherName = (partner1Id == partner.id)
                    ? record["partner2Name"] as? String
                    : record["partner1Name"] as? String

                let otherAvatarKey = (partner1Id == partner.id) ? "partner2AvatarId" : "partner1AvatarId"
                let otherAvatarId = record[otherAvatarKey] as? String ?? "avatar_02"
                remotePartner = PartnerProfile(
                    id: otherPartnerId,
                    displayName: otherName ?? "Partner",
                    avatarColorHex: "#6C5CE7",
                    avatarId: otherAvatarId
                )
            }

            print("[CloudKit] Reconnected to couple (code: \(code), paired: \(isPaired))")

        } catch {
            print("[CloudKit] Reconnect error: \(error)")
        }
    }

    // MARK: - Partner Profile

    /// Create a new partner profile
    func createProfile(name: String, colorHex: String, avatarId: String = "avatar_01") async -> PartnerProfile {
        let profile = PartnerProfile(displayName: name, avatarColorHex: colorHex, avatarId: avatarId)

        // Always set locally first — this is required for pairing to work
        saveLocalProfile(profile)
        currentPartner = profile

        // Then try to save to CloudKit (nice-to-have, not blocking)
        let record = CKRecord(recordType: "Partner", recordID: CKRecord.ID(recordName: profile.id, zoneID: coupleZone.zoneID))
        record["displayName"] = profile.displayName
        record["avatarColorHex"] = profile.avatarColorHex
        record["avatarId"] = profile.avatarId
        record["joinedAt"] = profile.joinedAt

        do {
            try await privateDB.save(record)
            print("[CloudKit] Profile created: \(name)")
        } catch {
            print("[CloudKit] Failed to save profile to CloudKit (local profile still valid): \(error)")
        }

        return profile
    }

    // MARK: - Pairing

    /// Check if this user is already part of a couple in CloudKit.
    /// Returns the existing couple's pairing code if found, or nil if not in a couple.
    func findExistingCouple() async -> String? {
        guard let partner = currentPartner else { return nil }

        let publicDB = container.publicCloudDatabase

        // Check as partner1
        let pred1 = NSPredicate(format: "partner1Id == %@", partner.id)
        let query1 = CKQuery(recordType: "Couple", predicate: pred1)

        // Check as partner2
        let pred2 = NSPredicate(format: "partner2Id == %@", partner.id)
        let query2 = CKQuery(recordType: "Couple", predicate: pred2)

        do {
            let (results1, _) = try await publicDB.records(matching: query1)
            if let (_, result) = results1.first,
               let record = try? result.get(),
               let code = record["pairingCode"] as? String {
                return code
            }

            let (results2, _) = try await publicDB.records(matching: query2)
            if let (_, result) = results2.first,
               let record = try? result.get(),
               let code = record["pairingCode"] as? String {
                return code
            }
        } catch {
            print("[CloudKit] Error checking existing couple: \(error)")
        }

        return nil
    }

    /// Generate a unique 6-digit pairing code and create a couple record
    func createCouple() async -> String {
        guard let partner = currentPartner else {
            connectionError = "Could not create your profile. Make sure you're signed into iCloud in Settings."
            return ""
        }

        // If this user already has a couple, recover the existing code
        if let existingCode = await findExistingCouple() {
            pairingCode = existingCode
            connectionError = nil  // Clear any stale error
            UserDefaults.standard.set(existingCode, forKey: "pairingCode")
            await reconnectToCouple(code: existingCode)
            print("[CloudKit] Recovered existing couple code: \(existingCode)")
            return existingCode
        }

        // Generate a 6-character alphanumeric code
        let code = generatePairingCode()

        let publicDB = container.publicCloudDatabase

        // Try saving to CloudKit public database with multiple strategies
        var saved = false

        // Strategy 1: standard save
        do {
            let record = CKRecord(recordType: "Couple")
            record["pairingCode"] = code
            record["partner1Id"] = partner.id
            record["partner1Name"] = partner.displayName
            record["partner1AvatarId"] = partner.avatarId
            record["createdAt"] = Date()
            record["currentStreak"] = 0
            record["longestStreak"] = 0

            try await publicDB.save(record)
            saved = true
            print("[CloudKit] Couple created with code: \(code)")
        } catch {
            print("[CloudKit] Strategy 1 failed: \(error)")
        }

        // Strategy 2: use a named record ID (some containers need deterministic IDs)
        if !saved {
            do {
                let recordID = CKRecord.ID(recordName: "couple_\(code)")
                let record = CKRecord(recordType: "Couple", recordID: recordID)
                record["pairingCode"] = code
                record["partner1Id"] = partner.id
                record["partner1Name"] = partner.displayName
                record["partner1AvatarId"] = partner.avatarId
                record["createdAt"] = Date()
                record["currentStreak"] = 0
                record["longestStreak"] = 0

                try await publicDB.save(record)
                saved = true
                print("[CloudKit] Couple created (strategy 2) with code: \(code)")
            } catch {
                print("[CloudKit] Strategy 2 failed: \(error)")
            }
        }

        // Strategy 3: check if it actually saved despite the error
        if !saved {
            // Wait briefly then check if the record exists
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            if let recoveredCode = await findExistingCouple() {
                let newCouple = Couple(pairingCode: recoveredCode, partner1Id: partner.id)
                couple = newCouple
                pairingCode = recoveredCode
                isPaired = false
                connectionError = nil
                UserDefaults.standard.set(recoveredCode, forKey: "pairingCode")
                print("[CloudKit] Recovered couple after errors: \(recoveredCode)")
                return recoveredCode
            }
        }

        if saved {
            let newCouple = Couple(pairingCode: code, partner1Id: partner.id)
            couple = newCouple
            pairingCode = code
            isPaired = false
            connectionError = nil
            UserDefaults.standard.set(code, forKey: "pairingCode")
        } else {
            connectionError = "Couldn't connect to iCloud. Make sure you're signed in and have internet access, then try again."
        }

        return pairingCode ?? ""
    }

    /// Join an existing couple using a pairing code
    func joinCouple(code: String) async {
        guard let partner = currentPartner else { return }

        // Block if this user is already in a couple
        if let existingCode = await findExistingCouple() {
            connectionError = "You're already paired with a partner (code: \(existingCode)). You can only have one partner at a time."
            print("[CloudKit] Join couple rejected — user already in a couple")
            return
        }

        let publicDB = container.publicCloudDatabase

        // Retry loop to handle oplock (optimistic locking) conflicts
        let maxAttempts = 3
        for attempt in 1...maxAttempts {
            let predicate = NSPredicate(format: "pairingCode == %@", code)
            let query = CKQuery(recordType: "Couple", predicate: predicate)

            do {
                let (results, _) = try await publicDB.records(matching: query)

                guard let (_, result) = results.first,
                      let record = try? result.get() else {
                    connectionError = "No couple found with code: \(code)"
                    return
                }

                // Check if this couple already has two partners
                let existingPartner2 = record["partner2Id"] as? String ?? ""
                if !existingPartner2.isEmpty {
                    // If WE are already partner2, treat as success (previous call succeeded)
                    if existingPartner2 == partner.id {
                        print("[CloudKit] Already joined as partner2 — treating as success")
                    } else {
                        connectionError = "This couple already has two partners. Each code can only be used by one person."
                        print("[CloudKit] Join rejected — couple already full")
                        return
                    }
                }

                // Check you're not trying to join your own couple
                let partner1Id = record["partner1Id"] as? String ?? ""
                if partner1Id == partner.id {
                    connectionError = "You can't join your own couple code."
                    print("[CloudKit] Join rejected — can't join own couple")
                    return
                }

                // Only save if we haven't already joined
                if existingPartner2 != partner.id {
                    // Update the record with partner 2
                    record["partner2Id"] = partner.id
                    record["partner2Name"] = partner.displayName
                    record["partner2AvatarId"] = partner.avatarId

                    try await publicDB.save(record)
                }

                // Build local couple object
                var newCouple = Couple(pairingCode: code, partner1Id: partner1Id)
                newCouple.partner2Id = partner.id

                couple = newCouple
                pairingCode = code
                isPaired = true

                // Fetch the other partner's profile
                let otherPartnerId = (partner1Id == partner.id)
                    ? record["partner2Id"] as? String
                    : record["partner1Id"] as? String

                if let otherId = otherPartnerId {
                    let otherName = (partner1Id == partner.id)
                        ? record["partner2Name"] as? String
                        : record["partner1Name"] as? String
                    let otherAvatarKey2 = (partner1Id == partner.id) ? "partner2AvatarId" : "partner1AvatarId"
                    let otherAvatarId2 = record[otherAvatarKey2] as? String ?? "avatar_02"

                    remotePartner = PartnerProfile(
                        id: otherId,
                        displayName: otherName ?? "Partner",
                        avatarColorHex: "#6C5CE7",
                        avatarId: otherAvatarId2
                    )
                }

                UserDefaults.standard.set(code, forKey: "pairingCode")
                print("[CloudKit] Joined couple with code: \(code)")

                // Start listening for real-time updates
                await subscribeToChanges()

                // Success — exit the retry loop
                return

            } catch let ckError as CKError where ckError.code == .serverRecordChanged {
                // Oplock conflict — the record was modified between our fetch and save.
                // Re-fetch and retry.
                print("[CloudKit] Oplock conflict on attempt \(attempt)/\(maxAttempts), retrying...")
                if attempt < maxAttempts {
                    try? await Task.sleep(nanoseconds: UInt64(attempt) * 500_000_000)
                    continue
                } else {
                    connectionError = "Couldn't join — please try again."
                    print("[CloudKit] Failed to join after \(maxAttempts) attempts due to record conflicts")
                }
            } catch {
                connectionError = "Failed to join: \(error.localizedDescription)"
                print("[CloudKit] Failed to join couple: \(error)")
                return
            }
        }
    }

    // MARK: - Partner Join Detection (for creator polling)

    /// Check if partner2 has joined the couple record.
    /// Called by the creator's polling loop to detect when their partner joins.
    /// Uses resultsLimit: 1 to keep it lightweight.
    func checkForPartnerJoin() async -> Bool {
        guard let code = pairingCode, let partner = currentPartner else { return false }

        let publicDB = container.publicCloudDatabase
        let predicate = NSPredicate(format: "pairingCode == %@", code)
        let query = CKQuery(recordType: "Couple", predicate: predicate)

        do {
            let (results, _) = try await publicDB.records(matching: query, resultsLimit: 1)

            guard let (_, result) = results.first,
                  let record = try? result.get() else { return false }

            let partner2Id = record["partner2Id"] as? String ?? ""
            guard !partner2Id.isEmpty else { return false }

            // Partner has joined! Update local state.
            let partner1Id = record["partner1Id"] as? String ?? ""
            var newCouple = Couple(pairingCode: code, partner1Id: partner1Id)
            newCouple.partner2Id = partner2Id
            couple = newCouple
            isPaired = true

            // Fetch the partner's profile info
            let otherPartnerId = (partner1Id == partner.id) ? partner2Id : partner1Id
            let otherName = (partner1Id == partner.id)
                ? record["partner2Name"] as? String
                : record["partner1Name"] as? String
            let otherAvatarKey3 = (partner1Id == partner.id) ? "partner2AvatarId" : "partner1AvatarId"
            let otherAvatarId3 = record[otherAvatarKey3] as? String ?? "avatar_02"

            remotePartner = PartnerProfile(
                id: otherPartnerId,
                displayName: otherName ?? "Partner",
                avatarColorHex: "#6C5CE7",
                avatarId: otherAvatarId3
            )

            print("[CloudKit] Partner joined! (partner2Id: \(partner2Id))")
            return true

        } catch {
            print("[CloudKit] Error checking for partner join: \(error)")
            return false
        }
    }

    // MARK: - Sync App Limits

    /// Push agreed-upon app limits to CloudKit so both partners have them
    func syncAppLimits(_ limits: [AppLimitConfig]) async {
        guard let code = pairingCode else { return }

        let publicDB = container.publicCloudDatabase
        let recordID = CKRecord.ID(recordName: "limits_\(code)")

        for attempt in 1...3 {
            do {
                // Try to fetch existing record first, then update it
                let record: CKRecord
                do {
                    record = try await publicDB.record(for: recordID)
                } catch {
                    // Record doesn't exist yet — create a new one
                    record = CKRecord(recordType: "AppLimits", recordID: recordID)
                }

                if let data = try? JSONEncoder().encode(limits) {
                    record["limitsData"] = data
                }
                record["pairingCode"] = code
                record["updatedAt"] = Date()

                try await publicDB.save(record)
                print("[CloudKit] Synced \(limits.count) app limits")
                return  // Success
            } catch let ckError as CKError where ckError.code == .serverRecordChanged {
                print("[CloudKit] Oplock conflict syncing app limits (attempt \(attempt)/3), retrying...")
                if attempt < 3 {
                    try? await Task.sleep(nanoseconds: UInt64(attempt) * 500_000_000)
                    continue
                }
                print("[CloudKit] Failed to sync app limits after 3 attempts")
            } catch {
                print("[CloudKit] Failed to sync limits: \(error)")
                return
            }
        }
    }

    /// Fetch the latest app limits from CloudKit
    func fetchAppLimits() async -> [AppLimitConfig] {
        guard let code = pairingCode else { return [] }

        let publicDB = container.publicCloudDatabase
        let recordID = CKRecord.ID(recordName: "limits_\(code)")

        do {
            let record = try await publicDB.record(for: recordID)
            if let data = record["limitsData"] as? Data,
               let limits = try? JSONDecoder().decode([AppLimitConfig].self, from: data) {
                return limits
            }
        } catch {
            print("[CloudKit] Failed to fetch limits: \(error)")
        }
        return []
    }

    // MARK: - Per-Partner Limits (each partner sets their own)

    /// Sync MY limits to CloudKit so my partner can see and approve them
    func syncMyLimits(_ limits: [AppLimitConfig]) async {
        guard let partner = currentPartner, let code = pairingCode else {
            connectionError = "No partner profile or pairing code — cannot sync limits"
            return
        }

        let publicDB = container.publicCloudDatabase
        let recordID = CKRecord.ID(recordName: "limits_\(code)_\(partner.id)")

        // Retry up to 3 times for oplock conflicts
        for attempt in 1...3 {
            do {
                let record: CKRecord
                do {
                    record = try await publicDB.record(for: recordID)
                } catch {
                    record = CKRecord(recordType: "PartnerLimits", recordID: recordID)
                }

                if let data = try? JSONEncoder().encode(limits) {
                    record["limitsData"] = data
                }
                record["pairingCode"] = code
                record["partnerId"] = partner.id
                record["partnerName"] = partner.displayName
                record["updatedAt"] = Date()

                try await publicDB.save(record)
                connectionError = nil  // Clear any previous sync error
                print("[CloudKit] Synced my limits (\(limits.count) apps)")
                return  // Success
            } catch let ckError as CKError where ckError.code == .serverRecordChanged {
                print("[CloudKit] Oplock conflict syncing limits (attempt \(attempt)/3), retrying...")
                if attempt < 3 {
                    try? await Task.sleep(nanoseconds: UInt64(attempt) * 500_000_000)
                    continue
                }
                connectionError = "Failed to sync limits — please try again."
                print("[CloudKit] Failed to sync limits after 3 attempts due to record conflicts")
            } catch {
                connectionError = "Failed to sync limits: \(error.localizedDescription)"
                print("[CloudKit] Failed to sync my limits: \(error)")
                return
            }
        }
    }

    /// Fetch my PARTNER's limits from CloudKit
    func fetchPartnerLimits() async -> [AppLimitConfig]? {
        guard let remoteId = remotePartner?.id, let code = pairingCode else {
            print("[CloudKit] Cannot fetch partner limits: remotePartner=\(remotePartner != nil), code=\(pairingCode != nil)")
            return nil
        }

        let publicDB = container.publicCloudDatabase
        let recordID = CKRecord.ID(recordName: "limits_\(code)_\(remoteId)")

        do {
            let record = try await publicDB.record(for: recordID)
            if let data = record["limitsData"] as? Data,
               let limits = try? JSONDecoder().decode([AppLimitConfig].self, from: data) {
                return limits
            }
        } catch {
            // Partner hasn't submitted limits yet
            return nil
        }
        return nil
    }

    /// Fetch MY OWN limits from CloudKit (to verify they were synced)
    func fetchMyLimits() async -> [AppLimitConfig]? {
        guard let partner = currentPartner, let code = pairingCode else { return nil }

        let publicDB = container.publicCloudDatabase
        let recordID = CKRecord.ID(recordName: "limits_\(code)_\(partner.id)")

        do {
            let record = try await publicDB.record(for: recordID)
            if let data = record["limitsData"] as? Data,
               let limits = try? JSONDecoder().decode([AppLimitConfig].self, from: data) {
                return limits
            }
        } catch {
            print("[CloudKit] Failed to fetch my limits for verification: \(error)")
        }
        return nil
    }

    /// Record that I approve my partner's limits
    func setApprovalStatus(approved: Bool) async {
        guard let partner = currentPartner, let code = pairingCode else { return }

        let publicDB = container.publicCloudDatabase
        let recordID = CKRecord.ID(recordName: "limitApproval_\(code)_\(partner.id)")

        do {
            let record: CKRecord
            do {
                record = try await publicDB.record(for: recordID)
            } catch {
                record = CKRecord(recordType: "LimitApproval", recordID: recordID)
            }

            record["pairingCode"] = code
            record["approverId"] = partner.id
            record["approved"] = approved
            record["updatedAt"] = Date()

            try await publicDB.save(record)
            print("[CloudKit] I \(approved ? "approved" : "rejected") partner's limits")
        } catch {
            print("[CloudKit] Failed to set approval: \(error)")
        }
    }

    /// Check if my partner approved MY limits
    func fetchPartnerApproval() async -> Bool {
        guard let remoteId = remotePartner?.id, let code = pairingCode else {
            print("[CloudKit] Cannot check partner approval: remotePartner=\(remotePartner != nil), code=\(pairingCode != nil)")
            return false
        }

        let publicDB = container.publicCloudDatabase
        let recordID = CKRecord.ID(recordName: "limitApproval_\(code)_\(remoteId)")

        do {
            let record = try await publicDB.record(for: recordID)
            return record["approved"] as? Bool ?? false
        } catch {
            return false
        }
    }

    // MARK: - Usage Sync

    /// Push this partner's current usage to CloudKit
    func syncUsage(appBundleId: String, minutesUsed: Int) async {
        guard let partner = currentPartner, let code = pairingCode else { return }

        let publicDB = container.publicCloudDatabase
        let dateStr = ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: Date()))
        let recordID = CKRecord.ID(recordName: "usage_\(code)_\(partner.id)_\(appBundleId)_\(dateStr)")

        do {
            // Fetch existing record or create new one
            let record: CKRecord
            do {
                record = try await publicDB.record(for: recordID)
            } catch {
                record = CKRecord(recordType: "Usage", recordID: recordID)
                record["pairingCode"] = code
                record["partnerId"] = partner.id
                record["appBundleId"] = appBundleId
                record["date"] = dateStr
            }

            record["minutesUsed"] = minutesUsed
            record["updatedAt"] = Date()

            try await publicDB.save(record)
        } catch {
            print("[CloudKit] Failed to sync usage for \(appBundleId): \(error)")
        }
    }

    /// Fetch partner's usage data
    func fetchPartnerUsage() async {
        guard let partner = currentPartner,
              let remoteId = remotePartner?.id,
              let code = pairingCode else { return }

        let publicDB = container.publicCloudDatabase
        let dateStr = ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: Date()))

        let predicate = NSPredicate(format: "pairingCode == %@ AND partnerId == %@ AND date == %@", code, remoteId, dateStr)
        let query = CKQuery(recordType: "Usage", predicate: predicate)

        do {
            let (results, _) = try await publicDB.records(matching: query)
            var usage: [String: Int] = [:]

            for (_, result) in results {
                if let record = try? result.get(),
                   let bundleId = record["appBundleId"] as? String,
                   let minutes = record["minutesUsed"] as? Int {
                    usage[bundleId] = minutes
                }
            }

            partnerUsage = usage
        } catch {
            print("[CloudKit] Failed to fetch partner usage: \(error)")
        }
    }

    // MARK: - Approval Requests

    /// Send an approval request to partner (when you hit your limit)
    func sendApprovalRequest(appBundleId: String, appDisplayName: String) async {
        guard let partner = currentPartner,
              let remote = remotePartner,
              let code = pairingCode else { return }

        let publicDB = container.publicCloudDatabase
        let request = ApprovalRequest(
            requesterId: partner.id,
            approverId: remote.id,
            appBundleId: appBundleId,
            appDisplayName: appDisplayName
        )

        let record = CKRecord(recordType: "ApprovalRequest", recordID: CKRecord.ID(recordName: request.id.uuidString))
        record["pairingCode"] = code
        record["requesterId"] = request.requesterId
        record["approverId"] = request.approverId
        record["appBundleId"] = request.appBundleId
        record["appDisplayName"] = request.appDisplayName
        record["requestedAt"] = request.requestedAt
        record["status"] = request.status.rawValue

        do {
            try await publicDB.save(record)
            print("[CloudKit] Approval request sent for \(appDisplayName)")

            // Also send a push notification
            await sendPushNotification(
                to: remote,
                title: "Screen Time Request",
                body: "\(partner.displayName) wants more time on \(appDisplayName). Approve?"
            )
        } catch {
            print("[CloudKit] Failed to send approval: \(error)")
        }
    }

    /// Respond to a pending approval request
    func respondToApproval(requestId: String, approved: Bool, extraMinutes: Int = 15) async {
        let publicDB = container.publicCloudDatabase
        let recordID = CKRecord.ID(recordName: requestId)

        do {
            let record = try await publicDB.record(for: recordID)
            record["status"] = approved ? ApprovalStatus.approved.rawValue : ApprovalStatus.denied.rawValue
            record["respondedAt"] = Date()
            if approved {
                record["extraMinutesGranted"] = extraMinutes
            }

            try await publicDB.save(record)
            pendingApproval = nil

            // Notify the requester
            let requesterName = record["requesterId"] as? String ?? ""
            let appName = record["appDisplayName"] as? String ?? "the app"

            if let remote = remotePartner {
                await sendPushNotification(
                    to: remote,
                    title: approved ? "Time Approved!" : "Time Denied 🌱",
                    body: approved
                        ? "You got \(extraMinutes) more minutes on \(appName)"
                        : "Time to put the phone down! Your garden is growing."
                )
            }

            print("[CloudKit] Approval response: \(approved ? "approved" : "denied")")
        } catch {
            print("[CloudKit] Failed to respond to approval: \(error)")
        }
    }

    /// Check for pending approval requests aimed at this user
    func checkPendingApprovals() async {
        guard let partner = currentPartner, let code = pairingCode else { return }

        let publicDB = container.publicCloudDatabase
        let predicate = NSPredicate(format: "pairingCode == %@ AND approverId == %@ AND status == %@",
                                     code, partner.id, ApprovalStatus.pending.rawValue)
        let query = CKQuery(recordType: "ApprovalRequest", predicate: predicate)

        do {
            let (results, _) = try await publicDB.records(matching: query)

            if let (_, result) = results.first,
               let record = try? result.get() {
                let request = ApprovalRequest(
                    requesterId: record["requesterId"] as? String ?? "",
                    approverId: record["approverId"] as? String ?? "",
                    appBundleId: record["appBundleId"] as? String ?? "",
                    appDisplayName: record["appDisplayName"] as? String ?? ""
                )
                pendingApproval = request
            }
        } catch {
            print("[CloudKit] Failed to check approvals: \(error)")
        }
    }

    // MARK: - Limit Proposals

    /// Send a limit change proposal to partner
    func sendLimitProposal(_ proposal: LimitProposal) async {
        guard let partner = currentPartner,
              let remote = remotePartner,
              let code = pairingCode else { return }

        let publicDB = container.publicCloudDatabase
        let record = CKRecord(recordType: "LimitProposal", recordID: CKRecord.ID(recordName: proposal.id.uuidString))
        record["pairingCode"] = code
        record["proposerId"] = partner.id
        record["approverId"] = remote.id
        record["appBundleId"] = proposal.appBundleId
        record["appName"] = proposal.appName
        record["currentLimit"] = proposal.currentLimit
        record["proposedLimit"] = proposal.proposedLimit
        record["status"] = "pending"
        record["createdAt"] = Date()

        do {
            try await publicDB.save(record)
            print("[CloudKit] Limit proposal sent for \(proposal.appName): \(proposal.currentLimit) -> \(proposal.proposedLimit)")

            await sendPushNotification(
                to: remote,
                title: "Limit Change Proposed",
                body: "\(partner.displayName) wants to change \(proposal.appName) to \(proposal.proposedLimit) min/day"
            )
        } catch {
            print("[CloudKit] Failed to send limit proposal: \(error)")
        }
    }

    /// Fetch pending limit proposals aimed at this user (partner wants to change a limit)
    func fetchPendingLimitProposals() async -> LimitProposal? {
        guard let partner = currentPartner, let code = pairingCode else { return nil }

        let publicDB = container.publicCloudDatabase
        let predicate = NSPredicate(format: "pairingCode == %@ AND approverId == %@ AND status == %@",
                                     code, partner.id, "pending")
        let query = CKQuery(recordType: "LimitProposal", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]

        do {
            let (results, _) = try await publicDB.records(matching: query, resultsLimit: 1)

            guard let (_, result) = results.first,
                  let record = try? result.get() else { return nil }

            let proposal = LimitProposal(
                appBundleId: record["appBundleId"] as? String ?? "",
                appName: record["appName"] as? String ?? "",
                currentLimit: record["currentLimit"] as? Int ?? 0,
                proposedLimit: record["proposedLimit"] as? Int ?? 0,
                proposerId: record["proposerId"] as? String ?? ""
            )
            return proposal
        } catch {
            print("[CloudKit] Failed to fetch pending limit proposals: \(error)")
            return nil
        }
    }

    /// Fetch limit proposals that THIS user sent and that partner has accepted (adds, changes, removals)
    func fetchAcceptedProposals() async -> [LimitProposal] {
        guard let partner = currentPartner, let code = pairingCode else { return [] }

        let publicDB = container.publicCloudDatabase
        let predicate = NSPredicate(format: "pairingCode == %@ AND proposerId == %@ AND status == %@",
                                     code, partner.id, "accepted")
        let query = CKQuery(recordType: "LimitProposal", predicate: predicate)

        do {
            let (results, _) = try await publicDB.records(matching: query)

            var proposals: [LimitProposal] = []
            for (_, result) in results {
                guard let record = try? result.get() else { continue }
                proposals.append(LimitProposal(
                    appBundleId: record["appBundleId"] as? String ?? "",
                    appName: record["appName"] as? String ?? "",
                    currentLimit: record["currentLimit"] as? Int ?? 0,
                    proposedLimit: record["proposedLimit"] as? Int ?? 0,
                    proposerId: record["proposerId"] as? String ?? ""
                ))
                // Clean up: mark as "completed" so we don't process it again
                record["status"] = "completed"
                try? await publicDB.save(record)
            }
            return proposals
        } catch {
            print("[CloudKit] Failed to fetch accepted proposals: \(error)")
            return []
        }
    }

    /// Mark a limit proposal as accepted or rejected
    func respondToLimitProposal(proposalId: String, accepted: Bool) async {
        let publicDB = container.publicCloudDatabase

        guard let code = pairingCode, let partner = currentPartner else { return }

        // Only update the most recent pending proposal (not all of them)
        let predicate = NSPredicate(format: "pairingCode == %@ AND approverId == %@ AND status == %@",
                                     code, partner.id, "pending")
        let query = CKQuery(recordType: "LimitProposal", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        do {
            let (results, _) = try await publicDB.records(matching: query, resultsLimit: 1)

            if let (_, result) = results.first,
               let record = try? result.get() {
                record["status"] = accepted ? "accepted" : "rejected"
                record["respondedAt"] = Date()
                try await publicDB.save(record)
                print("[CloudKit] Limit proposal \(accepted ? "accepted" : "rejected")")
            }
        } catch {
            print("[CloudKit] Failed to respond to limit proposal: \(error)")
        }
    }

    // MARK: - Goal Proposal Sync

    /// Save a goal proposal to CloudKit (limits for both partners)
    func syncGoalProposal(_ proposal: GoalProposal) async {
        guard let code = pairingCode else { return }

        let publicDB = container.publicCloudDatabase
        let recordID = CKRecord.ID(recordName: "proposal_\(code)_\(proposal.round)")

        do {
            let record: CKRecord
            do {
                record = try await publicDB.record(for: recordID)
            } catch {
                record = CKRecord(recordType: "GoalProposal", recordID: recordID)
            }

            let encoder = JSONEncoder()
            if let proposerData = try? encoder.encode(proposal.proposerLimits) {
                record["proposerLimitsData"] = proposerData
            }
            if let partnerData = try? encoder.encode(proposal.partnerLimits) {
                record["partnerLimitsData"] = partnerData
            }
            record["pairingCode"] = code
            record["proposerId"] = proposal.proposerId
            record["round"] = proposal.round
            record["status"] = proposal.status.rawValue
            record["checkInFrequency"] = proposal.checkInFrequency.rawValue
            record["updatedAt"] = Date()

            try await publicDB.save(record)
            print("[CloudKit] Synced goal proposal round \(proposal.round)")
        } catch {
            print("[CloudKit] Failed to sync goal proposal: \(error)")
        }
    }

    /// Fetch the latest goal proposal for this couple
    func fetchLatestProposal() async -> GoalProposal? {
        guard let code = pairingCode else { return nil }

        let publicDB = container.publicCloudDatabase
        let predicate = NSPredicate(format: "pairingCode == %@", code)
        let query = CKQuery(recordType: "GoalProposal", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "round", ascending: false)]

        do {
            let (results, _) = try await publicDB.records(matching: query, resultsLimit: 1)

            guard let (_, result) = results.first,
                  let record = try? result.get() else { return nil }

            let decoder = JSONDecoder()
            let proposerLimits: [AppLimitConfig] = {
                guard let data = record["proposerLimitsData"] as? Data,
                      let limits = try? decoder.decode([AppLimitConfig].self, from: data) else { return [] }
                return limits
            }()
            let partnerLimits: [AppLimitConfig] = {
                guard let data = record["partnerLimitsData"] as? Data,
                      let limits = try? decoder.decode([AppLimitConfig].self, from: data) else { return [] }
                return limits
            }()

            let proposerId = record["proposerId"] as? String ?? ""
            let round = record["round"] as? Int ?? 1
            let statusStr = record["status"] as? String ?? "pending"
            let status = GoalProposal.ProposalStatus(rawValue: statusStr) ?? .pending
            let freqStr = record["checkInFrequency"] as? String ?? "weekly"
            let freq = CheckInFrequency(rawValue: freqStr) ?? .weekly

            var proposal = GoalProposal(
                proposerLimits: proposerLimits,
                partnerLimits: partnerLimits,
                proposerId: proposerId,
                round: round,
                checkInFrequency: freq
            )
            proposal.status = status
            return proposal
        } catch {
            print("[CloudKit] Failed to fetch proposal: \(error)")
            return nil
        }
    }

    /// Mark the latest proposal as approved
    func approveProposal(round: Int) async {
        guard let code = pairingCode else { return }

        let publicDB = container.publicCloudDatabase
        let recordID = CKRecord.ID(recordName: "proposal_\(code)_\(round)")

        do {
            let record = try await publicDB.record(for: recordID)
            record["status"] = GoalProposal.ProposalStatus.approved.rawValue
            record["updatedAt"] = Date()
            try await publicDB.save(record)
            print("[CloudKit] Proposal round \(round) approved")
        } catch {
            print("[CloudKit] Failed to approve proposal: \(error)")
        }
    }

    /// Save check-in frequency to the couple record
    func syncCheckInFrequency(_ frequency: CheckInFrequency) async {
        guard let code = pairingCode else { return }

        let publicDB = container.publicCloudDatabase
        let predicate = NSPredicate(format: "pairingCode == %@", code)
        let query = CKQuery(recordType: "Couple", predicate: predicate)

        do {
            let (results, _) = try await publicDB.records(matching: query)
            guard let (_, result) = results.first,
                  let record = try? result.get() else { return }

            record["checkInFrequency"] = frequency.rawValue
            try await publicDB.save(record)
            print("[CloudKit] Check-in frequency set to \(frequency.rawValue)")
        } catch {
            print("[CloudKit] Failed to sync check-in frequency: \(error)")
        }
    }

    // MARK: - Garden Sync

    /// Sync garden state to CloudKit (includes unlocked plant types)
    func syncGarden(plants: [GardenPlant], streak: Int, unlockedPlantTypes: [String] = ["daisy", "tulip"]) async {
        guard let code = pairingCode else { return }

        let publicDB = container.publicCloudDatabase
        let recordID = CKRecord.ID(recordName: "garden_\(code)")

        do {
            // Fetch existing record or create new one
            let record: CKRecord
            do {
                record = try await publicDB.record(for: recordID)
            } catch {
                record = CKRecord(recordType: "Garden", recordID: recordID)
            }

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            if let data = try? encoder.encode(plants) {
                record["plantsData"] = data
            }
            record["pairingCode"] = code
            record["currentStreak"] = streak
            record["unlockedPlantTypes"] = unlockedPlantTypes
            record["updatedAt"] = Date()

            try await publicDB.save(record)
        } catch {
            print("[CloudKit] Failed to sync garden: \(error)")
        }
    }

    /// Fetch garden from CloudKit (includes unlocked plant types)
    func fetchGarden() async -> (plants: [GardenPlant], streak: Int, unlockedPlantTypes: [String])? {
        guard let code = pairingCode else { return nil }

        let publicDB = container.publicCloudDatabase
        let recordID = CKRecord.ID(recordName: "garden_\(code)")

        do {
            let record = try await publicDB.record(for: recordID)
            let streak = record["currentStreak"] as? Int ?? 0
            let unlockedTypes = record["unlockedPlantTypes"] as? [String] ?? ["daisy", "tulip"]

            if let data = record["plantsData"] as? Data {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                if let plants = try? decoder.decode([GardenPlant].self, from: data) {
                    return (plants, streak, unlockedTypes)
                }
            }
        } catch {
            print("[CloudKit] Failed to fetch garden: \(error)")
        }
        return nil
    }

    // MARK: - Real-time Subscriptions

    /// Subscribe to Couple record changes only.
    /// Called by the creator immediately after generating a pairing code so they
    /// get a push notification the moment partner2 joins.
    func subscribeToCoupleChanges() async {
        guard let code = pairingCode else { return }

        let publicDB = container.publicCloudDatabase

        // Remove any existing Couple subscription to avoid duplicates
        do {
            let existingSubs = try await publicDB.allSubscriptions()
            for sub in existingSubs where sub.subscriptionID == "coupleSub_\(code)" {
                try? await publicDB.deleteSubscription(withID: sub.subscriptionID)
            }
        } catch {
            print("[CloudKit] Could not clean old couple subscription: \(error)")
        }

        let predicate = NSPredicate(format: "pairingCode == %@", code)
        let coupleSub = CKQuerySubscription(
            recordType: "Couple",
            predicate: predicate,
            subscriptionID: "coupleSub_\(code)",
            options: [.firesOnRecordUpdate]
        )

        let notification = CKSubscription.NotificationInfo()
        notification.shouldSendContentAvailable = true
        notification.alertBody = "Your partner joined the garden!"
        coupleSub.notificationInfo = notification

        do {
            try await publicDB.save(coupleSub)
            print("[CloudKit] Subscribed to Couple record changes (waiting for partner)")
        } catch {
            print("[CloudKit] Couple subscription error: \(error)")
        }
    }

    /// Subscribe to CloudKit changes for real-time partner updates.
    /// Removes any existing subscriptions first to avoid duplicates.
    func subscribeToChanges() async {
        guard let code = pairingCode else { return }

        let publicDB = container.publicCloudDatabase

        // Remove only this couple's existing subscriptions to prevent duplicates
        // (Don't delete ALL subscriptions — that would remove other users' subs)
        do {
            let existingSubs = try await publicDB.allSubscriptions()
            for sub in existingSubs where sub.subscriptionID.contains(code) {
                try? await publicDB.deleteSubscription(withID: sub.subscriptionID)
            }
        } catch {
            print("[CloudKit] Could not clean old subscriptions: \(error)")
        }

        let sharedPredicate = NSPredicate(format: "pairingCode == %@", code)
        let notification = CKSubscription.NotificationInfo()
        notification.shouldSendContentAvailable = true
        notification.alertBody = "New screen time request from your partner!"

        // Subscribe to Couple record changes (partner joining, etc.)
        let coupleSub = CKQuerySubscription(
            recordType: "Couple",
            predicate: sharedPredicate,
            subscriptionID: "coupleSub_\(code)",
            options: [.firesOnRecordUpdate]
        )
        let coupleNotif = CKSubscription.NotificationInfo()
        coupleNotif.shouldSendContentAvailable = true
        coupleNotif.alertBody = "Your partner joined the garden!"
        coupleSub.notificationInfo = coupleNotif

        // Subscribe to approval requests
        let approvalSub = CKQuerySubscription(
            recordType: "ApprovalRequest",
            predicate: sharedPredicate,
            subscriptionID: "approvalSub_\(code)",
            options: [.firesOnRecordCreation, .firesOnRecordUpdate]
        )
        approvalSub.notificationInfo = notification

        // Subscribe to usage updates
        let usageSub = CKQuerySubscription(
            recordType: "Usage",
            predicate: sharedPredicate,
            subscriptionID: "usageSub_\(code)",
            options: [.firesOnRecordCreation, .firesOnRecordUpdate]
        )
        usageSub.notificationInfo = notification

        // Subscribe to limit proposals
        let proposalSub = CKQuerySubscription(
            recordType: "LimitProposal",
            predicate: sharedPredicate,
            subscriptionID: "proposalSub_\(code)",
            options: [.firesOnRecordCreation, .firesOnRecordUpdate]
        )
        proposalSub.notificationInfo = notification

        // Subscribe to limit suggestions (per-partner suggestions)
        let suggestionSub = CKQuerySubscription(
            recordType: "LimitSuggestion",
            predicate: sharedPredicate,
            subscriptionID: "suggestionSub_\(code)",
            options: [.firesOnRecordCreation, .firesOnRecordUpdate]
        )
        let suggestionNotif = CKSubscription.NotificationInfo()
        suggestionNotif.shouldSendContentAvailable = true
        suggestionNotif.alertBody = "Your partner suggested a limit change!"
        suggestionSub.notificationInfo = suggestionNotif

        // Subscribe to partner limits (setup flow — detect when partner submits their limits)
        let partnerLimitsSub = CKQuerySubscription(
            recordType: "PartnerLimits",
            predicate: sharedPredicate,
            subscriptionID: "partnerLimitsSub_\(code)",
            options: [.firesOnRecordCreation, .firesOnRecordUpdate]
        )
        partnerLimitsSub.notificationInfo = notification

        // Subscribe to limit approvals (setup flow — detect when partner approves your limits)
        let limitApprovalSub = CKQuerySubscription(
            recordType: "LimitApproval",
            predicate: sharedPredicate,
            subscriptionID: "limitApprovalSub_\(code)",
            options: [.firesOnRecordCreation, .firesOnRecordUpdate]
        )
        limitApprovalSub.notificationInfo = notification

        do {
            try await publicDB.save(coupleSub)
            try await publicDB.save(approvalSub)
            try await publicDB.save(usageSub)
            try await publicDB.save(proposalSub)
            try await publicDB.save(suggestionSub)
            try await publicDB.save(partnerLimitsSub)
            try await publicDB.save(limitApprovalSub)
            print("[CloudKit] Subscribed to real-time updates (couple, approval, usage, proposals, suggestions, partnerLimits, limitApproval)")
        } catch {
            print("[CloudKit] Subscription error: \(error)")
        }
    }

    // MARK: - Push Notifications

    /// Send a push notification to a partner via CloudKit
    private func sendPushNotification(to partner: PartnerProfile, title: String, body: String) async {
        // CloudKit subscriptions handle push delivery automatically
        // The notification info on the subscription triggers APNs
        // This is handled by the subscribeToChanges() method above
        print("[CloudKit] Push notification queued: \(title)")
    }

    /// Register this device's push token with CloudKit
    func registerPushToken(_ token: Data) async {
        guard let partner = currentPartner else { return }
        let tokenString = token.map { String(format: "%02.2hhx", $0) }.joined()

        var updatedPartner = partner
        updatedPartner.deviceToken = tokenString
        currentPartner = updatedPartner
        saveLocalProfile(updatedPartner)

        print("[CloudKit] Push token registered")
    }

    // MARK: - Local Storage Helpers

    private func saveLocalProfile(_ profile: PartnerProfile) {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: "partnerProfile")
        }
    }

    private func loadLocalProfile() -> PartnerProfile? {
        guard let data = UserDefaults.standard.data(forKey: "partnerProfile"),
              let profile = try? JSONDecoder().decode(PartnerProfile.self, from: data) else {
            return nil
        }
        return profile
    }

    private func generatePairingCode() -> String {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789" // No confusing chars (0/O, 1/I)
        return String((0..<6).compactMap { _ in chars.randomElement() })
    }

    // MARK: - Limit Suggestions

    /// Save a limit suggestion to CloudKit
    func syncLimitSuggestion(_ suggestion: LimitSuggestion) async {
        guard let code = pairingCode else { return }

        let publicDB = container.publicCloudDatabase
        let recordID = CKRecord.ID(recordName: "suggestion_\(suggestion.id.uuidString)")
        let record = CKRecord(recordType: "LimitSuggestion", recordID: recordID)

        record["pairingCode"] = code
        record["fromPartnerId"] = suggestion.fromPartnerId
        record["toPartnerId"] = suggestion.toPartnerId
        record["appBundleId"] = suggestion.appBundleId
        record["appDisplayName"] = suggestion.appDisplayName
        record["suggestedMinutes"] = suggestion.suggestedMinutes
        record["currentMinutes"] = suggestion.currentMinutes
        record["status"] = suggestion.status.rawValue
        record["createdAt"] = suggestion.createdAt

        do {
            try await publicDB.save(record)
            print("[CloudKit] Saved limit suggestion for \(suggestion.appDisplayName)")
        } catch {
            print("[CloudKit] Failed to save limit suggestion: \(error)")
        }
    }

    /// Fetch pending limit suggestions sent TO the current user
    func fetchPendingLimitSuggestions() async -> [LimitSuggestion] {
        guard let partner = currentPartner, let code = pairingCode else { return [] }

        let publicDB = container.publicCloudDatabase
        let predicate = NSPredicate(
            format: "pairingCode == %@ AND toPartnerId == %@ AND status == %@",
            code, partner.id, SuggestionStatus.pending.rawValue
        )
        let query = CKQuery(recordType: "LimitSuggestion", predicate: predicate)

        do {
            let (results, _) = try await publicDB.records(matching: query)
            var suggestions: [LimitSuggestion] = []

            for (_, result) in results {
                guard let record = try? result.get() else { continue }

                let suggestion = LimitSuggestion(
                    fromPartnerId: record["fromPartnerId"] as? String ?? "",
                    toPartnerId: record["toPartnerId"] as? String ?? "",
                    appBundleId: record["appBundleId"] as? String ?? "",
                    appDisplayName: record["appDisplayName"] as? String ?? "",
                    suggestedMinutes: record["suggestedMinutes"] as? Int ?? 60,
                    currentMinutes: record["currentMinutes"] as? Int ?? 60
                )
                suggestions.append(suggestion)
            }

            return suggestions
        } catch {
            print("[CloudKit] Failed to fetch limit suggestions: \(error)")
        }
        return []
    }

    /// Respond to a limit suggestion (accept or reject)
    func respondToLimitSuggestion(id: String, accepted: Bool) async {
        guard let code = pairingCode else { return }

        let publicDB = container.publicCloudDatabase

        // Find the suggestion record by querying — match by the specific ID first
        let predicate = NSPredicate(format: "pairingCode == %@", code)
        let query = CKQuery(recordType: "LimitSuggestion", predicate: predicate)

        do {
            let (results, _) = try await publicDB.records(matching: query)

            // First pass: try to match by exact ID
            for (_, result) in results {
                guard let record = try? result.get() else { continue }

                if record.recordID.recordName.contains(id) {
                    record["status"] = accepted ? SuggestionStatus.accepted.rawValue : SuggestionStatus.rejected.rawValue
                    record["respondedAt"] = Date()
                    try await publicDB.save(record)
                    print("[CloudKit] Responded to limit suggestion by ID: \(accepted ? "accepted" : "rejected")")
                    return
                }
            }

            // Fallback: update the most recent pending suggestion only
            for (_, result) in results {
                guard let record = try? result.get() else { continue }

                if record["status"] as? String == SuggestionStatus.pending.rawValue {
                    record["status"] = accepted ? SuggestionStatus.accepted.rawValue : SuggestionStatus.rejected.rawValue
                    record["respondedAt"] = Date()
                    try await publicDB.save(record)
                    print("[CloudKit] Responded to limit suggestion (fallback): \(accepted ? "accepted" : "rejected")")
                    return
                }
            }
        } catch {
            print("[CloudKit] Failed to respond to limit suggestion: \(error)")
        }
    }
}
