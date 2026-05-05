import SwiftUI
import FamilyControls

// MARK: - Approval Modal
struct ApprovalModalView: View {
    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { /* block dismissal */ }

            VStack(spacing: 20) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 40))
                    .foregroundColor(Color(hex: AppTheme.roseDark))

                Text("time's up!")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundColor(Color(hex: AppTheme.charcoal))

                if let approval = vm.currentApproval {
                    let requesterName = approval.requesterId == CloudKitManager.shared.currentPartner?.id
                        ? vm.myName
                        : vm.partnerName

                    Text("\(requesterName) hit their")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(Color(hex: AppTheme.bark).opacity(0.5))

                    let app = vm.appLimits.first { $0.bundleIdentifier == approval.appBundleId }
                    if let app = app {
                        HStack(spacing: 8) {
                            AppBrandIcon(bundleId: app.bundleIdentifier, size: 28)
                            Text("\(app.appName) limit")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color(hex: app.colorHex).opacity(0.75))
                        .cornerRadius(14)
                    }

                    let approverName = approval.approverId == CloudKitManager.shared.currentPartner?.id
                        ? vm.myName
                        : vm.partnerName
                    Text("\(approverName), do you approve more time?")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(Color(hex: AppTheme.charcoal))
                        .multilineTextAlignment(.center)
                }

                HStack(spacing: 12) {
                    Button {
                        vm.denyRequest()
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "leaf.fill")
                                .font(.system(size: 24))
                            Text("deny")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                            Text("grow the garden!")
                                .font(.system(size: 9, weight: .medium, design: .rounded))
                                .opacity(0.8)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: AppTheme.mint), Color(hex: AppTheme.mintDark)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(20)
                        .shadow(color: Color(hex: AppTheme.mint).opacity(0.3), radius: 8, y: 4)
                    }

                    Button {
                        vm.approveRequest(extraMinutes: 15)
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "iphone")
                                .font(.system(size: 24))
                            Text("allow")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                            Text("15 more min")
                                .font(.system(size: 9, weight: .medium, design: .rounded))
                            Text("-2 days progress")
                                .font(.system(size: 8, weight: .bold, design: .rounded))
                                .foregroundColor(Color(hex: AppTheme.roseDark).opacity(0.7))
                        }
                        .foregroundColor(Color(hex: AppTheme.bark).opacity(0.5))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color(hex: AppTheme.cloud))
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color(hex: AppTheme.bark).opacity(0.1), lineWidth: 2)
                        )
                    }
                }
            }
            .padding(28)
            .background(Color.white)
            .cornerRadius(28)
            .shadow(color: Color(hex: AppTheme.bark).opacity(0.15), radius: 24, y: 12)
            .padding(20)
        }
    }
}

// MARK: - Limit Proposal Modal
struct LimitProposalModal: View {
    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        if let proposal = vm.pendingLimitProposal {
            ZStack {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    Image(systemName: "arrow.up.arrow.down.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(Color(hex: AppTheme.lavenderDark))

                    Text("limit change proposed")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundColor(Color(hex: AppTheme.charcoal))

                    Text("\(vm.partnerName) wants to change")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(Color(hex: AppTheme.bark).opacity(0.5))

                    Text(proposal.appName)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: AppTheme.roseDark))

                    HStack(spacing: 12) {
                        VStack(spacing: 4) {
                            Text("current")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(Color(hex: AppTheme.bark).opacity(0.4))
                            Text("\(proposal.currentLimit)m")
                                .font(.system(size: 22, weight: .heavy, design: .rounded))
                                .foregroundColor(Color(hex: AppTheme.charcoal))
                        }

                        Image(systemName: "arrow.right")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Color(hex: AppTheme.lavender))

                        VStack(spacing: 4) {
                            Text("proposed")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(Color(hex: AppTheme.bark).opacity(0.4))
                            Text("\(proposal.proposedLimit)m")
                                .font(.system(size: 22, weight: .heavy, design: .rounded))
                                .foregroundColor(Color(hex: AppTheme.lavenderDark))
                        }
                    }
                    .padding(.vertical, 8)

                    HStack(spacing: 12) {
                        Button {
                            vm.rejectLimitProposal()
                        } label: {
                            Text("reject")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(Color(hex: AppTheme.bark).opacity(0.5))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color(hex: AppTheme.cloud))
                                .cornerRadius(20)
                        }

                        Button {
                            vm.acceptLimitProposal()
                        } label: {
                            Text("accept")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    LinearGradient(
                                        colors: [Color(hex: AppTheme.lavender), Color(hex: AppTheme.lavenderDark)],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                )
                                .cornerRadius(20)
                        }
                    }
                }
                .padding(28)
                .background(Color.white)
                .cornerRadius(28)
                .shadow(color: Color(hex: AppTheme.bark).opacity(0.15), radius: 24, y: 12)
                .padding(20)
            }
        }
    }
}

// MARK: - Limits Settings View
struct LimitsView: View {
    @EnvironmentObject var vm: AppViewModel
    let limitOptions = [15, 30, 45, 60, 90, 120]
    @State private var showAddApps = false
    @State private var proposalSentApp: String? = nil
    @State private var showSuggestSheet = false
    @State private var suggestingLimit: AppLimitConfig?

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("limits & settings")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundColor(Color(hex: AppTheme.charcoal))
                Text("your limits & \(vm.partnerName)'s limits")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(Color(hex: AppTheme.bark).opacity(0.5))
            }
            .padding(.top, 8)

            // SECTION: MY LIMITS
            HStack {
                Text("my limits")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundColor(Color(hex: AppTheme.roseDark))
                    .textCase(.uppercase)
                Spacer()
            }
            .padding(.top, 4)

            // Current app limits
            if vm.appLimits.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "app.dashed")
                        .font(.system(size: 32))
                        .foregroundColor(Color(hex: AppTheme.bark).opacity(0.2))
                    Text("no apps tracked yet")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(Color(hex: AppTheme.bark).opacity(0.4))
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .background(Color.white)
                .cornerRadius(20)
                .shadow(color: Color(hex: AppTheme.bark).opacity(0.05), radius: 8, y: 3)
            } else {
                ForEach(vm.appLimits) { limit in
                    LimitSettingCard(
                        limit: limit,
                        limitOptions: limitOptions,
                        proposalSent: proposalSentApp == limit.bundleIdentifier,
                        pendingChange: vm.pendingLimitChangeProposals.contains(limit.bundleIdentifier),
                        pendingRemoval: vm.pendingRemovalProposals.contains(limit.bundleIdentifier),
                        onPropose: { mins in
                            vm.proposeLimitChange(appId: limit.bundleIdentifier, newLimit: mins)
                            proposalSentApp = limit.bundleIdentifier
                            // Clear "sent" indicator after 3 seconds
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                if proposalSentApp == limit.bundleIdentifier {
                                    proposalSentApp = nil
                                }
                            }
                        },
                        onRemove: {
                            vm.removeAppLimit(appId: limit.bundleIdentifier)
                        }
                    )
                }
            }

            // Add / Change tracked apps button
            Button {
                showAddApps = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                    Text("add or change tracked apps")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .foregroundColor(Color(hex: AppTheme.lavenderDark))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.white)
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color(hex: AppTheme.lavender).opacity(0.3), lineWidth: 1.5)
                )
                .shadow(color: Color(hex: AppTheme.lavender).opacity(0.1), radius: 6, y: 3)
            }

            // SECTION: PENDING APPROVAL
            if !vm.pendingAddProposals.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "clock.badge.questionmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.orange)
                        Text("waiting for \(vm.partnerName)'s approval")
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .foregroundColor(.orange)
                            .textCase(.uppercase)
                        Spacer()
                    }

                    ForEach(Array(vm.pendingAddProposals), id: \.self) { bundleId in
                        let app = TrackedApp(rawValue: bundleId)
                        HStack(spacing: 12) {
                            AppBrandIcon(bundleId: bundleId, size: 36)
                            Text(app?.displayName ?? bundleId)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(Color(hex: AppTheme.bark))
                            Spacer()
                            Text("pending")
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                                .foregroundColor(.orange)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(8)
                        }
                        .padding(12)
                        .background(Color.white)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.orange.opacity(0.2), lineWidth: 1.5)
                        )
                    }
                }
                .padding(16)
                .background(Color.orange.opacity(0.04))
                .cornerRadius(20)
            }

            // SECTION: PARTNER'S LIMITS
            HStack {
                Text("\(vm.partnerName)'s limits")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundColor(Color(hex: AppTheme.lavenderDark))
                    .textCase(.uppercase)
                Spacer()
            }
            .padding(.top, 4)

            if vm.partnerLimits.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "person.2.slash")
                        .font(.system(size: 24))
                        .foregroundColor(Color(hex: AppTheme.bark).opacity(0.2))
                    Text("\(vm.partnerName) hasn't set limits yet")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(Color(hex: AppTheme.bark).opacity(0.4))
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .background(Color.white)
                .cornerRadius(20)
                .shadow(color: Color(hex: AppTheme.bark).opacity(0.05), radius: 8, y: 3)
            } else {
                ForEach(vm.partnerLimits) { limit in
                    PartnerLimitCard(limit: limit) {
                        suggestingLimit = limit
                        showSuggestSheet = true
                    }
                }
            }

            // Pending proposal from partner notification
            if let pending = vm.pendingLimitProposal {
                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "bell.badge.fill")
                            .foregroundColor(Color(hex: AppTheme.roseDark))
                        Text("\(vm.partnerName) proposed a change")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: AppTheme.charcoal))
                        Spacer()
                    }

                    HStack {
                        Text("\(pending.appName): \(formatMins(pending.currentLimit))")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(Color(hex: AppTheme.bark).opacity(0.5))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: AppTheme.lavender))
                        Text(formatMins(pending.proposedLimit))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: AppTheme.lavenderDark))
                        Spacer()
                    }

                    HStack(spacing: 10) {
                        Button {
                            vm.rejectLimitProposal()
                        } label: {
                            Text("decline")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(Color(hex: AppTheme.bark).opacity(0.5))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color(hex: AppTheme.cloud))
                                .cornerRadius(12)
                        }

                        Button {
                            vm.acceptLimitProposal()
                        } label: {
                            Text("approve")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    LinearGradient(
                                        colors: [Color(hex: AppTheme.mint), Color(hex: AppTheme.mintDark)],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                )
                                .cornerRadius(12)
                        }
                    }
                }
                .padding(16)
                .background(Color(hex: AppTheme.rose).opacity(0.06))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color(hex: AppTheme.rose).opacity(0.2), lineWidth: 1.5)
                )
            }


            HStack(spacing: 6) {
                Circle()
                    .fill(vm.isPaired ? Color(hex: AppTheme.mintDark) : Color(hex: AppTheme.honey))
                    .frame(width: 8, height: 8)
                Text(vm.isPaired ? "connected to \(vm.partnerName)" : "waiting for partner")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(Color(hex: AppTheme.bark).opacity(0.4))
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(20)
            .shadow(color: Color(hex: AppTheme.bark).opacity(0.05), radius: 8, y: 3)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .sheet(isPresented: $showAddApps) {
            AddAppsSheet()
                .environmentObject(vm)
        }
        .sheet(isPresented: $showSuggestSheet) {
            if let limit = suggestingLimit {
                SuggestLimitSheet(limit: limit) { suggestedMinutes in
                    vm.suggestLimitChange(
                        appBundleId: limit.bundleIdentifier,
                        appDisplayName: limit.appName,
                        suggestedMinutes: suggestedMinutes,
                        currentMinutes: limit.dailyLimitMinutes
                    )
                    showSuggestSheet = false
                }
            }
        }
        .task {
            // Poll for incoming limit proposals from partner
            while true {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                if Task.isCancelled { break }
                await vm.checkIncomingLimitProposals()
            }
        }
    }

    func formatMins(_ m: Int) -> String {
        m >= 60 ? "\(m/60)h\(m%60 > 0 ? " \(m%60)m" : "")" : "\(m)m"
    }
}

// MARK: - Add Apps Sheet (FamilyActivityPicker in a sheet)
struct AddAppsSheet: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.dismiss) var dismiss
    @State private var newAppLimits: [String: Int] = [:]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    Text("select apps to track")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundColor(Color(hex: AppTheme.charcoal))

                    Text("changes will be sent to \(vm.partnerName) for approval")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(Color(hex: AppTheme.bark).opacity(0.5))

                    FamilyActivityPicker(selection: $vm.activitySelection)
                        .frame(height: 350)
                        .cornerRadius(16)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("set limits for new apps")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: AppTheme.charcoal))

                        ForEach(TrackedApp.allCases) { app in
                            let alreadyTracked = vm.appLimits.contains(where: { $0.bundleIdentifier == app.rawValue })
                            let proposalSent = vm.pendingAddProposals.contains(app.rawValue)

                            // Only show apps not already in limits
                            if !alreadyTracked {
                                HStack(spacing: 10) {
                                    AppBrandIcon(bundleId: app.rawValue, size: 32)
                                    Text(app.displayName)
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .foregroundColor(Color(hex: AppTheme.charcoal))
                                    Spacer()

                                    if proposalSent {
                                        // Show "sent" confirmation instead of picker + button
                                        HStack(spacing: 4) {
                                            Image(systemName: "paperplane.fill")
                                                .font(.system(size: 10))
                                            Text("sent to \(vm.partnerName)!")
                                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                        }
                                        .foregroundColor(Color(hex: AppTheme.mintDark))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color(hex: AppTheme.mint).opacity(0.15))
                                        .cornerRadius(10)
                                    } else {
                                        Picker("", selection: Binding(
                                            get: { newAppLimits[app.rawValue] ?? 60 },
                                            set: { newAppLimits[app.rawValue] = $0 }
                                        )) {
                                            Text("15m").tag(15)
                                            Text("30m").tag(30)
                                            Text("45m").tag(45)
                                            Text("1h").tag(60)
                                            Text("1.5h").tag(90)
                                            Text("2h").tag(120)
                                        }
                                        .pickerStyle(.menu)
                                        .tint(Color(hex: app.colorHex))

                                        Button {
                                            let mins = newAppLimits[app.rawValue] ?? 60
                                            vm.addAppWithApproval(app: app, limitMinutes: mins)
                                        } label: {
                                            Text("add")
                                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 6)
                                                .background(Color(hex: app.colorHex).opacity(0.8))
                                                .cornerRadius(10)
                                        }
                                    }
                                }
                                .padding(12)
                                .background(Color.white)
                                .cornerRadius(14)
                                .shadow(color: Color(hex: AppTheme.bark).opacity(0.04), radius: 4, y: 2)
                                .animation(.easeInOut(duration: 0.2), value: proposalSent)
                            }
                        }
                    }
                }
                .padding(20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("done") {
                        dismiss()
                    }
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: AppTheme.lavenderDark))
                }
            }
        }
    }
}

struct LimitSettingCard: View {
    let limit: AppLimitConfig
    let limitOptions: [Int]
    var proposalSent: Bool = false
    var pendingChange: Bool = false
    var pendingRemoval: Bool = false
    let onPropose: (Int) -> Void
    var onRemove: (() -> Void)? = nil

    @State private var showCustomInput = false
    @State private var customMinutes = ""
    @State private var showRemoveConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                AppBrandIcon(bundleId: limit.bundleIdentifier, size: 36)
                Text(limit.appName)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: AppTheme.charcoal))
                Spacer()
                if pendingChange || pendingRemoval {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 10))
                        Text(pendingRemoval ? "removal pending" : "change pending")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                } else if proposalSent {
                    HStack(spacing: 4) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 10))
                        Text("sent!")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(Color(hex: AppTheme.mintDark))
                    .transition(.opacity)
                }
                Text(formatMins(limit.dailyLimitMinutes))
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundColor(Color(hex: limit.colorHex).opacity(0.8))

                // Remove button
                if let onRemove = onRemove {
                    Button {
                        showRemoveConfirm = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(Color(hex: AppTheme.bark).opacity(0.25))
                    }
                    .confirmationDialog(
                        "remove \(limit.appName)?",
                        isPresented: $showRemoveConfirm,
                        titleVisibility: .visible
                    ) {
                        Button("remove", role: .destructive) {
                            onRemove()
                        }
                        Button("cancel", role: .cancel) {}
                    } message: {
                        Text("this will stop tracking \(limit.appName)")
                    }
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(limitOptions, id: \.self) { mins in
                        Button {
                            showCustomInput = false
                            onPropose(mins)
                        } label: {
                            Text(formatMins(mins))
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    limit.dailyLimitMinutes == mins
                                        ? AnyShapeStyle(Color(hex: limit.colorHex).opacity(0.7))
                                        : AnyShapeStyle(Color(hex: AppTheme.cloud))
                                )
                                .foregroundColor(limit.dailyLimitMinutes == mins ? .white : Color(hex: AppTheme.bark).opacity(0.5))
                                .cornerRadius(10)
                        }
                    }

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showCustomInput.toggle()
                        }
                    } label: {
                        Text("custom")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                showCustomInput
                                    ? AnyShapeStyle(Color(hex: limit.colorHex).opacity(0.7))
                                    : AnyShapeStyle(Color(hex: AppTheme.cloud))
                            )
                            .foregroundColor(showCustomInput ? .white : Color(hex: AppTheme.bark).opacity(0.5))
                            .cornerRadius(10)
                    }
                }
            }

            if showCustomInput {
                HStack(spacing: 8) {
                    TextField("minutes", text: $customMinutes)
                        .keyboardType(.numberPad)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color(hex: AppTheme.cloud))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(hex: limit.colorHex).opacity(0.3), lineWidth: 1.5)
                        )
                        .frame(width: 80)

                    Text("min")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(hex: AppTheme.bark).opacity(0.4))

                    Button {
                        if let mins = Int(customMinutes), mins > 0 {
                            onPropose(mins)
                            showCustomInput = false
                        }
                    } label: {
                        Text("propose")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                Int(customMinutes) ?? 0 > 0
                                    ? Color(hex: limit.colorHex).opacity(0.7)
                                    : Color(hex: AppTheme.bark).opacity(0.2)
                            )
                            .cornerRadius(10)
                    }
                    .disabled((Int(customMinutes) ?? 0) <= 0)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Text("tap a time to propose a change")
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundColor(Color(hex: AppTheme.bark).opacity(0.3))
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color(hex: AppTheme.bark).opacity(0.05), radius: 8, y: 3)
    }

    func formatMins(_ m: Int) -> String {
        m >= 60 ? "\(m/60)h\(m%60 > 0 ? " \(m%60)m" : "")" : "\(m)m"
    }
}

// MARK: - Partner Limit Card
struct PartnerLimitCard: View {
    let limit: AppLimitConfig
    let onSuggest: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            AppBrandIcon(bundleId: limit.bundleIdentifier, size: 36)
            Text(limit.appName)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: AppTheme.charcoal))
            Spacer()
            Text(formatMins(limit.dailyLimitMinutes))
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundColor(Color(hex: limit.colorHex).opacity(0.8))
            Button(action: onSuggest) {
                Text("suggest")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: AppTheme.lavenderDark))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(hex: AppTheme.lavender).opacity(0.15))
                    .cornerRadius(10)
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color(hex: AppTheme.bark).opacity(0.05), radius: 8, y: 3)
    }

    func formatMins(_ m: Int) -> String {
        m >= 60 ? "\(m/60)h\(m%60 > 0 ? " \(m%60)m" : "")" : "\(m)m"
    }
}

// MARK: - Suggest Limit Sheet
struct SuggestLimitSheet: View {
    let limit: AppLimitConfig
    let onSuggest: (Int) -> Void
    @State private var suggestedMinutes: Int
    let options = [15, 30, 45, 60, 90, 120]

    init(limit: AppLimitConfig, onSuggest: @escaping (Int) -> Void) {
        self.limit = limit
        self.onSuggest = onSuggest
        self._suggestedMinutes = State(initialValue: limit.dailyLimitMinutes)
    }

    var body: some View {
        VStack(spacing: 24) {
            Text("suggest a new limit")
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundColor(Color(hex: AppTheme.charcoal))
                .padding(.top, 32)

            HStack(spacing: 10) {
                AppBrandIcon(bundleId: limit.bundleIdentifier, size: 36)
                Text(limit.appName)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: AppTheme.charcoal))
            }

            Text("current: \(formatMins(limit.dailyLimitMinutes))")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(Color(hex: AppTheme.bark).opacity(0.5))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(options, id: \.self) { mins in
                    Button {
                        suggestedMinutes = mins
                    } label: {
                        Text(formatMins(mins))
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .padding(.vertical, 14)
                            .frame(maxWidth: .infinity)
                            .background(
                                suggestedMinutes == mins
                                    ? Color(hex: AppTheme.lavenderDark)
                                    : Color(hex: AppTheme.cloud)
                            )
                            .foregroundColor(suggestedMinutes == mins ? .white : Color(hex: AppTheme.bark).opacity(0.5))
                            .cornerRadius(14)
                    }
                }
            }
            .padding(.horizontal)

            Button {
                onSuggest(suggestedMinutes)
            } label: {
                Text("send suggestion")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: AppTheme.lavender), Color(hex: AppTheme.lavenderDark)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .cornerRadius(20)
                    .padding(.horizontal)
            }

            Spacer()
        }
    }

    func formatMins(_ m: Int) -> String {
        m >= 60 ? "\(m/60)h\(m%60 > 0 ? " \(m%60)m" : "")" : "\(m)m"
    }
}

// MARK: - Limit Suggestion Modal (overlay when partner suggests a change)
struct LimitSuggestionModalView: View {
    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        if let suggestion = vm.pendingLimitSuggestion {
            ZStack {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 40))
                        .foregroundColor(Color(hex: AppTheme.lavenderDark))

                    Text("limit suggestion")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundColor(Color(hex: AppTheme.charcoal))

                    Text("\(vm.partnerName) suggests changing")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(Color(hex: AppTheme.bark).opacity(0.5))

                    Text(suggestion.appDisplayName)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: AppTheme.lavenderDark))

                    HStack(spacing: 12) {
                        VStack(spacing: 4) {
                            Text("current")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(Color(hex: AppTheme.bark).opacity(0.4))
                            Text(formatMins(suggestion.currentMinutes))
                                .font(.system(size: 22, weight: .heavy, design: .rounded))
                                .foregroundColor(Color(hex: AppTheme.charcoal))
                        }

                        Image(systemName: "arrow.right")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Color(hex: AppTheme.lavender))

                        VStack(spacing: 4) {
                            Text("suggested")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(Color(hex: AppTheme.bark).opacity(0.4))
                            Text(formatMins(suggestion.suggestedMinutes))
                                .font(.system(size: 22, weight: .heavy, design: .rounded))
                                .foregroundColor(Color(hex: AppTheme.lavenderDark))
                        }
                    }
                    .padding(.vertical, 8)

                    HStack(spacing: 12) {
                        Button {
                            vm.rejectLimitSuggestion(suggestion)
                        } label: {
                            Text("decline")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(Color(hex: AppTheme.bark).opacity(0.5))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color(hex: AppTheme.cloud))
                                .cornerRadius(20)
                        }

                        Button {
                            vm.acceptLimitSuggestion(suggestion)
                        } label: {
                            Text("accept")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    LinearGradient(
                                        colors: [Color(hex: AppTheme.lavender), Color(hex: AppTheme.lavenderDark)],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                )
                                .cornerRadius(20)
                        }
                    }
                }
                .padding(28)
                .background(Color.white)
                .cornerRadius(28)
                .shadow(color: Color(hex: AppTheme.bark).opacity(0.15), radius: 24, y: 12)
                .padding(20)
            }
        }
    }

    func formatMins(_ m: Int) -> String {
        m >= 60 ? "\(m/60)h\(m%60 > 0 ? " \(m%60)m" : "")" : "\(m)m"
    }
}
