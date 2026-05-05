import SwiftUI
import FamilyControls
import UserNotifications

// MARK: - Notification Names for CloudKit Push Events
extension Notification.Name {
    static let partnerJoinedNotification = Notification.Name("partnerJoinedNotification")
    static let cloudKitDataChanged = Notification.Name("cloudKitDataChanged")
}

@main
struct UnplugTogetherApp: App {
    @StateObject private var viewModel = AppViewModel()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .onOpenURL { url in
                    viewModel.handleDeepLink(url)
                }
        }
    }
}

// MARK: - App Delegate for Push Notifications
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task {
            await CloudKitManager.shared.registerPushToken(deviceToken)
        }
    }

    /// Handle silent push notifications from CloudKit subscriptions.
    /// This fires when a CKQuerySubscription with shouldSendContentAvailable triggers.
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        // CloudKit silent push — trigger a sync check
        let ck = userInfo["ck"] as? [String: Any]
        let recordType = (ck?["qry"] as? [String: Any])?["rt"] as? String

        print("[Push] Received silent push for record type: \(recordType ?? "unknown")")

        if recordType == "Couple" {
            // Partner may have joined — post notification so the waiting view can react
            NotificationCenter.default.post(name: .partnerJoinedNotification, object: nil)
        }

        // Trigger a general sync for any CloudKit change
        NotificationCenter.default.post(name: .cloudKitDataChanged, object: nil)

        completionHandler(.newData)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        if response.notification.request.content.categoryIdentifier == "APPROVAL_REQUEST",
           let requestId = userInfo["requestId"] as? String {

            let appBundleId = userInfo["appBundleId"] as? String ?? ""

            Task {
                switch response.actionIdentifier {
                case "APPROVE":
                    // Tell CloudKit the request was approved.
                    // The REQUESTER's device will detect the approval via
                    // checkMyApprovalResponses() and unblock apps on their side.
                    // Do NOT call grantExtension() here — this runs on the
                    // APPROVER's device and would corrupt their own limits.
                    await CloudKitManager.shared.respondToApproval(requestId: requestId, approved: true)
                case "DENY":
                    await CloudKitManager.shared.respondToApproval(requestId: requestId, approved: false)
                default:
                    break
                }
            }
        }

        completionHandler()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .badge, .sound])
    }
}

// MARK: - Root Content View
struct ContentView: View {
    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        ZStack {
            Color(hex: AppTheme.cream).ignoresSafeArea()

            switch vm.state {
            case .setup:
                SetupNameView()
            case .avatarPicker:
                AvatarPickerView()
            case .pairing:
                PairingView()
            case .waitingForPartner:
                WaitingForPartnerView()
            case .pickMyLimits:
                PickMyLimitsView()
            case .waitingForBothLimits:
                WaitingForBothLimitsView()
            case .reviewPartnerLimits:
                ReviewPartnerLimitsView()
            case .home:
                MainTabView()
            }

            // Approval overlay
            if vm.showApprovalModal {
                ApprovalModalView()
            }

            // Limit proposal overlay
            if vm.showLimitProposal {
                LimitProposalModal()
            }

            // Limit suggestion overlay (per-partner suggestions)
            if vm.pendingLimitSuggestion != nil {
                LimitSuggestionModalView()
            }
        }
        .fontDesign(.rounded)
        .alert("Oops", isPresented: Binding(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )) {
            Button("OK") { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: .init(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)

        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double(rgbValue & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
