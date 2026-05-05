import SwiftUI

// MARK: - Paper Cutout Diorama Garden View
struct GardenView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var selectedPlant: GardenPlant?
    @State private var showPlantDetail = false
    @State private var showShop = false

    // Character walking animation
    @State private var char1Position: CGPoint = .zero
    @State private var char2Position: CGPoint = .zero
    @State private var char1Target: CGPoint = .zero
    @State private var char2Target: CGPoint = .zero
    @State private var char1FacingRight = true
    @State private var char2FacingRight = false
    @State private var walkTimer: Timer?
    @State private var stepToggle = false

    var body: some View {
        VStack(spacing: 14) {
            // Garden title
            VStack(spacing: 4) {
                HStack(spacing: 0) {
                    Text(vm.myName)
                        .foregroundColor(Color(hex: AppTheme.roseDark))
                    Text(" & ")
                        .foregroundColor(Color(hex: AppTheme.bark).opacity(0.35))
                    Text(vm.partnerName)
                        .foregroundColor(Color(hex: AppTheme.lavenderDark))
                    Text("'s")
                        .foregroundColor(Color(hex: AppTheme.bark).opacity(0.5))
                }
                .font(.system(size: 22, weight: .heavy, design: .rounded))

                Text("garden")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: AppTheme.mintDark))
                    .tracking(3)
                    .textCase(.uppercase)

                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(hex: AppTheme.honey))
                        .frame(width: 6, height: 6)
                    Text("\(vm.streak) day streak")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: AppTheme.bark).opacity(0.5))
                }
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 10)
            .padding(.bottom, 4)

            // Paper cutout garden diorama
            ZStack {
                gardenBackground
                gardenHills
                gardenFence
                gardenDecorations

                // Completed plants (tappable)
                ForEach(vm.gardenPlants) { plant in
                    PaperPlantView(plant: plant, isSelected: selectedPlant?.id == plant.id)
                        .position(
                            x: CGFloat(plant.gridX) / 20 * gardenWidth,
                            y: CGFloat(plant.gridY) / 16 * gardenHeight
                        )
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedPlant = plant
                            }
                            // Show "tap for details" briefly, then open sheet
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                showPlantDetail = true
                            }
                        }
                }

                // Active plant (growing)
                if let active = vm.activePlant {
                    VStack(spacing: 2) {
                        Text("\(active.daysProgress)/\(active.daysRequired)")
                            .font(.system(size: 8, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color(hex: AppTheme.mintDark).opacity(0.85))
                            .cornerRadius(8)
                        PaperTypedPlantSprite(plantId: active.shopPlantId, stage: active.currentStage, scale: 1.0)
                    }
                    .position(
                        x: CGFloat(active.gridX) / 20 * gardenWidth,
                        y: CGFloat(active.gridY) / 16 * gardenHeight
                    )
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedPlant = active
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            showPlantDetail = true
                        }
                    }
                }

                // Walking characters
                characterSprites

                // Butterflies
                paperButterflies
            }
            .frame(height: gardenHeight)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: Color(hex: AppTheme.bark).opacity(0.1), radius: 12, y: 6)
            .onAppear { startWalking() }
            .onDisappear { walkTimer?.invalidate() }

            // Active Plant Progress Card
            if let active = vm.activePlant {
                activePlantCard(active)
            } else {
                Button {
                    showShop = true
                } label: {
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color(hex: AppTheme.mint).opacity(0.2))
                                .frame(width: 46, height: 46)
                            Image(systemName: "leaf.fill")
                                .font(.system(size: 22))
                                .foregroundColor(Color(hex: AppTheme.mintDark))
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text("pick a plant to grow")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(Color(hex: AppTheme.charcoal))
                            Text("browse the shop and start growing!")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(Color(hex: AppTheme.bark).opacity(0.5))
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color(hex: AppTheme.mint))
                    }
                    .padding(14)
                    .background(Color.white)
                    .cornerRadius(20)
                    .shadow(color: Color(hex: AppTheme.bark).opacity(0.06), radius: 8, y: 3)
                }
            }

            // Penalty warning
            if vm.activePlant != nil {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: AppTheme.honey))
                    Text("approving extra screen time costs 2 days of progress")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(Color(hex: AppTheme.bark).opacity(0.4))
                }
                .padding(.horizontal, 4)
            }

            // Completed plants list
            if !vm.gardenPlants.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("your plants")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundColor(Color(hex: AppTheme.bark).opacity(0.5))
                        .textCase(.uppercase)
                        .tracking(1)

                    ForEach(vm.gardenPlants.sorted(by: { ($0.completedDate ?? .distantPast) > ($1.completedDate ?? .distantPast) })) { plant in
                        HStack(spacing: 12) {
                            // Mini plant sprite
                            PaperTypedPlantSprite(
                                plantId: plant.shopPlantId,
                                stage: plant.isDead ? .seed : plant.currentStage,
                                scale: 0.5
                            )
                            .frame(width: 32, height: 32)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(plant.shopPlant?.name ?? plant.shopPlantId)
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundColor(
                                            plant.isDead
                                                ? Color(hex: AppTheme.bark).opacity(0.3)
                                                : Color(hex: AppTheme.charcoal)
                                        )
                                    if plant.isDead {
                                        Text("withered")
                                            .font(.system(size: 9, weight: .heavy, design: .rounded))
                                            .foregroundColor(Color(hex: AppTheme.roseDark).opacity(0.6))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color(hex: AppTheme.rose).opacity(0.15))
                                            .cornerRadius(6)
                                    } else if plant.weatheringStage != .healthy {
                                        Text(plant.weatheringStage.rawValue)
                                            .font(.system(size: 9, weight: .heavy, design: .rounded))
                                            .foregroundColor(.orange)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.orange.opacity(0.1))
                                            .cornerRadius(6)
                                    }
                                }
                                HStack(spacing: 4) {
                                    Text("grew in \(plant.daysRequired) days")
                                        .font(.system(size: 11, weight: .medium, design: .rounded))
                                        .foregroundColor(Color(hex: AppTheme.bark).opacity(0.4))
                                    if let date = plant.completedDate {
                                        Text("·")
                                            .foregroundColor(Color(hex: AppTheme.bark).opacity(0.2))
                                        Text(date, style: .date)
                                            .font(.system(size: 11, weight: .medium, design: .rounded))
                                            .foregroundColor(Color(hex: AppTheme.bark).opacity(0.3))
                                    }
                                }
                            }

                            Spacer()

                            if !plant.isDead {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(Color(hex: AppTheme.mintDark).opacity(0.6))
                            } else {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(Color(hex: AppTheme.bark).opacity(0.2))
                            }
                        }
                        .padding(12)
                        .background(Color.white)
                        .cornerRadius(16)
                        .shadow(color: Color(hex: AppTheme.bark).opacity(0.04), radius: 6, y: 2)
                        .onTapGesture {
                            selectedPlant = plant
                            showPlantDetail = true
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .sheet(isPresented: $showPlantDetail, onDismiss: {
            withAnimation(.easeOut(duration: 0.15)) {
                selectedPlant = nil
            }
        }) {
            if let plant = selectedPlant {
                PlantDetailSheet(plant: plant, myName: vm.myName, partnerName: vm.partnerName)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showShop) {
            PlantShopSheet()
                .environmentObject(vm)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Active Plant Progress Card
    func activePlantCard(_ plant: GardenPlant) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(hex: plant.shopPlant?.colorHex ?? AppTheme.mint).opacity(0.15))
                    .frame(width: 46, height: 46)
                Text(plantEmoji(for: plant.shopPlantId))
                    .font(.system(size: 24))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(plant.shopPlant?.name ?? "plant")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: AppTheme.charcoal))
                Text("blooming · day \(plant.daysProgress) of \(plant.daysRequired)")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(hex: AppTheme.bark).opacity(0.5))

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3.5)
                            .fill(Color(hex: AppTheme.cloud))
                            .frame(height: 7)
                        RoundedRectangle(cornerRadius: 3.5)
                            .fill(Color(hex: plant.shopPlant?.colorHex ?? AppTheme.mint))
                            .frame(width: geo.size.width * plant.progress, height: 7)
                    }
                }
                .frame(height: 7)
            }

            Spacer()

            VStack(spacing: 2) {
                Text("\(plant.daysRemaining)")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundColor(Color(hex: plant.shopPlant?.colorHex ?? AppTheme.mintDark))
                Text("days left")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: AppTheme.bark).opacity(0.4))
            }
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color(hex: AppTheme.bark).opacity(0.06), radius: 8, y: 3)
    }

    // MARK: - Walking Logic

    func startWalking() {
        let gw = gardenWidth
        let gh = gardenHeight
        char1Position = CGPoint(x: gw * 0.3, y: gh * 0.78)
        char2Position = CGPoint(x: gw * 0.7, y: gh * 0.82)
        pickNewTarget1()
        pickNewTarget2()

        walkTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            DispatchQueue.main.async {
                stepToggle.toggle()
                withAnimation(.easeInOut(duration: 1.8)) {
                    moveTowardTarget(&char1Position, target: char1Target, facing: &char1FacingRight)
                    moveTowardTarget(&char2Position, target: char2Target, facing: &char2FacingRight)
                }
                if distance(char1Position, char1Target) < 20 { pickNewTarget1() }
                if distance(char2Position, char2Target) < 20 { pickNewTarget2() }
            }
        }
    }

    func pickNewTarget1() {
        char1Target = CGPoint(
            x: CGFloat.random(in: gardenWidth * 0.1...gardenWidth * 0.9),
            y: CGFloat.random(in: gardenHeight * 0.65...gardenHeight * 0.92)
        )
    }

    func pickNewTarget2() {
        char2Target = CGPoint(
            x: CGFloat.random(in: gardenWidth * 0.1...gardenWidth * 0.9),
            y: CGFloat.random(in: gardenHeight * 0.65...gardenHeight * 0.92)
        )
    }

    func moveTowardTarget(_ pos: inout CGPoint, target: CGPoint, facing: inout Bool) {
        let dx = target.x - pos.x
        let dy = target.y - pos.y
        let step: CGFloat = 25
        let dist = sqrt(dx * dx + dy * dy)
        if dist > step {
            pos.x += (dx / dist) * step
            pos.y += (dy / dist) * step
        } else {
            pos = target
        }
        facing = dx > 0
    }

    func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        sqrt(pow(a.x - b.x, 2) + pow(a.y - b.y, 2))
    }

    // MARK: - Garden Dimensions
    var gardenWidth: CGFloat { UIScreen.main.bounds.width - 32 }
    var gardenHeight: CGFloat { 340 }

    // MARK: - Paper Cutout Background (Sky + Clouds + Sun)
    var gardenBackground: some View {
        ZStack {
            // Sky
            Color(hex: "#D4EEFF")

            // Deeper sky layer
            Rectangle()
                .fill(Color(hex: "#C0DEFF").opacity(0.5))
                .frame(height: 120)
                .frame(maxHeight: .infinity, alignment: .top)

            // Clouds — paper cutout style
            paperCloud(at: CGPoint(x: 80, y: 70), scale: 1.0)
            paperCloud(at: CGPoint(x: 250, y: 85), scale: 0.7)
            paperCloud(at: CGPoint(x: 340, y: 60), scale: 0.5)

            // Sun
            paperSun
                .position(x: gardenWidth - 55, y: 60)
        }
    }

    func paperCloud(at pos: CGPoint, scale: CGFloat) -> some View {
        ZStack {
            Ellipse()
                .fill(Color.white.opacity(0.85))
                .frame(width: 60 * scale, height: 24 * scale)
            Ellipse()
                .fill(Color.white.opacity(0.8))
                .frame(width: 34 * scale, height: 18 * scale)
                .offset(x: -12 * scale, y: -4 * scale)
            Ellipse()
                .fill(Color.white.opacity(0.8))
                .frame(width: 38 * scale, height: 18 * scale)
                .offset(x: 12 * scale, y: -3 * scale)
        }
        .shadow(color: Color(hex: AppTheme.bark).opacity(0.06), radius: 2, y: 2)
        .position(pos)
    }

    var paperSun: some View {
        ZStack {
            // Rays as separate paper pieces
            ForEach(0..<4, id: \.self) { i in
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(hex: "#FFE890").opacity(0.6))
                    .frame(width: 8, height: 22)
                    .rotationEffect(.degrees(Double(i) * 45))
            }
            Circle()
                .fill(Color(hex: "#FFE066"))
                .frame(width: 32, height: 32)
            Circle()
                .fill(Color(hex: "#FFD93D"))
                .frame(width: 24, height: 24)
        }
        .shadow(color: Color(hex: AppTheme.bark).opacity(0.08), radius: 3, y: 2)
    }

    // MARK: - Layered Paper Hills
    var gardenHills: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            // Back hill
            PaperHill(color: Color(hex: "#A8D5A0"), yOffset: h * 0.52, amplitude: 20, width: w)
                .shadow(color: Color(hex: AppTheme.bark).opacity(0.08), radius: 3, y: 2)

            // Middle hill
            PaperHill(color: Color(hex: "#8BC48A"), yOffset: h * 0.60, amplitude: 15, width: w)
                .shadow(color: Color(hex: AppTheme.bark).opacity(0.08), radius: 3, y: 2)

            // Front hill
            PaperHill(color: Color(hex: "#6BAF6A"), yOffset: h * 0.68, amplitude: 12, width: w)
                .shadow(color: Color(hex: AppTheme.bark).opacity(0.10), radius: 4, y: 3)
        }
    }

    // MARK: - Paper Fence
    var gardenFence: some View {
        GeometryReader { geo in
            let fenceY = geo.size.height * 0.86
            ZStack {
                // Horizontal rails
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(hex: "#D4B882"))
                    .frame(width: geo.size.width - 40, height: 4)
                    .position(x: geo.size.width / 2, y: fenceY)
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(hex: "#D4B882"))
                    .frame(width: geo.size.width - 40, height: 4)
                    .position(x: geo.size.width / 2, y: fenceY + 12)

                // Vertical posts
                ForEach(0..<11, id: \.self) { i in
                    let x = 30 + CGFloat(i) * ((geo.size.width - 60) / 10)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(hex: "#C4A872"))
                        .frame(width: 7, height: 28)
                        .position(x: x, y: fenceY + 4)
                }
            }
            .opacity(0.45)
        }
    }

    // MARK: - Garden Decorations
    var gardenDecorations: some View {
        GeometryReader { geo in
            // Small ground flowers
            PaperGroundFlower(color: Color(hex: AppTheme.rose))
                .position(x: geo.size.width * 0.08, y: geo.size.height * 0.72)
            PaperGroundFlower(color: Color(hex: AppTheme.lavender))
                .position(x: geo.size.width * 0.92, y: geo.size.height * 0.65)
            PaperGroundFlower(color: Color(hex: AppTheme.honey))
                .position(x: geo.size.width * 0.2, y: geo.size.height * 0.77)
            PaperGroundFlower(color: Color(hex: AppTheme.sky))
                .position(x: geo.size.width * 0.82, y: geo.size.height * 0.80)
        }
    }

    // MARK: - Character Sprites (Paper Cutout Style)
    var characterSprites: some View {
        ZStack {
            // My character
            VStack(spacing: 2) {
                Text(vm.myName)
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: vm.myAvatar.outfitColorHex))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.white.opacity(0.9)).cornerRadius(6)
                PaperCutoutCharacter(avatar: vm.myAvatar, size: 36, stepFrame: stepToggle)
                    .scaleEffect(x: char1FacingRight ? 1 : -1, y: 1)
                    .shadow(color: Color(hex: AppTheme.bark).opacity(0.12), radius: 2, y: 2)
            }
            .position(char1Position)

            // Partner character
            VStack(spacing: 2) {
                Text(vm.partnerName)
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: vm.partnerAvatar.outfitColorHex))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.white.opacity(0.9)).cornerRadius(6)
                PaperCutoutCharacter(avatar: vm.partnerAvatar, size: 36, stepFrame: !stepToggle)
                    .scaleEffect(x: char2FacingRight ? 1 : -1, y: 1)
                    .shadow(color: Color(hex: AppTheme.bark).opacity(0.12), radius: 2, y: 2)
            }
            .position(char2Position)

            // Heart between characters (when close)
            if distance(char1Position, char2Position) < 80 {
                PaperHeart()
                    .position(
                        x: (char1Position.x + char2Position.x) / 2,
                        y: min(char1Position.y, char2Position.y) - 20
                    )
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }

    // MARK: - Paper Butterflies
    var paperButterflies: some View {
        ZStack {
            PaperButterfly(color1: Color(hex: AppTheme.lavender), color2: Color(hex: "#D4C4F0"))
                .position(x: gardenWidth * 0.35, y: gardenHeight * 0.42)
                .opacity(0.6)
            PaperButterfly(color1: Color(hex: "#FFB7C5"), color2: Color(hex: "#FFD0DE"))
                .position(x: gardenWidth * 0.78, y: gardenHeight * 0.50)
                .opacity(0.5)
        }
    }

    // MARK: - Helpers
    func plantEmoji(for plantId: String) -> String {
        switch plantId {
        case "daisy": return "🌼"
        case "tulip": return "🌷"
        case "sunflower": return "🌻"
        case "bonsai": return "🌳"
        case "cherry_blossom": return "🌸"
        case "oak": return "🪵"
        case "wisteria": return "💜"
        default: return "🌱"
        }
    }
}

// MARK: - Paper Hill Shape
struct PaperHill: View {
    let color: Color
    let yOffset: CGFloat
    let amplitude: CGFloat
    let width: CGFloat

    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: yOffset))
            path.addQuadCurve(
                to: CGPoint(x: width * 0.5, y: yOffset - amplitude),
                control: CGPoint(x: width * 0.25, y: yOffset - amplitude * 0.7)
            )
            path.addQuadCurve(
                to: CGPoint(x: width, y: yOffset + 5),
                control: CGPoint(x: width * 0.75, y: yOffset - amplitude * 0.5)
            )
            path.addLine(to: CGPoint(x: width, y: 500))
            path.addLine(to: CGPoint(x: 0, y: 500))
            path.closeSubpath()
        }
        .fill(color)
    }
}

// MARK: - Paper Ground Flower
struct PaperGroundFlower: View {
    let color: Color

    var body: some View {
        ZStack {
            // Stem
            RoundedRectangle(cornerRadius: 1)
                .fill(Color(hex: "#5DA05C"))
                .frame(width: 2, height: 10)
                .offset(y: 6)

            // Petals
            ForEach(0..<5, id: \.self) { i in
                Ellipse()
                    .fill(color)
                    .frame(width: 5, height: 8)
                    .rotationEffect(.degrees(Double(i) * 72))
            }

            // Center
            Circle()
                .fill(Color(hex: AppTheme.honey))
                .frame(width: 4, height: 4)
        }
        .frame(width: 16, height: 22)
    }
}

// MARK: - Paper Butterfly
struct PaperButterfly: View {
    let color1: Color
    let color2: Color

    var body: some View {
        ZStack {
            Ellipse()
                .fill(color1)
                .frame(width: 10, height: 14)
                .rotationEffect(.degrees(-20))
            Ellipse()
                .fill(color2)
                .frame(width: 10, height: 14)
                .rotationEffect(.degrees(20))
            Ellipse()
                .fill(color1.opacity(0.8))
                .frame(width: 2, height: 7)
        }
    }
}

// MARK: - Paper Heart
struct PaperHeart: View {
    var body: some View {
        Canvas { context, size in
            var path = Path()
            let w = size.width
            let h = size.height
            path.move(to: CGPoint(x: w * 0.5, y: h * 0.3))
            path.addCurve(
                to: CGPoint(x: w * 0.5, y: h),
                control1: CGPoint(x: 0, y: 0),
                control2: CGPoint(x: 0, y: h * 0.7)
            )
            path.move(to: CGPoint(x: w * 0.5, y: h * 0.3))
            path.addCurve(
                to: CGPoint(x: w * 0.5, y: h),
                control1: CGPoint(x: w, y: 0),
                control2: CGPoint(x: w, y: h * 0.7)
            )
            context.fill(path, with: .color(Color(hex: AppTheme.rose)))
        }
        .frame(width: 16, height: 14)
        .shadow(color: Color(hex: AppTheme.bark).opacity(0.08), radius: 1, y: 1)
    }
}

// MARK: - Paper Cutout Plant Views

struct PaperPlantView: View {
    let plant: GardenPlant
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Status label
            if plant.isDead {
                Text("withered")
                    .font(.system(size: 7, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color(hex: "#8B4513").opacity(0.8))
                    .cornerRadius(6).offset(y: -4)
            } else if plant.weatheringStage == .recovering {
                Text("recovering")
                    .font(.system(size: 7, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color(hex: AppTheme.honey).opacity(0.8))
                    .cornerRadius(6).offset(y: -4)
            } else if isSelected {
                Text("tap for details")
                    .font(.system(size: 7, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color(hex: AppTheme.charcoal).opacity(0.8))
                    .cornerRadius(6).offset(y: -4)
            }

            ZStack {
                PaperTypedPlantSprite(plantId: plant.shopPlantId, stage: plant.currentStage, scale: 1.0)

                // Weathering visual overlays for completed plants
                if plant.isComplete {
                    weatheringOverlay
                }
            }
            .shadow(color: isSelected ? Color(hex: AppTheme.honey).opacity(0.5) : Color(hex: AppTheme.bark).opacity(0.08), radius: isSelected ? 4 : 2, y: 2)
        }
    }

    @ViewBuilder
    private var weatheringOverlay: some View {
        switch plant.weatheringStage {
        case .healthy:
            EmptyView()

        case .recovering:
            // Slight yellow tint — healing
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(hex: "#F5D88E").opacity(0.2))
                .frame(width: 36, height: 42)
                .allowsHitTesting(false)

        case .slightlyWilted:
            // Subtle desaturation + slight droop
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(hex: "#8B7355").opacity(0.15))
                .frame(width: 36, height: 42)
                .allowsHitTesting(false)

        case .wilted:
            // Noticeable brown tint, drooping leaves effect
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: "#8B6914").opacity(0.25))
                    .frame(width: 36, height: 42)
                // Wilting droop indicator
                Ellipse()
                    .fill(Color(hex: "#A0522D").opacity(0.3))
                    .frame(width: 20, height: 6)
                    .offset(y: -8)
            }
            .allowsHitTesting(false)

        case .heavilyWilted:
            // Heavy brown overlay, visible damage
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: "#6B4226").opacity(0.35))
                    .frame(width: 36, height: 42)
                // Brown spots
                Circle()
                    .fill(Color(hex: "#5C3317").opacity(0.4))
                    .frame(width: 8, height: 8)
                    .offset(x: -6, y: -4)
                Circle()
                    .fill(Color(hex: "#5C3317").opacity(0.3))
                    .frame(width: 6, height: 6)
                    .offset(x: 5, y: 6)
            }
            .allowsHitTesting(false)

        case .dying:
            // Mostly brown/grey, clearly dying
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: "#4A3728").opacity(0.5))
                    .frame(width: 36, height: 42)
                // Multiple damage spots
                Circle()
                    .fill(Color(hex: "#3B2F2F").opacity(0.5))
                    .frame(width: 10, height: 10)
                    .offset(x: -4, y: -6)
                Circle()
                    .fill(Color(hex: "#3B2F2F").opacity(0.4))
                    .frame(width: 8, height: 8)
                    .offset(x: 6, y: 4)
                Circle()
                    .fill(Color(hex: "#3B2F2F").opacity(0.35))
                    .frame(width: 7, height: 7)
                    .offset(x: -2, y: 8)
            }
            .allowsHitTesting(false)

        case .dead:
            // Grey/dead overlay — plant is gone
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: "#2F2F2F").opacity(0.55))
                    .frame(width: 36, height: 42)
                // X mark
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.4))
            }
            .allowsHitTesting(false)
        }
    }
}

// MARK: - Paper Cutout Plant Sprites (per plant type)
/// Each plant is drawn as layered paper cutout shapes instead of pixel blocks.
struct PaperTypedPlantSprite: View {
    let plantId: String
    let stage: PlantStage
    var scale: CGFloat = 1.0

    var body: some View {
        ZStack {
            switch plantId {
            case "daisy":       paperDaisy
            case "tulip":       paperTulip
            case "sunflower":   paperSunflower
            case "bonsai":      paperBonsai
            case "cherry_blossom": paperCherryBlossom
            case "oak":         paperOak
            case "wisteria":    paperWisteria
            default:            paperDaisy
            }
        }
        .scaleEffect(scale)
    }

    // ───────── DAISY ─────────
    var paperDaisy: some View {
        ZStack {
            switch stage {
            case .seed:
                Ellipse().fill(Color(hex: AppTheme.bark)).frame(width: 12, height: 8).offset(y: 10)
            case .sprout:
                RoundedRectangle(cornerRadius: 2).fill(Color(hex: "#5DA05C")).frame(width: 3, height: 16).offset(y: 4)
                Ellipse().fill(Color(hex: "#7BC47B")).frame(width: 8, height: 5).offset(x: -4, y: 2)
            case .sapling:
                RoundedRectangle(cornerRadius: 2).fill(Color(hex: "#5DA05C")).frame(width: 3, height: 20).offset(y: 2)
                Ellipse().fill(Color(hex: "#7BC47B")).frame(width: 10, height: 5).offset(x: -5, y: -2).rotationEffect(.degrees(-15))
                Ellipse().fill(Color(hex: "#6BAF6A")).frame(width: 10, height: 5).offset(x: 5, y: 4).rotationEffect(.degrees(10))
                Circle().fill(Color(hex: AppTheme.honey).opacity(0.5)).frame(width: 8).offset(y: -10)
            default:
                // Full daisy
                RoundedRectangle(cornerRadius: 2).fill(Color(hex: "#5DA05C")).frame(width: 4, height: 26).offset(y: 4)
                Ellipse().fill(Color(hex: "#7BC47B")).frame(width: 12, height: 6).offset(x: -6, y: 4).rotationEffect(.degrees(-15))
                Ellipse().fill(Color(hex: "#6BAF6A")).frame(width: 12, height: 6).offset(x: 6, y: -2).rotationEffect(.degrees(10))
                ForEach(0..<5, id: \.self) { i in
                    Ellipse()
                        .fill(i % 2 == 0 ? Color(hex: "#FFFBE8") : Color(hex: "#FFF5D8"))
                        .frame(width: 10, height: 16)
                        .rotationEffect(.degrees(Double(i) * 72))
                        .offset(y: -14)
                }
                Circle().fill(Color(hex: "#F5D88E")).frame(width: 10).offset(y: -14)
                Circle().fill(Color(hex: "#E8C25E")).frame(width: 6).offset(y: -14)
            }
        }
        .frame(width: 36, height: 42)
    }

    // ───────── TULIP ─────────
    var paperTulip: some View {
        ZStack {
            switch stage {
            case .seed:
                Ellipse().fill(Color(hex: "#C4956A")).frame(width: 10, height: 8).offset(y: 10)
            case .sprout:
                RoundedRectangle(cornerRadius: 2).fill(Color(hex: "#5DA05C")).frame(width: 3, height: 16).offset(y: 4)
                Ellipse().fill(Color(hex: "#7BC47B")).frame(width: 8, height: 5).offset(x: -4, y: 4)
            case .sapling:
                RoundedRectangle(cornerRadius: 2).fill(Color(hex: "#5DA05C")).frame(width: 3, height: 22).offset(y: 2)
                Ellipse().fill(Color(hex: "#7BC47B")).frame(width: 10, height: 5).offset(x: -5, y: 2).rotationEffect(.degrees(-15))
                Ellipse().fill(Color(hex: "#FF8FA3").opacity(0.5)).frame(width: 8, height: 10).offset(y: -12)
            default:
                RoundedRectangle(cornerRadius: 2).fill(Color(hex: "#5DA05C")).frame(width: 4, height: 28).offset(y: 4)
                Ellipse().fill(Color(hex: "#7BC47B")).frame(width: 12, height: 6).offset(x: -6, y: 2).rotationEffect(.degrees(-15))
                // Tulip petals
                TulipPetalShape(isLeft: true).fill(Color(hex: "#FF8FA3")).frame(width: 12, height: 18).offset(x: -3, y: -14)
                TulipPetalShape(isLeft: false).fill(Color(hex: "#FF6B8A")).frame(width: 12, height: 18).offset(x: 3, y: -14)
                Ellipse().fill(Color(hex: "#FF5580").opacity(0.5)).frame(width: 6, height: 14).offset(y: -14)
            }
        }
        .frame(width: 36, height: 42)
    }

    // ───────── SUNFLOWER ─────────
    var paperSunflower: some View {
        ZStack {
            switch stage {
            case .seed:
                Ellipse().fill(Color(hex: "#333333")).frame(width: 8, height: 6).offset(y: 10)
                Ellipse().fill(Color(hex: AppTheme.bark)).frame(width: 14, height: 8).offset(y: 14)
            case .sprout:
                RoundedRectangle(cornerRadius: 2).fill(Color(hex: "#4A8C5E")).frame(width: 3, height: 18).offset(y: 4)
                Ellipse().fill(Color(hex: "#5DBB63")).frame(width: 8, height: 5).offset(x: -4, y: 4)
            case .sapling:
                RoundedRectangle(cornerRadius: 2).fill(Color(hex: "#4A8C5E")).frame(width: 3, height: 24).offset(y: 0)
                Ellipse().fill(Color(hex: "#3A8C5E")).frame(width: 12, height: 6).offset(x: -6, y: -2)
                Ellipse().fill(Color(hex: "#5DBB63")).frame(width: 12, height: 6).offset(x: 6, y: 4)
                Circle().fill(Color(hex: "#FFD93D").opacity(0.5)).frame(width: 10).offset(y: -14)
            default:
                RoundedRectangle(cornerRadius: 2).fill(Color(hex: "#4A8C5E")).frame(width: 5, height: 30).offset(y: 4)
                Ellipse().fill(Color(hex: "#3A8C5E")).frame(width: 14, height: 7).offset(x: -8, y: 0)
                Ellipse().fill(Color(hex: "#5DBB63")).frame(width: 14, height: 7).offset(x: 8, y: 4)
                // Big flower head
                ForEach(0..<8, id: \.self) { i in
                    Ellipse()
                        .fill(i % 2 == 0 ? Color(hex: "#FFD93D") : Color(hex: "#F5B800"))
                        .frame(width: 8, height: 14)
                        .rotationEffect(.degrees(Double(i) * 45))
                        .offset(y: -16)
                }
                Circle().fill(Color(hex: "#6B4226")).frame(width: 12).offset(y: -16)
            }
        }
        .frame(width: 40, height: 48)
    }

    // ───────── BONSAI ─────────
    var paperBonsai: some View {
        ZStack {
            switch stage {
            case .seed:
                RoundedRectangle(cornerRadius: 3).fill(Color(hex: "#A86040")).frame(width: 20, height: 4).offset(y: 10)
                RoundedRectangle(cornerRadius: 2).fill(Color(hex: "#C07850")).frame(width: 16, height: 10).offset(y: 16)
            case .sprout:
                RoundedRectangle(cornerRadius: 2).fill(Color(hex: "#8B6C42")).frame(width: 3, height: 10).offset(y: 2)
                Ellipse().fill(Color(hex: "#4A8C5E")).frame(width: 12, height: 8).offset(y: -6)
                RoundedRectangle(cornerRadius: 3).fill(Color(hex: "#A86040")).frame(width: 20, height: 4).offset(y: 10)
                RoundedRectangle(cornerRadius: 2).fill(Color(hex: "#C07850")).frame(width: 16, height: 10).offset(y: 16)
            default:
                // Full bonsai — shaped canopy + pot
                RoundedRectangle(cornerRadius: 2).fill(Color(hex: "#8B6C42")).frame(width: 4, height: 12).offset(y: 2)
                // Canopy layers
                Ellipse().fill(Color(hex: "#4A8C5E")).frame(width: 28, height: 14).offset(y: -8)
                Ellipse().fill(Color(hex: "#3A7A50")).frame(width: 20, height: 10).offset(y: -12)
                Ellipse().fill(Color(hex: "#4A8C5E")).frame(width: 14, height: 8).offset(x: 8, y: -6)
                // Pot
                RoundedRectangle(cornerRadius: 3).fill(Color(hex: "#A86040")).frame(width: 22, height: 4).offset(y: 10)
                RoundedRectangle(cornerRadius: 2).fill(Color(hex: "#C07850")).frame(width: 16, height: 10).offset(y: 16)
            }
        }
        .frame(width: 36, height: 42)
    }

    // ───────── CHERRY BLOSSOM ─────────
    var paperCherryBlossom: some View {
        ZStack {
            switch stage {
            case .seed:
                Ellipse().fill(Color(hex: "#7A5C3E")).frame(width: 8, height: 6).offset(y: 10)
                Ellipse().fill(Color(hex: AppTheme.bark)).frame(width: 14, height: 8).offset(y: 14)
            case .sprout:
                RoundedRectangle(cornerRadius: 2).fill(Color(hex: "#7A5C3E")).frame(width: 3, height: 16).offset(y: 4)
                Ellipse().fill(Color(hex: "#6B9E6F")).frame(width: 10, height: 6).offset(y: -4)
            case .sapling:
                RoundedRectangle(cornerRadius: 2).fill(Color(hex: "#7A5C3E")).frame(width: 4, height: 22).offset(y: 2)
                Ellipse().fill(Color(hex: "#6B9E6F")).frame(width: 16, height: 10).offset(y: -8)
                Circle().fill(Color(hex: "#FFB7C5")).frame(width: 6).offset(x: -4, y: -10)
            default:
                // Full cherry blossom tree
                RoundedRectangle(cornerRadius: 2).fill(Color(hex: "#8B6040")).frame(width: 5, height: 20).offset(y: 8)
                // Branches
                RoundedRectangle(cornerRadius: 1).fill(Color(hex: "#7A5030")).frame(width: 16, height: 3).offset(x: -8, y: -2).rotationEffect(.degrees(-15))
                RoundedRectangle(cornerRadius: 1).fill(Color(hex: "#7A5030")).frame(width: 16, height: 3).offset(x: 8, y: -6).rotationEffect(.degrees(10))
                // Blossom clusters
                Circle().fill(Color(hex: "#FFD0DE")).frame(width: 14).offset(x: -12, y: -4)
                Circle().fill(Color(hex: "#FFC0D0")).frame(width: 11).offset(x: -6, y: -12)
                Circle().fill(Color(hex: "#FFD0DE")).frame(width: 12).offset(x: 0, y: -16)
                Circle().fill(Color(hex: "#FFC0D0")).frame(width: 10).offset(x: 8, y: -14)
                Circle().fill(Color(hex: "#FFD0DE")).frame(width: 13).offset(x: 14, y: -6)
                Circle().fill(Color(hex: "#FFCCD8")).frame(width: 9).offset(x: 6, y: -8)
                // Detail dots
                Circle().fill(Color(hex: "#FFB0C0").opacity(0.5)).frame(width: 4).offset(x: -10, y: -4)
                Circle().fill(Color(hex: "#FFB0C0").opacity(0.5)).frame(width: 5).offset(x: 2, y: -14)
            }
        }
        .frame(width: 44, height: 48)
    }

    // ───────── OAK ─────────
    var paperOak: some View {
        ZStack {
            switch stage {
            case .seed:
                Circle().fill(Color(hex: "#B8860B")).frame(width: 8).offset(y: 8)
                Ellipse().fill(Color(hex: "#6B4226")).frame(width: 8, height: 6).offset(y: 12)
            case .sprout:
                RoundedRectangle(cornerRadius: 2).fill(Color(hex: "#6B4226")).frame(width: 3, height: 16).offset(y: 4)
                Ellipse().fill(Color(hex: "#4A8C5E")).frame(width: 12, height: 8).offset(y: -4)
            case .sapling:
                RoundedRectangle(cornerRadius: 2).fill(Color(hex: "#6B4226")).frame(width: 4, height: 22).offset(y: 2)
                Ellipse().fill(Color(hex: "#4A8C5E")).frame(width: 18, height: 14).offset(y: -8)
                Ellipse().fill(Color(hex: "#2E6B3E")).frame(width: 10, height: 8).offset(x: -2, y: -10)
            default:
                // Full oak
                RoundedRectangle(cornerRadius: 2).fill(Color(hex: "#6B4226")).frame(width: 6, height: 18).offset(y: 8)
                // Roots
                RoundedRectangle(cornerRadius: 1).fill(Color(hex: "#6B4226")).frame(width: 4, height: 6).offset(x: -6, y: 14).rotationEffect(.degrees(-20))
                RoundedRectangle(cornerRadius: 1).fill(Color(hex: "#6B4226")).frame(width: 4, height: 6).offset(x: 6, y: 14).rotationEffect(.degrees(20))
                // Massive canopy
                Ellipse().fill(Color(hex: "#4A8C5E")).frame(width: 36, height: 24).offset(y: -6)
                Ellipse().fill(Color(hex: "#2E6B3E")).frame(width: 24, height: 16).offset(y: -10)
                Ellipse().fill(Color(hex: "#6BB878")).frame(width: 14, height: 10).offset(x: 8, y: -4)
                Ellipse().fill(Color(hex: "#2E6B3E")).frame(width: 10, height: 8).offset(x: -8, y: -6)
            }
        }
        .frame(width: 44, height: 48)
    }

    // ───────── WISTERIA ─────────
    var paperWisteria: some View {
        ZStack {
            switch stage {
            case .seed:
                Ellipse().fill(Color(hex: "#7A5C3E")).frame(width: 8, height: 6).offset(y: 10)
                Ellipse().fill(Color(hex: AppTheme.bark)).frame(width: 14, height: 8).offset(y: 14)
            case .sprout:
                RoundedRectangle(cornerRadius: 2).fill(Color(hex: "#7A5C3E")).frame(width: 3, height: 16).offset(y: 4)
                Ellipse().fill(Color(hex: "#6B9E6F")).frame(width: 10, height: 6).offset(y: -4)
            case .sapling:
                RoundedRectangle(cornerRadius: 2).fill(Color(hex: "#7A5C3E")).frame(width: 3, height: 22).offset(y: 2)
                Ellipse().fill(Color(hex: "#6B9E6F")).frame(width: 18, height: 10).offset(y: -8)
                RoundedRectangle(cornerRadius: 2).fill(Color(hex: "#B39DDB").opacity(0.5)).frame(width: 3, height: 8).offset(x: -6, y: -2)
            default:
                // Full wisteria
                RoundedRectangle(cornerRadius: 2).fill(Color(hex: "#7A5C3E")).frame(width: 4, height: 24).offset(y: 4)
                // Branches
                RoundedRectangle(cornerRadius: 1).fill(Color(hex: "#7A5C3E")).frame(width: 20, height: 3).offset(x: -8, y: -4)
                RoundedRectangle(cornerRadius: 1).fill(Color(hex: "#7A5C3E")).frame(width: 20, height: 3).offset(x: 8, y: -6)
                // Leaf canopy
                Ellipse().fill(Color(hex: "#6B9E6F")).frame(width: 36, height: 12).offset(y: -10)
                // Hanging flower cascades
                RoundedRectangle(cornerRadius: 2).fill(Color(hex: "#B39DDB")).frame(width: 4, height: 16).offset(x: -12, y: 2)
                RoundedRectangle(cornerRadius: 2).fill(Color(hex: "#8E6DB8")).frame(width: 4, height: 12).offset(x: -6, y: 0)
                RoundedRectangle(cornerRadius: 2).fill(Color(hex: "#B39DDB")).frame(width: 4, height: 14).offset(x: 0, y: 1)
                RoundedRectangle(cornerRadius: 2).fill(Color(hex: "#6A4C93")).frame(width: 4, height: 18).offset(x: 6, y: 4)
                RoundedRectangle(cornerRadius: 2).fill(Color(hex: "#B39DDB")).frame(width: 4, height: 10).offset(x: 12, y: -2)
                // Flower tips (darker at bottom)
                Circle().fill(Color(hex: "#8E6DB8")).frame(width: 5).offset(x: -12, y: 11)
                Circle().fill(Color(hex: "#6A4C93")).frame(width: 5).offset(x: 6, y: 14)
            }
        }
        .frame(width: 44, height: 48)
    }
}

// Tulip petal helper shape
struct TulipPetalShape: Shape {
    let isLeft: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        if isLeft {
            path.move(to: CGPoint(x: w * 0.5, y: h))
            path.addQuadCurve(to: CGPoint(x: w * 0.3, y: 0), control: CGPoint(x: 0, y: h * 0.5))
            path.addQuadCurve(to: CGPoint(x: w * 0.5, y: h * 0.15), control: CGPoint(x: w * 0.35, y: 0))
        } else {
            path.move(to: CGPoint(x: w * 0.5, y: h))
            path.addQuadCurve(to: CGPoint(x: w * 0.7, y: 0), control: CGPoint(x: w, y: h * 0.5))
            path.addQuadCurve(to: CGPoint(x: w * 0.5, y: h * 0.15), control: CGPoint(x: w * 0.65, y: 0))
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - Plant Shop Sheet
struct PlantShopSheet: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    Text("choose a plant to grow")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(Color(hex: AppTheme.bark).opacity(0.5))
                        .padding(.top, 4)

                    ForEach(plantShop) { shopPlant in
                        let isUnlocked = vm.unlockedPlantTypes.contains(shopPlant.id)
                        let streakNeeded = PlantType(rawValue: shopPlant.id)?.unlockStreakDays ?? 0
                        ShopPlantCard(
                            shopPlant: shopPlant,
                            isDisabled: !vm.canSelectPlant || !isUnlocked,
                            isLocked: !isUnlocked,
                            streakToUnlock: streakNeeded,
                            onSelect: {
                                vm.selectPlantFromShop(shopPlantId: shopPlant.id)
                                dismiss()
                            }
                        )
                    }

                    if !vm.canSelectPlant {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: AppTheme.honey))
                            Text("finish growing your current plant first!")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(Color(hex: AppTheme.bark).opacity(0.5))
                        }
                        .padding(16)
                        .background(Color(hex: AppTheme.honey).opacity(0.1))
                        .cornerRadius(14)
                    }
                }
                .padding(20)
            }
            .background(Color(hex: AppTheme.cream))
            .navigationTitle("plant shop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("done") { dismiss() }
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: AppTheme.mintDark))
                }
            }
        }
    }
}

struct ShopPlantCard: View {
    let shopPlant: ShopPlant
    let isDisabled: Bool
    var isLocked: Bool = false
    var streakToUnlock: Int = 0
    let onSelect: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            // Plant preview
            ZStack {
                PaperTypedPlantSprite(plantId: shopPlant.id, stage: .flowerTree, scale: 1.2)
                    .frame(width: 56, height: 56)
                    .background(
                        Circle()
                            .fill(Color(hex: shopPlant.colorHex).opacity(0.15))
                            .frame(width: 56, height: 56)
                    )

                if isLocked {
                    Circle()
                        .fill(Color.black.opacity(0.4))
                        .frame(width: 56, height: 56)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(shopPlant.name)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: AppTheme.charcoal))

                if isLocked {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text("unlocks at \(streakToUnlock)-day streak")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(Color(hex: AppTheme.honey))
                } else {
                    Text(shopPlant.description)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(Color(hex: AppTheme.bark).opacity(0.5))
                        .lineLimit(2)
                }

                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 10, weight: .bold))
                    Text("\(shopPlant.daysToGrow) days")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                }
                .foregroundColor(Color(hex: shopPlant.colorHex))
            }

            Spacer()

            if isLocked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: AppTheme.bark).opacity(0.2))
                    .padding(.horizontal, 14)
            } else {
                Button {
                    onSelect()
                } label: {
                    Text("grow")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(
                            isDisabled
                                ? AnyShapeStyle(Color(hex: AppTheme.bark).opacity(0.2))
                                : AnyShapeStyle(LinearGradient(
                                    colors: [Color(hex: AppTheme.mint), Color(hex: AppTheme.mintDark)],
                                    startPoint: .leading, endPoint: .trailing
                                ))
                        )
                        .cornerRadius(14)
                }
                .disabled(isDisabled)
            }
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color(hex: AppTheme.bark).opacity(0.06), radius: 8, y: 3)
        .opacity(isLocked ? 0.5 : (isDisabled ? 0.6 : 1.0))
    }
}

// MARK: - Plant Detail Sheet
struct PlantDetailSheet: View {
    let plant: GardenPlant
    let myName: String
    let partnerName: String

    var body: some View {
        VStack(spacing: 20) {
            PaperTypedPlantSprite(plantId: plant.shopPlantId, stage: plant.currentStage, scale: 2.0)
                .frame(width: 80, height: 80)
                .padding(.top, 20)

            VStack(spacing: 6) {
                Text(plant.shopPlant?.name ?? plant.currentStage.displayName)
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundColor(Color(hex: AppTheme.mintDark))

                if plant.isDead {
                    Text("withered away")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "#8B4513"))
                        .padding(.horizontal, 12).padding(.vertical, 4)
                        .background(Color(hex: "#8B4513").opacity(0.15))
                        .cornerRadius(8)
                } else if plant.isComplete {
                    VStack(spacing: 4) {
                        Text("fully grown!")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: AppTheme.honey))
                            .padding(.horizontal, 12).padding(.vertical, 4)
                            .background(Color(hex: AppTheme.honey).opacity(0.15))
                            .cornerRadius(8)

                        if plant.weatheringDays > 0 {
                            Text(weatheringStatusText)
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundColor(weatheringStatusColor)
                        }

                        if plant.weatheringRecoveryDays > 0 {
                            Text("recovering (\(plant.weatheringRecoveryDays) day\(plant.weatheringRecoveryDays == 1 ? "" : "s") left)")
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundColor(Color(hex: AppTheme.bark).opacity(0.4))
                        }
                    }
                } else {
                    Text("\(plant.daysProgress) of \(plant.daysRequired) days")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(Color(hex: AppTheme.bark).opacity(0.5))
                }

                Text("planted on \(plant.plantedDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(Color(hex: AppTheme.bark).opacity(0.4))

                if let completed = plant.completedDate {
                    Text("completed \(completed.formatted(date: .abbreviated, time: .omitted))")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: AppTheme.mintDark))
                }
            }

            if !plant.isComplete {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(hex: AppTheme.cloud)).frame(height: 8)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(LinearGradient(
                                colors: [Color(hex: AppTheme.mint), Color(hex: AppTheme.mintDark)],
                                startPoint: .leading, endPoint: .trailing
                            ))
                            .frame(width: geo.size.width * plant.progress, height: 8)
                    }
                }
                .frame(height: 8)
                .padding(.horizontal, 20)
            }

            if !plant.appContributions.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("apps that grew this plant")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: AppTheme.charcoal))

                    let grouped = Dictionary(grouping: plant.appContributions, by: \.appName)
                    ForEach(Array(grouped.keys.sorted()), id: \.self) { appName in
                        if let contributions = grouped[appName], let first = contributions.first {
                            let totalSaved = contributions.reduce(0) { $0 + $1.minutesSaved }
                            let totalUsed = contributions.reduce(0) { $0 + $1.usedMinutes }
                            let totalLimit = contributions.reduce(0) { $0 + $1.limitMinutes }

                            HStack(spacing: 10) {
                                Circle()
                                    .fill(Color(hex: first.appColorHex).opacity(0.15))
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Image(systemName: first.appIconName)
                                            .foregroundColor(Color(hex: first.appColorHex))
                                            .font(.system(size: 14, weight: .bold))
                                    )

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(appName)
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                        .foregroundColor(Color(hex: AppTheme.charcoal))
                                    Text("used \(totalUsed)m of \(totalLimit)m total")
                                        .font(.system(size: 10, weight: .medium, design: .rounded))
                                        .foregroundColor(Color(hex: AppTheme.bark).opacity(0.5))
                                }

                                Spacer()

                                VStack(spacing: 2) {
                                    Text("\(totalSaved)m")
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundColor(Color(hex: AppTheme.mintDark))
                                    Text("saved")
                                        .font(.system(size: 9, weight: .medium, design: .rounded))
                                        .foregroundColor(Color(hex: AppTheme.bark).opacity(0.4))
                                }
                            }
                            .padding(12)
                            .background(Color(hex: AppTheme.cloud))
                            .cornerRadius(14)
                        }
                    }

                    let totalSaved = plant.appContributions.reduce(0) { $0 + $1.minutesSaved }
                    HStack {
                        Spacer()
                        Text("total time saved: \(totalSaved) minutes")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: AppTheme.mintDark))
                        Spacer()
                    }
                    .padding(.top, 4)
                }
                .padding(16)
            } else {
                Text("this plant is still growing — keep it up!")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(Color(hex: AppTheme.bark).opacity(0.4))
                    .padding()
            }

            Spacer()
        }
        .padding(.horizontal, 20)
    }

    private var weatheringStatusText: String {
        let pct = Int(plant.weatheringFraction * 100)
        switch plant.weatheringStage {
        case .slightlyWilted: return "slightly weathered (\(pct)%)"
        case .wilted: return "weathered (\(pct)%)"
        case .heavilyWilted: return "heavily weathered (\(pct)%)"
        case .dying: return "critical condition (\(pct)%)"
        case .dead: return "withered away"
        default: return "healthy"
        }
    }

    private var weatheringStatusColor: Color {
        switch plant.weatheringStage {
        case .slightlyWilted: return Color(hex: "#C4956A")
        case .wilted: return Color(hex: "#A0522D")
        case .heavilyWilted: return Color(hex: "#8B4513")
        case .dying: return Color(hex: "#800000")
        case .dead: return Color(hex: "#4A3728")
        default: return Color(hex: AppTheme.mintDark)
        }
    }
}

// MARK: - PixelHeartView (kept for SetupNameView usage)
struct PixelHeartView: View {
    var body: some View {
        Canvas { context, size in
            let s: CGFloat = 4
            let c = Color(hex: AppTheme.rose)
            drawBlock(context: context, x: 1, y: 0, w: 2, h: 1, color: c, scale: s)
            drawBlock(context: context, x: 5, y: 0, w: 2, h: 1, color: c, scale: s)
            drawBlock(context: context, x: 0, y: 1, w: 8, h: 1, color: c, scale: s)
            drawBlock(context: context, x: 0, y: 2, w: 8, h: 1, color: c, scale: s)
            drawBlock(context: context, x: 1, y: 3, w: 6, h: 1, color: c, scale: s)
            drawBlock(context: context, x: 2, y: 4, w: 4, h: 1, color: c, scale: s)
            drawBlock(context: context, x: 3, y: 5, w: 2, h: 1, color: c, scale: s)
        }
        .frame(width: 32, height: 24)
    }

    private func drawBlock(context: GraphicsContext, x: Int, y: Int, w: Int, h: Int, color: Color, scale: CGFloat) {
        let rect = CGRect(
            x: CGFloat(x) * scale,
            y: CGFloat(y) * scale,
            width: CGFloat(w) * scale,
            height: CGFloat(h) * scale
        )
        context.fill(Path(rect), with: .color(color))
    }
}

// MARK: - Legacy Pixel Drawing Helper (kept for backward compat)
func drawPixelBlock(context: GraphicsContext, x: Int, y: Int, w: Int, h: Int, color: Color, scale: CGFloat) {
    let rect = CGRect(
        x: CGFloat(x) * scale,
        y: CGFloat(y) * scale,
        width: CGFloat(w) * scale,
        height: CGFloat(h) * scale
    )
    context.fill(Path(rect), with: .color(color))
}
