import Foundation
import FamilyControls
import ManagedSettings
import CloudKit

// MARK: - Theme Colors (soft, hand-drawn aesthetic)
struct AppTheme {
    static let rose = "#F2A0A0"
    static let roseDark = "#E07070"
    static let lavender = "#B8A9E8"
    static let lavenderDark = "#8B7AC7"
    static let mint = "#A8DFC8"
    static let mintDark = "#6BBF96"
    static let honey = "#F5D88E"
    static let honeyDark = "#E8C25E"
    static let peach = "#F5C5A3"
    static let sky = "#A8D5E8"
    static let cream = "#FFF8F0"
    static let bark = "#8B6F5A"
    static let charcoal = "#4A4A4A"
    static let cloud = "#F0EDE8"
}

// MARK: - App Limit Model
struct AppLimitConfig: Codable, Identifiable {
    let id: UUID
    var appName: String
    var bundleIdentifier: String
    var dailyLimitMinutes: Int
    var iconName: String
    var colorHex: String

    init(appName: String, bundleIdentifier: String, dailyLimitMinutes: Int, iconName: String, colorHex: String) {
        self.id = UUID()
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.dailyLimitMinutes = dailyLimitMinutes
        self.iconName = iconName
        self.colorHex = colorHex
    }
}

// MARK: - Tracked App Presets
enum TrackedApp: String, CaseIterable, Identifiable {
    case instagram = "com.burbn.instagram"
    case youtube = "com.google.ios.youtube"
    case twitter = "com.atebits.Tweetie2"
    case facebook = "com.facebook.Facebook"
    case tiktok = "com.zhiliaoapp.musically"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .instagram: return "Instagram"
        case .youtube: return "YouTube"
        case .twitter: return "Twitter / X"
        case .facebook: return "Facebook"
        case .tiktok: return "TikTok"
        }
    }

    var iconName: String {
        switch self {
        case .instagram: return "camera.filters"
        case .youtube: return "play.rectangle.fill"
        case .twitter: return "at"
        case .facebook: return "f.cursive"
        case .tiktok: return "music.note"
        }
    }

    /// Short letter/symbol used for custom app icon rendering
    var iconLetter: String {
        switch self {
        case .instagram: return "Ig"
        case .youtube: return "▶"
        case .twitter: return "𝕏"
        case .facebook: return "f"
        case .tiktok: return "♪"
        }
    }

    var colorHex: String {
        switch self {
        case .instagram: return "#E1306C"
        case .youtube: return "#FF0000"
        case .twitter: return "#1DA1F2"
        case .facebook: return "#1877F2"
        case .tiktok: return "#010101"
        }
    }

    func toConfig(limitMinutes: Int) -> AppLimitConfig {
        AppLimitConfig(
            appName: displayName,
            bundleIdentifier: rawValue,
            dailyLimitMinutes: limitMinutes,
            iconName: iconName,
            colorHex: colorHex
        )
    }
}

// MARK: - Usage Record
struct UsageRecord: Codable, Identifiable {
    let id: UUID
    let date: Date
    var appBundleId: String
    var usedMinutes: Int
    var partnerId: String

    init(date: Date, appBundleId: String, usedMinutes: Int, partnerId: String) {
        self.id = UUID()
        self.date = date
        self.appBundleId = appBundleId
        self.usedMinutes = usedMinutes
        self.partnerId = partnerId
    }
}

// MARK: - Approval Request
struct ApprovalRequest: Codable, Identifiable {
    let id: UUID
    let requesterId: String
    let approverId: String
    let appBundleId: String
    let appDisplayName: String
    let requestedAt: Date
    var status: ApprovalStatus
    var respondedAt: Date?
    var extraMinutesGranted: Int?

    init(requesterId: String, approverId: String, appBundleId: String, appDisplayName: String) {
        self.id = UUID()
        self.requesterId = requesterId
        self.approverId = approverId
        self.appBundleId = appBundleId
        self.appDisplayName = appDisplayName
        self.requestedAt = Date()
        self.status = .pending
    }
}

enum ApprovalStatus: String, Codable {
    case pending
    case approved
    case denied
}

// MARK: - Partner Profile
struct PartnerProfile: Codable, Identifiable {
    let id: String
    var displayName: String
    var deviceToken: String?
    var avatarColorHex: String
    var avatarId: String      // References AvatarConfig.id
    var joinedAt: Date

    init(id: String = UUID().uuidString, displayName: String, avatarColorHex: String, avatarId: String = "avatar_01") {
        self.id = id
        self.displayName = displayName
        self.avatarColorHex = avatarColorHex
        self.avatarId = avatarId
        self.joinedAt = Date()
    }

    // Custom decoder to handle old profiles without avatarId
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        displayName = try container.decode(String.self, forKey: .displayName)
        deviceToken = try container.decodeIfPresent(String.self, forKey: .deviceToken)
        avatarColorHex = try container.decode(String.self, forKey: .avatarColorHex)
        avatarId = try container.decodeIfPresent(String.self, forKey: .avatarId) ?? "avatar_01"
        joinedAt = try container.decode(Date.self, forKey: .joinedAt)
    }

    /// Resolved avatar config from the catalog
    var avatar: AvatarConfig? {
        avatarCatalog.first { $0.id == avatarId }
    }
}

// MARK: - Couple (Partnership)
struct Couple: Codable, Identifiable {
    let id: String
    var partner1Id: String
    var partner2Id: String?
    var appLimits: [AppLimitConfig]
    var createdAt: Date
    var gardenPlants: [GardenPlant]
    var currentStreak: Int
    var longestStreak: Int
    var unlockedPlantTypes: [String]  // Plant types unlocked by streak milestones

    init(pairingCode: String, partner1Id: String) {
        self.id = pairingCode
        self.partner1Id = partner1Id
        self.partner2Id = nil
        self.appLimits = []
        self.createdAt = Date()
        self.gardenPlants = []
        self.currentStreak = 0
        self.longestStreak = 0
        self.unlockedPlantTypes = ["daisy", "tulip"]
    }
}

// MARK: - Shop Plant Types (catalog of plants to grow)
struct ShopPlant: Identifiable {
    let id: String
    let name: String
    let daysToGrow: Int
    let description: String
    let colorHex: String
    let iconStages: [String]  // emoji for each visual stage

    /// Visual progress stages based on percentage complete
    func stageIndex(forProgress progress: Double) -> Int {
        let idx = Int(progress * Double(iconStages.count - 1))
        return min(max(idx, 0), iconStages.count - 1)
    }
}

/// All available plants in the shop
let plantShop: [ShopPlant] = [
    ShopPlant(
        id: "daisy",
        name: "Daisy",
        daysToGrow: 3,
        description: "A cheerful little flower. Quick to bloom!",
        colorHex: AppTheme.honey,
        iconStages: ["seed", "sprout", "sapling", "flowerTree"]
    ),
    ShopPlant(
        id: "tulip",
        name: "Tulip",
        daysToGrow: 5,
        description: "Elegant and colorful. A garden classic.",
        colorHex: AppTheme.roseDark,
        iconStages: ["seed", "sprout", "sapling", "bush", "flowerTree"]
    ),
    ShopPlant(
        id: "sunflower",
        name: "Sunflower",
        daysToGrow: 7,
        description: "Tall and bright. Stands proud in any garden.",
        colorHex: AppTheme.honeyDark,
        iconStages: ["seed", "sprout", "sapling", "bush", "tree", "flowerTree"]
    ),
    ShopPlant(
        id: "bonsai",
        name: "Bonsai",
        daysToGrow: 10,
        description: "A patient gardener's reward. Small but mighty.",
        colorHex: AppTheme.mintDark,
        iconStages: ["seed", "sprout", "sapling", "bush", "tree", "bigTree"]
    ),
    ShopPlant(
        id: "cherry_blossom",
        name: "Cherry Blossom",
        daysToGrow: 14,
        description: "Beautiful pink blossoms. Worth the wait.",
        colorHex: AppTheme.rose,
        iconStages: ["seed", "sprout", "sapling", "bush", "tree", "bigTree", "flowerTree"]
    ),
    ShopPlant(
        id: "oak",
        name: "Oak Tree",
        daysToGrow: 21,
        description: "Strong and enduring. A true commitment.",
        colorHex: AppTheme.bark,
        iconStages: ["seed", "sprout", "sapling", "bush", "tree", "bigTree", "flowerTree"]
    ),
    ShopPlant(
        id: "wisteria",
        name: "Wisteria",
        daysToGrow: 30,
        description: "Cascading purple blooms. A masterpiece of patience.",
        colorHex: AppTheme.lavenderDark,
        iconStages: ["seed", "sprout", "sapling", "bush", "tree", "bigTree", "flowerTree"]
    ),
]

// MARK: - Garden Plant (actively growing or completed)
struct GardenPlant: Codable, Identifiable {
    let id: UUID
    var shopPlantId: String           // which shop plant this is
    var plantedDate: Date
    var daysProgress: Int             // how many on-track days so far
    var daysRequired: Int             // total days needed
    var isComplete: Bool
    var completedDate: Date?
    var gridX: Int
    var gridY: Int
    var plantedBy: String
    var appContributions: [PlantAppContribution]
    var penaltyDays: Int              // Growing plants: each extension adds 2 penalty days (slows growth)
    var weatheringDays: Int            // Completed plants: accumulated weathering damage
    var weatheringRecoveryDays: Int    // Days remaining until current weathering heals
    var isDead: Bool                   // Plant died from too much weathering

    init(shopPlantId: String, daysRequired: Int, gridX: Int, gridY: Int, plantedBy: String) {
        self.id = UUID()
        self.shopPlantId = shopPlantId
        self.plantedDate = Date()
        self.daysProgress = 0
        self.daysRequired = daysRequired
        self.isComplete = false
        self.completedDate = nil
        self.gridX = gridX
        self.gridY = gridY
        self.plantedBy = plantedBy
        self.appContributions = []
        self.penaltyDays = 0
        self.weatheringDays = 0
        self.weatheringRecoveryDays = 0
        self.isDead = false
    }

    // Custom decoder to handle existing plants without newer fields
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        shopPlantId = try container.decode(String.self, forKey: .shopPlantId)
        plantedDate = try container.decode(Date.self, forKey: .plantedDate)
        daysProgress = try container.decode(Int.self, forKey: .daysProgress)
        daysRequired = try container.decode(Int.self, forKey: .daysRequired)
        isComplete = try container.decode(Bool.self, forKey: .isComplete)
        completedDate = try container.decodeIfPresent(Date.self, forKey: .completedDate)
        gridX = try container.decode(Int.self, forKey: .gridX)
        gridY = try container.decode(Int.self, forKey: .gridY)
        plantedBy = try container.decode(String.self, forKey: .plantedBy)
        appContributions = try container.decode([PlantAppContribution].self, forKey: .appContributions)
        penaltyDays = try container.decodeIfPresent(Int.self, forKey: .penaltyDays) ?? 0
        weatheringDays = try container.decodeIfPresent(Int.self, forKey: .weatheringDays) ?? 0
        weatheringRecoveryDays = try container.decodeIfPresent(Int.self, forKey: .weatheringRecoveryDays) ?? 0
        isDead = try container.decodeIfPresent(Bool.self, forKey: .isDead) ?? false
    }

    /// Progress from 0.0 to 1.0 (penalty days reduce effective progress)
    var progress: Double {
        guard daysRequired > 0 else { return 1.0 }
        let effectiveProgress = max(0, daysProgress - penaltyDays)
        return min(Double(effectiveProgress) / Double(daysRequired), 1.0)
    }

    /// Weathering damage as a fraction of growth days (0.0 = healthy, 0.7+ = dead)
    var weatheringFraction: Double {
        guard daysRequired > 0 else { return 0.0 }
        return Double(weatheringDays) / Double(daysRequired)
    }

    /// Weathering visual stage for completed plants
    var weatheringStage: WeatheringStage {
        if isDead { return .dead }
        if weatheringRecoveryDays > 0 { return .recovering }
        let fraction = weatheringFraction
        if fraction <= 0 { return .healthy }
        if fraction < 0.15 { return .slightlyWilted }
        if fraction < 0.3 { return .wilted }
        if fraction < 0.5 { return .heavilyWilted }
        if fraction < 0.7 { return .dying }
        return .dead
    }

    /// Get the current visual stage name (maps to PlantStage for rendering)
    var currentStage: PlantStage {
        if isDead { return .seed }
        if isComplete { return .flowerTree }
        let fraction = progress
        if fraction <= 0 { return .seed }
        if fraction < 0.15 { return .sprout }
        if fraction < 0.3 { return .sapling }
        if fraction < 0.5 { return .bush }
        if fraction < 0.75 { return .tree }
        if fraction < 0.95 { return .bigTree }
        return .flowerTree
    }

    /// Days remaining
    var daysRemaining: Int {
        max(0, daysRequired - daysProgress)
    }

    /// Shop plant metadata lookup
    var shopPlant: ShopPlant? {
        plantShop.first { $0.id == shopPlantId }
    }

    /// Apply weathering to a completed plant: +2 damage days, 2 days to recover
    /// Returns true if the plant dies from this weathering
    mutating func applyWeathering() -> Bool {
        guard isComplete && !isDead else { return false }
        weatheringDays += 2
        weatheringRecoveryDays = 2
        if weatheringFraction >= 0.7 {
            isDead = true
            return true
        }
        return false
    }

    /// Tick one day of recovery at day end (when no new penalty occurred)
    mutating func tickRecovery() {
        guard isComplete && !isDead else { return }
        if weatheringRecoveryDays > 0 {
            weatheringRecoveryDays -= 1
        }
    }
}

/// Weathering stages for completed plants — each has a distinct visual
enum WeatheringStage: String, CaseIterable {
    case healthy           // Full color, no damage
    case recovering        // Slightly muted, healing animation
    case slightlyWilted    // < 15% — leaves slightly droopy, subtle desaturation
    case wilted            // 15-30% — noticeable droop, color fading
    case heavilyWilted     // 30-50% — heavy droop, brown edges
    case dying             // 50-70% — mostly brown, about to die
    case dead              // >= 70% — grey/dead, plant is gone
}

/// Tracks how much time was saved on each app
struct PlantAppContribution: Codable, Identifiable {
    let id: UUID
    var appName: String
    var appIconName: String
    var appColorHex: String
    var limitMinutes: Int
    var usedMinutes: Int
    var minutesSaved: Int

    init(appName: String, iconName: String, colorHex: String, limitMinutes: Int, usedMinutes: Int) {
        self.id = UUID()
        self.appName = appName
        self.appIconName = iconName
        self.appColorHex = colorHex
        self.limitMinutes = limitMinutes
        self.usedMinutes = usedMinutes
        self.minutesSaved = max(0, limitMinutes - usedMinutes)
    }
}

enum PlantStage: String, CaseIterable {
    case seed
    case sprout
    case sapling
    case bush
    case tree
    case bigTree
    case flowerTree

    var displayName: String {
        switch self {
        case .seed: return "Seed"
        case .sprout: return "Sprout"
        case .sapling: return "Sapling"
        case .bush: return "Bush"
        case .tree: return "Tree"
        case .bigTree: return "Big Tree"
        case .flowerTree: return "Flower Tree"
        }
    }

    var minDays: Int {
        switch self {
        case .seed: return 0
        case .sprout: return 1
        case .sapling: return 3
        case .bush: return 7
        case .tree: return 14
        case .bigTree: return 21
        case .flowerTree: return 30
        }
    }

    static func forAge(_ days: Int) -> PlantStage {
        let sorted = PlantStage.allCases.sorted { $0.minDays > $1.minDays }
        return sorted.first { days >= $0.minDays } ?? .seed
    }
}

// MARK: - Avatar System

/// A character avatar with customizable appearance
struct AvatarConfig: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let hairStyle: HairStyle
    let hairColorHex: String
    let skinColorHex: String
    let outfitStyle: OutfitStyle
    let outfitColorHex: String
    let accessory: AvatarAccessory

    enum HairStyle: String, Codable, CaseIterable {
        case bob           // Short bob cut
        case long          // Long flowing hair
        case fluffy        // Fluffy/curly round hair
        case spiky         // Short spiky hair
        case ponytail      // Ponytail
        case buzzcut       // Very short / buzzcut
    }

    enum OutfitStyle: String, Codable, CaseIterable {
        case dress         // A-line dress
        case shirtPants    // Shirt + pants combo
        case hoodie        // Casual hoodie
        case overalls      // Cute overalls
    }

    enum AvatarAccessory: String, Codable, CaseIterable {
        case none
        case glasses
        case hat
        case bow
        case headband
        case flower
    }
}

/// Pre-built avatar options for the picker
/// Balanced 50/50: 6 feminine-presenting, 6 masculine-presenting
let avatarCatalog: [AvatarConfig] = [
    // Row 1 — Mixed
    AvatarConfig(id: "avatar_01", name: "Sunny", hairStyle: .bob, hairColorHex: "#8B6F5A",
                 skinColorHex: "#FFE4D6", outfitStyle: .dress, outfitColorHex: "#F5D88E", accessory: .none),
    AvatarConfig(id: "avatar_02", name: "Kai", hairStyle: .spiky, hairColorHex: "#4A4A4A",
                 skinColorHex: "#FFCC80", outfitStyle: .shirtPants, outfitColorHex: "#6BBF96", accessory: .none),
    AvatarConfig(id: "avatar_03", name: "Rosie", hairStyle: .long, hairColorHex: "#6B5A4A",
                 skinColorHex: "#FFE4D6", outfitStyle: .dress, outfitColorHex: "#F2A0A0", accessory: .bow),
    AvatarConfig(id: "avatar_04", name: "Milo", hairStyle: .buzzcut, hairColorHex: "#2C1810",
                 skinColorHex: "#8D5524", outfitStyle: .hoodie, outfitColorHex: "#6BBF96", accessory: .glasses),
    // Row 2 — Mixed
    AvatarConfig(id: "avatar_05", name: "Luna", hairStyle: .fluffy, hairColorHex: "#3D2B1F",
                 skinColorHex: "#D4A574", outfitStyle: .dress, outfitColorHex: "#B8A9E8", accessory: .headband),
    AvatarConfig(id: "avatar_06", name: "Ash", hairStyle: .spiky, hairColorHex: "#8B6F5A",
                 skinColorHex: "#FFCC80", outfitStyle: .shirtPants, outfitColorHex: "#4A4A4A", accessory: .hat),
    AvatarConfig(id: "avatar_07", name: "Jade", hairStyle: .bob, hairColorHex: "#1A1A2E",
                 skinColorHex: "#FFCC80", outfitStyle: .dress, outfitColorHex: "#A8DFC8", accessory: .flower),
    AvatarConfig(id: "avatar_08", name: "Rex", hairStyle: .buzzcut, hairColorHex: "#C27A42",
                 skinColorHex: "#FFE4D6", outfitStyle: .shirtPants, outfitColorHex: "#A8D5E8", accessory: .none),
    // Row 3 — Mixed
    AvatarConfig(id: "avatar_09", name: "Fern", hairStyle: .long, hairColorHex: "#1A1A2E",
                 skinColorHex: "#D4A574", outfitStyle: .dress, outfitColorHex: "#6BAF6A", accessory: .headband),
    AvatarConfig(id: "avatar_10", name: "Leo", hairStyle: .fluffy, hairColorHex: "#3D2B1F",
                 skinColorHex: "#FFCC80", outfitStyle: .hoodie, outfitColorHex: "#E8C25E", accessory: .none),
    AvatarConfig(id: "avatar_11", name: "Peach", hairStyle: .ponytail, hairColorHex: "#C27A42",
                 skinColorHex: "#FFE4D6", outfitStyle: .dress, outfitColorHex: "#FFB7C5", accessory: .bow),
    AvatarConfig(id: "avatar_12", name: "Blake", hairStyle: .spiky, hairColorHex: "#2C1810",
                 skinColorHex: "#8D5524", outfitStyle: .shirtPants, outfitColorHex: "#F5C5A3", accessory: .glasses),
]

// MARK: - Goal Proposal (for limit negotiation between partners)
struct GoalProposal: Codable, Identifiable {
    let id: UUID
    var proposerLimits: [AppLimitConfig]   // limits the proposer sets for themselves
    var partnerLimits: [AppLimitConfig]    // limits the proposer sets for their partner
    var proposerId: String
    var round: Int
    var status: ProposalStatus
    var checkInFrequency: CheckInFrequency

    enum ProposalStatus: String, Codable {
        case pending    // waiting for partner review
        case approved   // partner accepted
        case revised    // partner made changes and sent back
    }

    init(proposerLimits: [AppLimitConfig], partnerLimits: [AppLimitConfig],
         proposerId: String, round: Int = 1, checkInFrequency: CheckInFrequency = .weekly) {
        self.id = UUID()
        self.proposerLimits = proposerLimits
        self.partnerLimits = partnerLimits
        self.proposerId = proposerId
        self.round = round
        self.status = .pending
        self.checkInFrequency = checkInFrequency
    }
}

// MARK: - Check-In Frequency
enum CheckInFrequency: String, Codable, CaseIterable, Identifiable {
    case weekly = "weekly"
    case biweekly = "biweekly"
    case monthly = "monthly"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .weekly: return "Weekly"
        case .biweekly: return "Every 2 Weeks"
        case .monthly: return "Monthly"
        }
    }

    var days: Int {
        switch self {
        case .weekly: return 7
        case .biweekly: return 14
        case .monthly: return 30
        }
    }

    var iconName: String {
        switch self {
        case .weekly: return "calendar.badge.clock"
        case .biweekly: return "calendar"
        case .monthly: return "calendar.circle"
        }
    }

    var subtitle: String {
        switch self {
        case .weekly: return "Stay on top of things"
        case .biweekly: return "A balanced rhythm"
        case .monthly: return "For the patient gardener"
        }
    }
}

// MARK: - Plant Type (unlockable via streak milestones)
enum PlantType: String, CaseIterable {
    case daisy
    case tulip
    case sunflower
    case cherryBlossom
    case lavender
    case wisteria
    case goldenFlower

    var displayName: String {
        switch self {
        case .daisy: return "Daisy"
        case .tulip: return "Tulip"
        case .sunflower: return "Sunflower"
        case .cherryBlossom: return "Cherry Blossom"
        case .lavender: return "Lavender"
        case .wisteria: return "Wisteria"
        case .goldenFlower: return "Golden Flower"
        }
    }

    /// Streak days needed to unlock this plant type (0 = available by default)
    var unlockStreakDays: Int {
        switch self {
        case .daisy: return 0
        case .tulip: return 0
        case .sunflower: return 7
        case .cherryBlossom: return 14
        case .lavender: return 30
        case .wisteria: return 60
        case .goldenFlower: return 100
        }
    }
}

// MARK: - Limit Suggestion (suggest changes to partner's limits)
struct LimitSuggestion: Codable, Identifiable {
    let id: UUID
    let fromPartnerId: String
    let toPartnerId: String
    let appBundleId: String
    let appDisplayName: String
    let suggestedMinutes: Int
    let currentMinutes: Int
    var status: SuggestionStatus
    let createdAt: Date
    var respondedAt: Date?

    init(fromPartnerId: String, toPartnerId: String, appBundleId: String,
         appDisplayName: String, suggestedMinutes: Int, currentMinutes: Int) {
        self.id = UUID()
        self.fromPartnerId = fromPartnerId
        self.toPartnerId = toPartnerId
        self.appBundleId = appBundleId
        self.appDisplayName = appDisplayName
        self.suggestedMinutes = suggestedMinutes
        self.currentMinutes = currentMinutes
        self.status = .pending
        self.createdAt = Date()
    }
}

enum SuggestionStatus: String, Codable {
    case pending
    case accepted
    case rejected
}

// MARK: - Day Result
struct DayResult: Codable, Identifiable {
    let id: UUID
    let date: Date
    var allGoalsMet: Bool
    var partner1GoalsMet: Bool
    var partner2GoalsMet: Bool

    init(date: Date, partner1Met: Bool, partner2Met: Bool) {
        self.id = UUID()
        self.date = date
        self.partner1GoalsMet = partner1Met
        self.partner2GoalsMet = partner2Met
        self.allGoalsMet = partner1Met && partner2Met
    }
}
