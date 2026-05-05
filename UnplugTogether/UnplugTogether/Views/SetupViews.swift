import SwiftUI
import FamilyControls

// MARK: - Step 1: Name Setup
struct SetupNameView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var name = ""

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Logo — soft and warm
            Text("unplug\ntogether")
                .font(.system(size: 38, weight: .heavy, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: AppTheme.rose), Color(hex: AppTheme.lavender)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            PixelHeartView()
                .frame(width: 60, height: 50)

            Text("grow a garden together\nby putting your phones down")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(Color(hex: AppTheme.bark).opacity(0.6))
                .multilineTextAlignment(.center)

            Spacer().frame(height: 8)

            VStack(alignment: .leading, spacing: 6) {
                Text("your name")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: AppTheme.roseDark))
                TextField("e.g. Jed", text: $name)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .padding(14)
                    .background(Color(hex: AppTheme.cloud))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(hex: AppTheme.rose).opacity(0.3), lineWidth: 2)
                    )
            }

            Spacer()

            Button {
                vm.completeNameSetup(myName: name.isEmpty ? "Player 1" : name)
            } label: {
                Text("next")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: AppTheme.rose), Color(hex: AppTheme.peach)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(24)
                    .shadow(color: Color(hex: AppTheme.rose).opacity(0.3), radius: 12, y: 6)
            }
        }
        .padding(24)
    }
}

// MARK: - Pairing with Share Sheet
struct PairingView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var joinCode = ""
    @State private var mode: PairingMode = .choose
    @State private var showShareSheet = false
    @State private var didAutoJoin = false
    @State private var codeCopied = false

    enum PairingMode {
        case choose, create, join
    }

    var body: some View {
        Group {
            switch mode {
            case .choose:
                chooseModeView
            case .create:
                createModeView
            case .join:
                joinModeView
            }
        }
        .sheet(isPresented: $showShareSheet) {
            let deepLink = "https://unplugtogether.app/join?code=\(vm.pairingCode)"
            ShareSheet(items: [
                "Join me on Unplug Together! We'll hold each other accountable for screen time and grow a garden together 🌱\n\nTap this link to connect with me:\n\(deepLink)\n\nOr enter my code manually: \(vm.pairingCode)"
            ])
        }
        .onAppear {
            if let code = vm.deepLinkCode, !didAutoJoin {
                joinCode = code
                mode = .join
                didAutoJoin = true
                Task { await vm.joinCouple(code: code) }
            }
        }
        .onChange(of: vm.deepLinkCode) { _, newCode in
            if let code = newCode, !didAutoJoin {
                joinCode = code
                mode = .join
                didAutoJoin = true
                Task { await vm.joinCouple(code: code) }
            }
        }
    }

    // MARK: - Choose Mode
    private var chooseModeView: some View {
        VStack(spacing: 24) {
            Spacer()

            // Back button
            HStack {
                Button {
                    vm.goBackFromPairing()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("back")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(Color(hex: AppTheme.bark).opacity(0.5))
                }
                Spacer()
            }

            Text("connect with\nyour partner")
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundColor(Color(hex: AppTheme.charcoal))

            Text("one creates, the other joins")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(Color(hex: AppTheme.bark).opacity(0.5))

            Spacer().frame(height: 8)

            Button {
                mode = .create
                Task { await vm.createCouple() }
            } label: {
                VStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 32))
                    Text("create couple")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Text("get a code to share")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(
                    LinearGradient(
                        colors: [Color(hex: AppTheme.rose), Color(hex: AppTheme.peach)],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .cornerRadius(24)
                .shadow(color: Color(hex: AppTheme.rose).opacity(0.3), radius: 12, y: 6)
            }

            Button {
                mode = .join
            } label: {
                VStack(spacing: 8) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 32))
                    Text("join partner")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Text("enter their code")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                }
                .foregroundColor(Color(hex: AppTheme.lavenderDark))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(Color.white)
                .cornerRadius(24)
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color(hex: AppTheme.lavender), lineWidth: 2))
                .shadow(color: Color(hex: AppTheme.lavender).opacity(0.2), radius: 8, y: 4)
            }

            Spacer()
        }
        .padding(24)
    }

    // MARK: - Create Mode
    private var createModeView: some View {
        VStack(spacing: 0) {
            if vm.isLoading {
                Spacer()
                ProgressView("setting up...")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                Spacer()
            } else if vm.pairingCode.isEmpty {
                // Code generation failed
                Spacer()
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(Color(hex: AppTheme.peach))
                Text("couldn't create code")
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundColor(Color(hex: AppTheme.charcoal))
                    .padding(.top, 12)

                if let error = vm.errorMessage {
                    Text(error)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(Color(hex: AppTheme.bark).opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.top, 4)
                }

                VStack(spacing: 12) {
                    Button {
                        vm.errorMessage = nil
                        Task { await vm.createCouple() }
                    } label: {
                        Label("try again", systemImage: "arrow.clockwise")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: AppTheme.rose), Color(hex: AppTheme.peach)],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .cornerRadius(20)
                    }
                    Button {
                        mode = .choose
                        vm.errorMessage = nil
                    } label: {
                        Text("go back")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(Color(hex: AppTheme.bark).opacity(0.4))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                Spacer()
            } else {
                // Code generated — show it + share options
                Spacer().frame(height: 60)

                VStack(spacing: 12) {
                    Image(systemName: "link.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(Color(hex: AppTheme.rose).opacity(0.6))

                    Text("share this code\nwith your partner")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundColor(Color(hex: AppTheme.charcoal))
                }

                Spacer().frame(height: 32)

                // Code display card
                VStack(spacing: 16) {
                    Text("your pairing code")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: AppTheme.bark).opacity(0.4))
                        .textCase(.uppercase)
                        .tracking(1)

                    Text(vm.pairingCode)
                        .font(.system(size: 44, weight: .black, design: .rounded))
                        .tracking(10)
                        .foregroundColor(Color(hex: AppTheme.roseDark))

                    Button {
                        UIPasteboard.general.string = vm.pairingCode
                        codeCopied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { codeCopied = false }
                    } label: {
                        Label(
                            codeCopied ? "copied!" : "copy code",
                            systemImage: codeCopied ? "checkmark.circle.fill" : "doc.on.doc"
                        )
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(codeCopied ? Color(hex: AppTheme.mintDark) : Color(hex: AppTheme.bark).opacity(0.5))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(hex: AppTheme.cloud))
                        .cornerRadius(12)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .background(Color.white)
                .cornerRadius(24)
                .shadow(color: Color(hex: AppTheme.bark).opacity(0.06), radius: 12, y: 4)
                .padding(.horizontal, 24)

                Spacer().frame(height: 24)

                VStack(spacing: 12) {
                    Button {
                        showShareSheet = true
                    } label: {
                        Label("send invite to partner", systemImage: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: AppTheme.rose), Color(hex: AppTheme.peach)],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .cornerRadius(20)
                            .shadow(color: Color(hex: AppTheme.rose).opacity(0.3), radius: 10, y: 5)
                    }

                    Button {
                        vm.moveToWaitingForPartner()
                    } label: {
                        Text("done sharing — wait for partner")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(Color(hex: AppTheme.lavenderDark))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(hex: AppTheme.cloud))
                            .cornerRadius(18)
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                Button {
                    mode = .choose
                } label: {
                    Text("back")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(hex: AppTheme.bark).opacity(0.4))
                }
                .padding(.bottom, 32)
            }
        }
    }

    // MARK: - Join Mode
    private var joinModeView: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("connect with\nyour partner")
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundColor(Color(hex: AppTheme.charcoal))

            if let error = vm.errorMessage {
                Text(error)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(Color(hex: AppTheme.roseDark))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(hex: AppTheme.rose).opacity(0.1))
                    .cornerRadius(12)
            }

            VStack(spacing: 16) {
                Text("enter partner's code")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: AppTheme.bark).opacity(0.5))

                TextField("ABC123", text: $joinCode)
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundColor(Color(hex: AppTheme.charcoal))
                    .tracking(6)
                    .multilineTextAlignment(.center)
                    .textInputAutocapitalization(.characters)
                    .padding(16)
                    .background(Color.white)
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: AppTheme.lavender), lineWidth: 2))

                Button {
                    Task { await vm.joinCouple(code: joinCode.uppercased()) }
                } label: {
                    if vm.isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text("join")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    LinearGradient(
                        colors: [Color(hex: AppTheme.lavender), Color(hex: AppTheme.lavenderDark)],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .cornerRadius(24)
                .disabled(joinCode.count < 6)
            }

            Button {
                mode = .choose
            } label: {
                Text("back")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(hex: AppTheme.bark).opacity(0.4))
            }

            Spacer()
        }
        .padding(24)
    }
}

// MARK: - Waiting For Partner View (cute screen after sharing code)
struct WaitingForPartnerView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var bobOffset: CGFloat = 0
    @State private var showShareSheet = false
    @State private var pushCheckTrigger = false
    @State private var lastPushSyncTime: Date = .distantPast

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Cute character with garden preview
            ZStack {
                // Mini garden backdrop
                RoundedRectangle(cornerRadius: 32)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "#E8F5E9"),
                                Color(hex: "#C8E6C9")
                            ],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .frame(height: 180)
                    .overlay(
                        // Little hills
                        VStack {
                            Spacer()
                            HillShape()
                                .fill(Color(hex: AppTheme.mint).opacity(0.5))
                                .frame(height: 60)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 32))
                    )

                // Your avatar sitting in the garden
                VStack(spacing: 0) {
                    Spacer().frame(height: 40)
                    PaperCutoutCharacter(avatar: vm.myAvatar, size: 80, stepFrame: false)
                        .offset(y: bobOffset)
                    Spacer().frame(height: 12)
                }
            }
            .frame(height: 180)
            .padding(.horizontal, 40)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    bobOffset = -6
                }
            }

            Spacer().frame(height: 32)

            Text("waiting for your partner\nto join the garden")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundColor(Color(hex: AppTheme.charcoal))

            Spacer().frame(height: 12)

            Text("once they enter your code,\nyou'll each set your own limits")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(Color(hex: AppTheme.bark).opacity(0.5))
                .multilineTextAlignment(.center)

            Spacer().frame(height: 24)

            // Code reminder
            HStack(spacing: 8) {
                Text("code:")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(Color(hex: AppTheme.bark).opacity(0.4))
                Text(vm.pairingCode)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .tracking(4)
                    .foregroundColor(Color(hex: AppTheme.roseDark))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: Color(hex: AppTheme.bark).opacity(0.05), radius: 8, y: 3)

            Spacer().frame(height: 20)

            Button {
                showShareSheet = true
            } label: {
                Label("resend invite", systemImage: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(hex: AppTheme.bark).opacity(0.5))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color(hex: AppTheme.cloud))
                    .cornerRadius(16)
            }

            Spacer()

            HStack(spacing: 10) {
                ProgressView()
                    .tint(Color(hex: AppTheme.rose))
                    .scaleEffect(0.8)
                Text("listening for partner...")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(Color(hex: AppTheme.bark).opacity(0.4))
            }
            .padding(.bottom, 32)
        }
        .sheet(isPresented: $showShareSheet) {
            let deepLink = "https://unplugtogether.app/join?code=\(vm.pairingCode)"
            ShareSheet(items: [
                "Join me on Unplug Together! 🌱\n\nTap this link: \(deepLink)\nOr use code: \(vm.pairingCode)"
            ])
        }
        .task {
            // Poll for partner joining — check immediately, then every 2 seconds
            // Times out after 1 hour and returns to pairing screen
            let startTime = Date()
            let timeoutSeconds: TimeInterval = 3600 // 1 hour

            while !vm.isPaired {
                if Task.isCancelled { break }

                // Check for timeout
                if Date().timeIntervalSince(startTime) > timeoutSeconds {
                    await MainActor.run {
                        vm.errorMessage = "Partner hasn't joined after 1 hour. Check that they entered your code correctly, or resend the invite."
                        vm.state = .pairing
                    }
                    break
                }

                let joined = await CloudKitManager.shared.checkForPartnerJoin()
                if joined {
                    await MainActor.run {
                        vm.onPartnerJoined()
                    }
                    break
                }
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .partnerJoinedNotification)) { _ in
            // Push notification received — debounce to avoid racing with polling
            let now = Date()
            guard now.timeIntervalSince(lastPushSyncTime) > 0.5 else { return }
            lastPushSyncTime = now

            Task {
                let joined = await CloudKitManager.shared.checkForPartnerJoin()
                if joined {
                    await MainActor.run {
                        vm.onPartnerJoined()
                    }
                }
            }
        }
    }
}

/// Simple hill shape for the waiting view backdrop
struct HillShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.height))
        path.addQuadCurve(
            to: CGPoint(x: rect.width, y: rect.height),
            control: CGPoint(x: rect.width * 0.5, y: -rect.height * 0.3)
        )
        path.closeSubpath()
        return path
    }
}

// MARK: - Pick My Limits View (each user sets their OWN limits)
struct PickMyLimitsView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var myLimits: [String: Int] = [:]
    @State private var selectedFrequency: CheckInFrequency = .weekly
    let limitOptions = [15, 30, 45, 60, 90, 120]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text("set your limits")
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundColor(Color(hex: AppTheme.charcoal))

                    Text("pick daily screen time limits for yourself.\n\(vm.partnerName) is setting theirs too.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(Color(hex: AppTheme.bark).opacity(0.5))
                        .multilineTextAlignment(.center)
                }

                // Family Activity Picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("select apps to track")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: AppTheme.roseDark))

                    FamilyActivityPicker(selection: $vm.activitySelection)
                        .frame(height: 280)
                        .cornerRadius(16)
                }
                .padding(.horizontal, 4)

                // === MY LIMITS SECTION ===
                sectionHeader(
                    title: "your goals",
                    subtitle: "daily time limits for you",
                    avatarConfig: vm.myAvatar,
                    colorHex: AppTheme.rose
                )

                ForEach(TrackedApp.allCases) { app in
                    AppLimitCard(
                        app: app,
                        selectedMinutes: myLimits[app.rawValue] ?? 0,
                        limitOptions: limitOptions,
                        onSelect: { mins in myLimits[app.rawValue] = mins }
                    )
                }


                // Submit button
                Button {
                    let myConfigs = buildConfigs(from: myLimits)
                    Task {
                        await vm.submitMyLimits(
                            limits: myConfigs,
                            frequency: selectedFrequency
                        )
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text("submit my limits")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: AppTheme.mint), Color(hex: AppTheme.mintDark)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .cornerRadius(24)
                    .shadow(color: Color(hex: AppTheme.mint).opacity(0.4), radius: 12, y: 6)
                }
            }
            .padding(24)
        }
        .onAppear {
            // Pre-fill from existing limits if going back to edit
            for limit in vm.appLimits {
                myLimits[limit.bundleIdentifier] = limit.dailyLimitMinutes
            }
            selectedFrequency = vm.checkInFrequency
        }
    }

    private func sectionHeader(title: String, subtitle: String, avatarConfig: AvatarConfig, colorHex: String) -> some View {
        HStack(spacing: 12) {
            PaperCutoutCharacter(avatar: avatarConfig, size: 36, stepFrame: false)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundColor(Color(hex: AppTheme.charcoal))
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(Color(hex: AppTheme.bark).opacity(0.4))
            }

            Spacer()
        }
        .padding(14)
        .background(Color(hex: colorHex).opacity(0.08))
        .cornerRadius(16)
    }

    private func dividerRow(text: String) -> some View {
        HStack {
            Rectangle().fill(Color(hex: AppTheme.bark).opacity(0.1)).frame(height: 1)
            Text(text)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: AppTheme.bark).opacity(0.4))
            Rectangle().fill(Color(hex: AppTheme.bark).opacity(0.1)).frame(height: 1)
        }
    }

    private func buildConfigs(from dict: [String: Int]) -> [AppLimitConfig] {
        var configs: [AppLimitConfig] = []
        for (bundleId, mins) in dict where mins > 0 {
            if let app = TrackedApp(rawValue: bundleId) {
                configs.append(app.toConfig(limitMinutes: mins))
            }
        }
        if configs.isEmpty {
            configs = TrackedApp.allCases.map { $0.toConfig(limitMinutes: 60) }
        }
        return configs
    }
}

// MARK: - Waiting For Both Limits View
struct WaitingForBothLimitsView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var bobOffset: CGFloat = 0
    @State private var pollId = UUID()  // Force .task restart when view reappears
    @State private var lastPushSyncTime: Date = .distantPast  // Debounce push vs polling

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // Avatar bobbing
            PaperCutoutCharacter(avatar: vm.myAvatar, size: 80, stepFrame: false)
                .offset(y: bobOffset)
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                        bobOffset = -6
                    }
                }

            if vm.iConfirmedPartner && !vm.partnerConfirmedMe {
                // I've confirmed partner's limits, waiting for them to confirm mine
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(Color(hex: AppTheme.mint).opacity(0.6))

                Text("you're all set!")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundColor(Color(hex: AppTheme.charcoal))

                Text("waiting for \(vm.partnerName)\nto confirm your limits")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(Color(hex: AppTheme.bark).opacity(0.5))
                    .multilineTextAlignment(.center)
            } else {
                // Waiting for partner to submit their limits
                Image(systemName: "clock.fill")
                    .font(.system(size: 32))
                    .foregroundColor(Color(hex: AppTheme.lavender).opacity(0.6))

                Text("limits submitted!")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundColor(Color(hex: AppTheme.charcoal))

                Text("waiting for \(vm.partnerName)\nto finish setting their limits")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(Color(hex: AppTheme.bark).opacity(0.5))
                    .multilineTextAlignment(.center)
            }

            // Show my submitted limits summary
            if !vm.appLimits.isEmpty {
                VStack(spacing: 8) {
                    Text("your limits")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: AppTheme.bark).opacity(0.3))
                        .textCase(.uppercase)
                        .tracking(1)

                    ForEach(vm.appLimits) { limit in
                        HStack {
                            AppBrandIcon(bundleId: limit.bundleIdentifier, size: 24)
                            Text(limit.appName)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(Color(hex: AppTheme.charcoal))
                            Spacer()
                            Text(formatMins(limit.dailyLimitMinutes))
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(Color(hex: limit.colorHex))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                    }
                }
                .padding(14)
                .background(Color.white)
                .cornerRadius(16)
                .shadow(color: Color(hex: AppTheme.bark).opacity(0.05), radius: 6, y: 3)
                .padding(.horizontal, 32)

                if !vm.iConfirmedPartner {
                    Button {
                        vm.goBackToEditMyLimits()
                    } label: {
                        Text("edit my limits")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(Color(hex: AppTheme.bark).opacity(0.4))
                    }
                }
            }

            Spacer()

            HStack(spacing: 10) {
                ProgressView()
                    .tint(Color(hex: AppTheme.lavender))
                    .scaleEffect(0.8)
                Text("waiting for \(vm.partnerName)...")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(Color(hex: AppTheme.bark).opacity(0.4))
            }
            .padding(.bottom, 32)
        }
        .onAppear {
            // Generate a new ID each time the view appears so .task(id:) restarts
            // This handles coming back from ReviewPartnerLimitsView
            pollId = UUID()
        }
        .task(id: pollId) {
            // Poll for partner's limits and confirmation status — check immediately, then every 3 seconds
            while true {
                if Task.isCancelled { break }

                // Check if partner has submitted their limits
                if let pLimits = await CloudKitManager.shared.fetchPartnerLimits(), !pLimits.isEmpty {
                    vm.partnerLimits = pLimits
                    vm.partnerLimitsSubmitted = true

                    // If I haven't confirmed partner's limits yet, go to review
                    if !vm.iConfirmedPartner {
                        vm.state = .reviewPartnerLimits
                        break
                    }
                }

                // If I already confirmed, check if partner confirmed mine
                if vm.iConfirmedPartner {
                    let partnerApproved = await CloudKitManager.shared.fetchPartnerApproval()
                    if partnerApproved {
                        vm.partnerConfirmedMe = true
                        vm.beginMonitoring()
                        break
                    }
                }

                try? await Task.sleep(nanoseconds: 2_000_000_000) // Poll every 2 seconds
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .cloudKitDataChanged)) { _ in
            // Push notification received — debounce to avoid racing with the polling task
            let now = Date()
            guard now.timeIntervalSince(lastPushSyncTime) > 0.5 else { return }
            lastPushSyncTime = now

            Task {
                if let pLimits = await CloudKitManager.shared.fetchPartnerLimits(), !pLimits.isEmpty {
                    vm.partnerLimits = pLimits
                    vm.partnerLimitsSubmitted = true
                    if !vm.iConfirmedPartner {
                        vm.state = .reviewPartnerLimits
                        return
                    }
                }
                if vm.iConfirmedPartner {
                    let partnerApproved = await CloudKitManager.shared.fetchPartnerApproval()
                    if partnerApproved {
                        vm.partnerConfirmedMe = true
                        vm.beginMonitoring()
                    }
                }
            }
        }
    }

    func formatMins(_ m: Int) -> String {
        m >= 60 ? "\(m/60)h\(m%60 > 0 ? " \(m%60)m" : "")" : "\(m)m"
    }
}

// MARK: - Review Partner Limits View (confirm or suggest changes to partner's limits)
struct ReviewPartnerLimitsView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var showSuggestSheet = false
    @State private var suggestingApp: AppLimitConfig? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(Color(hex: AppTheme.lavenderDark).opacity(0.6))

                    Text("\(vm.partnerName)'s limits")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundColor(Color(hex: AppTheme.charcoal))

                    Text("review the limits \(vm.partnerName) set for themselves")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(Color(hex: AppTheme.bark).opacity(0.5))
                        .multilineTextAlignment(.center)
                }

                // Partner's limits
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        PaperCutoutCharacter(avatar: vm.partnerAvatar, size: 30, stepFrame: false)
                        Text("\(vm.partnerName)'s goals")
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundColor(Color(hex: AppTheme.charcoal))
                        Spacer()
                    }

                    ForEach(vm.partnerLimits) { limit in
                        HStack(spacing: 12) {
                            AppBrandIcon(bundleId: limit.bundleIdentifier, size: 36)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(limit.appName)
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(Color(hex: AppTheme.charcoal))
                                Text("daily limit")
                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                                    .foregroundColor(Color(hex: AppTheme.bark).opacity(0.4))
                            }

                            Spacer()

                            Text(formatMins(limit.dailyLimitMinutes))
                                .font(.system(size: 16, weight: .heavy, design: .rounded))
                                .foregroundColor(Color(hex: limit.colorHex))

                            // Suggest change button
                            Button {
                                suggestingApp = limit
                                showSuggestSheet = true
                            } label: {
                                Image(systemName: "pencil.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(Color(hex: AppTheme.lavender))
                            }
                        }
                        .padding(12)
                        .background(Color.white)
                        .cornerRadius(14)
                        .shadow(color: Color(hex: AppTheme.bark).opacity(0.04), radius: 4, y: 2)
                    }
                }
                .padding(16)
                .background(Color(hex: AppTheme.lavender).opacity(0.05))
                .cornerRadius(20)

                // My limits summary
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        PaperCutoutCharacter(avatar: vm.myAvatar, size: 30, stepFrame: false)
                        Text("your goals")
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundColor(Color(hex: AppTheme.charcoal))
                        Spacer()
                    }

                    ForEach(vm.appLimits) { limit in
                        HStack(spacing: 12) {
                            AppBrandIcon(bundleId: limit.bundleIdentifier, size: 36)

                            Text(limit.appName)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(Color(hex: AppTheme.charcoal))

                            Spacer()

                            Text(formatMins(limit.dailyLimitMinutes))
                                .font(.system(size: 16, weight: .heavy, design: .rounded))
                                .foregroundColor(Color(hex: limit.colorHex))
                        }
                        .padding(12)
                        .background(Color.white)
                        .cornerRadius(14)
                        .shadow(color: Color(hex: AppTheme.bark).opacity(0.04), radius: 4, y: 2)
                    }
                }
                .padding(16)
                .background(Color(hex: AppTheme.rose).opacity(0.05))
                .cornerRadius(20)

                // Action buttons
                VStack(spacing: 12) {
                    Button {
                        Task { await vm.confirmPartnerLimits() }
                    } label: {
                        HStack(spacing: 8) {
                            Text("looks good — confirm!")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: AppTheme.mint), Color(hex: AppTheme.mintDark)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .cornerRadius(24)
                        .shadow(color: Color(hex: AppTheme.mint).opacity(0.4), radius: 12, y: 6)
                    }

                    Text("tap the pencil icon to suggest a different limit")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(Color(hex: AppTheme.bark).opacity(0.3))
                }
            }
            .padding(24)
        }
        .sheet(isPresented: $showSuggestSheet) {
            if let app = suggestingApp {
                SetupSuggestLimitSheet(
                    appName: app.appName,
                    currentMinutes: app.dailyLimitMinutes,
                    onSuggest: { newMinutes in
                        vm.suggestLimitChange(
                            appBundleId: app.bundleIdentifier,
                            appDisplayName: app.appName,
                            suggestedMinutes: newMinutes,
                            currentMinutes: app.dailyLimitMinutes
                        )
                        showSuggestSheet = false
                    }
                )
                .presentationDetents([.medium])
            }
        }
    }

    func formatMins(_ m: Int) -> String {
        m >= 60 ? "\(m/60)h\(m%60 > 0 ? " \(m%60)m" : "")" : "\(m)m"
    }
}

// MARK: - Review Partner Limits Wrapper (adds push/foreground listeners)
extension ReviewPartnerLimitsView {
    /// Check if partner has already confirmed our limits while we're reviewing theirs.
    /// If so, when we confirm, confirmPartnerLimits() will detect it and go straight to home.
    /// We also pre-fetch so the transition is seamless.
    func checkPartnerApprovalInBackground() {
        Task {
            let approved = await CloudKitManager.shared.fetchPartnerApproval()
            if approved {
                // Don't transition yet — wait for the user to confirm.
                // But remember the result so confirmPartnerLimits() picks it up immediately.
                print("[ReviewPartnerLimits] Partner already approved our limits")
            }
        }
    }
}

// MARK: - Setup Suggest Limit Sheet (suggest a different limit during setup review)
struct SetupSuggestLimitSheet: View {
    let appName: String
    let currentMinutes: Int
    let onSuggest: (Int) -> Void
    let options = [15, 30, 45, 60, 90, 120]
    @State private var selectedMinutes: Int = 0

    var body: some View {
        VStack(spacing: 20) {
            Text("suggest a limit for \(appName)")
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundColor(Color(hex: AppTheme.charcoal))

            Text("currently set to \(formatMins(currentMinutes))")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(Color(hex: AppTheme.bark).opacity(0.5))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(options, id: \.self) { mins in
                    Button {
                        selectedMinutes = mins
                    } label: {
                        Text(formatMins(mins))
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                selectedMinutes == mins
                                    ? Color(hex: AppTheme.lavender)
                                    : Color(hex: AppTheme.cloud)
                            )
                            .foregroundColor(
                                selectedMinutes == mins ? .white : Color(hex: AppTheme.charcoal)
                            )
                            .cornerRadius(14)
                    }
                }
            }

            Button {
                guard selectedMinutes > 0 else { return }
                onSuggest(selectedMinutes)
            } label: {
                Text("send suggestion")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        selectedMinutes > 0
                            ? LinearGradient(colors: [Color(hex: AppTheme.lavender), Color(hex: AppTheme.lavenderDark)], startPoint: .leading, endPoint: .trailing)
                            : LinearGradient(colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing)
                    )
                    .cornerRadius(20)
            }
            .disabled(selectedMinutes == 0)
        }
        .padding(24)
    }

    func formatMins(_ m: Int) -> String {
        m >= 60 ? "\(m/60)h\(m%60 > 0 ? " \(m%60)m" : "")" : "\(m)m"
    }
}

// MARK: - App Limit Card (reusable for both sections)
struct AppLimitCard: View {
    let app: TrackedApp
    let selectedMinutes: Int
    let limitOptions: [Int]
    let onSelect: (Int) -> Void

    @State private var showCustom = false
    @State private var customMinutes = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                AppBrandIcon(bundleId: app.rawValue, size: 36)
                Text(app.displayName)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: AppTheme.charcoal))
                Spacer()
                if selectedMinutes > 0 {
                    Text(formatMins(selectedMinutes))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: app.colorHex))
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(limitOptions, id: \.self) { mins in
                        Button {
                            showCustom = false
                            onSelect(mins)
                        } label: {
                            Text(formatMins(mins))
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    !showCustom && selectedMinutes == mins
                                        ? AnyShapeStyle(Color(hex: app.colorHex).opacity(0.8))
                                        : AnyShapeStyle(Color(hex: AppTheme.cloud))
                                )
                                .foregroundColor(!showCustom && selectedMinutes == mins ? .white : Color(hex: AppTheme.bark).opacity(0.5))
                                .cornerRadius(12)
                        }
                    }

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showCustom.toggle()
                            if showCustom && selectedMinutes > 0 && !limitOptions.contains(selectedMinutes) {
                                customMinutes = "\(selectedMinutes)"
                            }
                        }
                    } label: {
                        Text("custom")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                showCustom
                                    ? AnyShapeStyle(Color(hex: app.colorHex).opacity(0.8))
                                    : AnyShapeStyle(Color(hex: AppTheme.cloud))
                            )
                            .foregroundColor(showCustom ? .white : Color(hex: AppTheme.bark).opacity(0.5))
                            .cornerRadius(12)
                    }
                }
            }

            if showCustom {
                HStack(spacing: 8) {
                    TextField("minutes", text: $customMinutes)
                        .keyboardType(.numberPad)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(hex: AppTheme.cloud))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(hex: app.colorHex).opacity(0.3), lineWidth: 1.5)
                        )
                        .frame(width: 100)

                    Text("min")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(hex: AppTheme.bark).opacity(0.4))

                    Button {
                        if let mins = Int(customMinutes), mins > 0 {
                            onSelect(mins)
                        }
                    } label: {
                        Text("set")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Int(customMinutes) ?? 0 > 0
                                    ? Color(hex: app.colorHex).opacity(0.8)
                                    : Color(hex: AppTheme.bark).opacity(0.2)
                            )
                            .cornerRadius(12)
                    }
                    .disabled((Int(customMinutes) ?? 0) <= 0)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color(hex: AppTheme.bark).opacity(0.06), radius: 8, y: 3)
    }

    func formatMins(_ m: Int) -> String {
        m >= 60 ? "\(m/60)h\(m%60 > 0 ? " \(m%60)m" : "")" : "\(m)m"
    }
}

// MARK: - UIKit Share Sheet wrapper
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
