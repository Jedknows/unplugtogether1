import SwiftUI

// MARK: - Main Tab View
struct MainTabView: View {
    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                switch vm.selectedTab {
                case .home:
                    HomeView()
                case .garden:
                    GardenView()
                case .limits:
                    LimitsView()
                }
            }

            // Tab Bar — soft hand-drawn feel
            HStack {
                ForEach(AppViewModel.Tab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            vm.selectedTab = tab
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: tabIcon(tab))
                                .font(.system(size: 22, weight: vm.selectedTab == tab ? .bold : .regular))
                            Text(tab.rawValue)
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(vm.selectedTab == tab ? Color(hex: AppTheme.roseDark) : Color(hex: AppTheme.bark).opacity(0.3))
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.vertical, 10)
            .background(Color(hex: AppTheme.cloud).opacity(0.95))
            .overlay(Divider().foregroundColor(Color(hex: AppTheme.bark).opacity(0.1)), alignment: .top)
        }
    }

    func tabIcon(_ tab: AppViewModel.Tab) -> String {
        switch tab {
        case .home: return "house.fill"
        case .garden: return "leaf.fill"
        case .limits: return "gearshape.fill"
        }
    }
}

// MARK: - Home View
struct HomeView: View {
    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        VStack(spacing: 16) {
            // Header
            VStack(spacing: 4) {
                Text("unplug together")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: AppTheme.rose), Color(hex: AppTheme.lavender)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                HStack(spacing: 4) {
                    Text(vm.myName)
                        .foregroundColor(Color(hex: AppTheme.roseDark))
                    Text("&")
                        .foregroundColor(Color(hex: AppTheme.bark).opacity(0.4))
                    Text(vm.partnerName)
                        .foregroundColor(Color(hex: AppTheme.lavenderDark))
                }
                .font(.system(size: 12, weight: .semibold, design: .rounded))
            }
            .padding(.top, 16)

            // Streak Banner — warm pastels
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(vm.streak)")
                        .font(.system(size: 36, weight: .black, design: .rounded))
                    Text("day streak")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .opacity(0.9)
                }

                Spacer()

                // Week dots
                HStack(spacing: 4) {
                    ForEach(0..<7, id: \.self) { i in
                        let met = i < vm.dayHistory.suffix(7).count
                            ? vm.dayHistory.suffix(7)[vm.dayHistory.suffix(7).startIndex + i].allGoalsMet
                            : false
                        RoundedRectangle(cornerRadius: 4)
                            .fill(met ? Color.white : Color.white.opacity(0.3))
                            .frame(width: 12, height: 12)
                    }
                }
            }
            .foregroundColor(.white)
            .padding(20)
            .background(
                LinearGradient(
                    colors: [Color(hex: AppTheme.rose), Color(hex: AppTheme.peach)],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .cornerRadius(24)
            .shadow(color: Color(hex: AppTheme.rose).opacity(0.2), radius: 12, y: 6)

            // App Usage Cards
            VStack(alignment: .leading, spacing: 10) {
                Text("today's screen time")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: AppTheme.charcoal))

                // My tracked apps
                ForEach(vm.appLimits) { limit in
                    let partnerLimit = vm.partnerLimits.first(where: { $0.bundleIdentifier == limit.bundleIdentifier })
                    AppUsageCard(
                        limit: limit,
                        myUsage: vm.myUsage[limit.bundleIdentifier] ?? 0,
                        myLimit: limit.dailyLimitMinutes,
                        partnerUsage: vm.partnerUsage[limit.bundleIdentifier] ?? 0,
                        partnerLimit: partnerLimit?.dailyLimitMinutes,
                        myName: vm.myName,
                        partnerName: vm.partnerName,
                        onProposeLimitChange: { newLimit in
                            vm.proposeLimitChange(appId: limit.bundleIdentifier, newLimit: newLimit)
                        }
                    )
                }

                // Partner-only apps (ones I don't track but partner does)
                let myBundleIds = Set(vm.appLimits.map(\.bundleIdentifier))
                let partnerOnlyLimits = vm.partnerLimits.filter { !myBundleIds.contains($0.bundleIdentifier) }
                if !partnerOnlyLimits.isEmpty {
                    Text("\(vm.partnerName)'s apps")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundColor(Color(hex: AppTheme.lavenderDark))
                        .textCase(.uppercase)
                        .padding(.top, 4)

                    ForEach(partnerOnlyLimits) { limit in
                        AppUsageCard(
                            limit: limit,
                            myUsage: 0,
                            myLimit: nil,
                            partnerUsage: vm.partnerUsage[limit.bundleIdentifier] ?? 0,
                            partnerLimit: limit.dailyLimitMinutes,
                            myName: vm.myName,
                            partnerName: vm.partnerName,
                            onProposeLimitChange: nil
                        )
                    }
                }
            }

            // Mini Garden Preview
            Button {
                vm.selectedTab = .garden
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("your garden")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: AppTheme.mintDark))
                        if let active = vm.activePlant {
                            Text("growing \(active.shopPlant?.name ?? "plant") — \(active.daysProgress)/\(active.daysRequired) days")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(Color(hex: AppTheme.mint))
                        } else {
                            Text("\(vm.gardenPlants.count) plants grown — pick a new one!")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(Color(hex: AppTheme.mint))
                        }
                    }
                    Spacer()
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: AppTheme.mintDark))
                }
                .padding(16)
                .background(
                    LinearGradient(
                        colors: [Color(hex: AppTheme.mint).opacity(0.3), Color(hex: AppTheme.honey).opacity(0.2)],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color(hex: AppTheme.mint).opacity(0.3), lineWidth: 1)
                )
            }

            // Auto day-end status
            HStack(spacing: 8) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: AppTheme.lavender))
                Text("garden grows automatically at midnight")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(Color(hex: AppTheme.bark).opacity(0.4))
            }
            .padding(.vertical, 6)

            // Connection status
            HStack(spacing: 6) {
                Circle()
                    .fill(vm.isPaired ? Color(hex: AppTheme.mintDark) : Color(hex: AppTheme.honey))
                    .frame(width: 8, height: 8)
                Text(vm.isPaired ? "connected to \(vm.partnerName)" : "waiting for partner...")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(Color(hex: AppTheme.bark).opacity(0.4))
            }
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - App Usage Card
struct AppUsageCard: View {
    let limit: AppLimitConfig
    let myUsage: Int
    let myLimit: Int?           // nil if I don't track this app
    let partnerUsage: Int
    let partnerLimit: Int?      // nil if partner doesn't track this app
    let myName: String
    let partnerName: String
    let onProposeLimitChange: ((Int) -> Void)?

    @State private var showLimitPicker = false
    @State private var showCustomInput = false
    @State private var customMinutes = ""
    let limitOptions = [15, 30, 45, 60, 90, 120]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                AppBrandIcon(bundleId: limit.bundleIdentifier, size: 32)

                Text(limit.appName)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: AppTheme.charcoal))

                Spacer()

                if let myLim = myLimit, onProposeLimitChange != nil {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showLimitPicker.toggle()
                            if !showLimitPicker { showCustomInput = false }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(formatMins(myLim))
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 12))
                        }
                        .foregroundColor(Color(hex: limit.colorHex).opacity(0.7))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color(hex: limit.colorHex).opacity(0.08))
                        .cornerRadius(10)
                    }
                }
            }

            if showLimitPicker {
                VStack(alignment: .leading, spacing: 8) {
                    Text("propose new limit")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: AppTheme.bark).opacity(0.4))

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(limitOptions, id: \.self) { mins in
                                Button {
                                    onProposeLimitChange?(mins)
                                    showLimitPicker = false
                                    showCustomInput = false
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
                                    onProposeLimitChange?(mins)
                                    showLimitPicker = false
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

                    Text("your partner will be asked to approve")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundColor(Color(hex: AppTheme.honey))
                }
                .padding(.top, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if let myLim = myLimit {
                UsageBar(
                    name: myName,
                    used: myUsage,
                    limit: myLim,
                    color: Color(hex: AppTheme.roseDark),
                    isOver: myUsage >= myLim
                )
            }

            if let pLim = partnerLimit {
                UsageBar(
                    name: partnerName,
                    used: partnerUsage,
                    limit: pLim,
                    color: Color(hex: AppTheme.lavenderDark),
                    isOver: partnerUsage >= pLim
                )
            } else {
                HStack {
                    Text("\(partnerName) doesn't track this app")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(Color(hex: AppTheme.bark).opacity(0.3))
                }
            }
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color(hex: AppTheme.bark).opacity(0.05), radius: 8, y: 3)
    }

    func formatMins(_ m: Int) -> String {
        m >= 60 ? "\(m/60)h\(m%60 > 0 ? " \(m%60)m" : "")" : "\(m)m"
    }
}

struct UsageBar: View {
    let name: String
    let used: Int
    let limit: Int
    let color: Color
    let isOver: Bool

    var body: some View {
        VStack(spacing: 3) {
            HStack {
                Text(name)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(isOver ? Color(hex: AppTheme.roseDark) : Color(hex: AppTheme.bark).opacity(0.5))
                Spacer()
                Text(formatMins(used))
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(isOver ? Color(hex: AppTheme.roseDark) : Color(hex: AppTheme.bark).opacity(0.5))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color(hex: AppTheme.cloud))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 5)
                        .fill(
                            isOver
                                ? LinearGradient(colors: [Color(hex: AppTheme.roseDark), Color(hex: AppTheme.rose)], startPoint: .leading, endPoint: .trailing)
                                : LinearGradient(colors: [color.opacity(0.4), color.opacity(0.7)], startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(width: geo.size.width * min(CGFloat(used) / CGFloat(max(limit, 1)), 1.0), height: 8)
                        .animation(.easeInOut(duration: 0.5), value: used)
                }
            }
            .frame(height: 8)
        }
    }

    func formatMins(_ m: Int) -> String {
        m >= 60 ? "\(m/60)h \(m%60)m" : "\(m)m"
    }
}

// MARK: - App Icon View
/// Loads real app icons from the iTunes API for known apps, falls back to SF Symbols
struct AppBrandIcon: View {
    let bundleId: String
    let size: CGFloat

    /// iTunes App Store IDs for known apps — used to fetch real icons
    private var itunesId: String? {
        switch bundleId {
        case "com.burbn.instagram": return "389801252"
        case "com.google.ios.youtube": return "544007664"
        case "com.atebits.Tweetie2": return "333903271"
        case "com.facebook.Facebook": return "284882215"
        case "com.zhiliaoapp.musically": return "835599320"
        default: return nil
        }
    }

    private var iconURL: URL? {
        guard let id = itunesId else { return nil }
        return URL(string: "https://is1-ssl.mzstatic.com/image/thumb/Purple211/v4/\(id)/AppIcon-0-0-1x_U007emarketing-0-7-0-85-220.png/120x120bb.jpg")
    }

    /// Direct artwork URLs that are stable and don't need the lookup API
    private var artworkURL: URL? {
        guard let id = itunesId else { return nil }
        // Use iTunes lookup to get the icon — we'll use AsyncImage with the lookup endpoint
        return URL(string: "https://itunes.apple.com/lookup?id=\(id)")
    }

    var body: some View {
        if let id = itunesId {
            ITunesAppIcon(itunesId: id, size: size)
        } else {
            // Fallback for non-major apps: SF Symbol style
            let app = TrackedApp(rawValue: bundleId)
            let color = Color(hex: app?.colorHex ?? "#888888")
            Circle()
                .fill(color.opacity(0.15))
                .frame(width: size, height: size)
                .overlay(
                    Image(systemName: app?.iconName ?? "app.fill")
                        .foregroundColor(color.opacity(0.8))
                        .font(.system(size: size * 0.4, weight: .bold))
                )
        }
    }
}

/// Fetches and displays an app icon from the iTunes Search API
struct ITunesAppIcon: View {
    let itunesId: String
    let size: CGFloat
    @State private var iconURL: URL?

    var body: some View {
        Group {
            if let url = iconURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: size, height: size)
                            .clipShape(RoundedRectangle(cornerRadius: size * 0.22))
                    case .failure:
                        fallbackIcon
                    case .empty:
                        RoundedRectangle(cornerRadius: size * 0.22)
                            .fill(Color(hex: AppTheme.cloud))
                            .frame(width: size, height: size)
                    @unknown default:
                        fallbackIcon
                    }
                }
            } else {
                fallbackIcon
            }
        }
        .task {
            await loadIconURL()
        }
    }

    private var fallbackIcon: some View {
        RoundedRectangle(cornerRadius: size * 0.22)
            .fill(Color(hex: AppTheme.cloud))
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: "app.fill")
                    .font(.system(size: size * 0.4))
                    .foregroundColor(Color(hex: AppTheme.bark).opacity(0.3))
            )
    }

    private func loadIconURL() async {
        // Check cache first
        if let cached = ITunesIconCache.shared.cache[itunesId] {
            iconURL = cached
            return
        }

        guard let url = URL(string: "https://itunes.apple.com/lookup?id=\(itunesId)") else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let results = json["results"] as? [[String: Any]],
               let first = results.first,
               let artworkUrl = first["artworkUrl512"] as? String,
               let parsed = URL(string: artworkUrl) {
                ITunesIconCache.shared.cache[itunesId] = parsed
                await MainActor.run { iconURL = parsed }
            }
        } catch {
            print("[AppIcon] Failed to load icon for \(itunesId): \(error)")
        }
    }
}

/// Simple in-memory cache for iTunes icon URLs so we don't re-fetch every time
class ITunesIconCache {
    static let shared = ITunesIconCache()
    var cache: [String: URL] = [:]
}
