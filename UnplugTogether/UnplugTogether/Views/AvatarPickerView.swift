import SwiftUI

// MARK: - Avatar Picker (Setup Step 2)
struct AvatarPickerView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var selectedId: String = "avatar_01"
    @State private var animateIn = false

    let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 8)

            // Title
            VStack(spacing: 6) {
                Text("choose your avatar")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundColor(Color(hex: AppTheme.charcoal))
                Text("pick a character for your garden")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(Color(hex: AppTheme.bark).opacity(0.5))
            }

            // Selected avatar preview
            if let avatar = avatarCatalog.first(where: { $0.id == selectedId }) {
                VStack(spacing: 8) {
                    PaperCutoutCharacter(avatar: avatar, size: 100)
                        .shadow(color: Color(hex: avatar.outfitColorHex).opacity(0.3), radius: 12, y: 6)
                        .scaleEffect(animateIn ? 1.0 : 0.8)
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: selectedId)

                    Text(avatar.name)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: AppTheme.charcoal))
                }
                .padding(.vertical, 8)
            }

            // Avatar grid
            ScrollView {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(avatarCatalog) { avatar in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                selectedId = avatar.id
                            }
                        } label: {
                            VStack(spacing: 6) {
                                PaperCutoutCharacter(avatar: avatar, size: 56)
                                    .frame(width: 60, height: 60)

                                Text(avatar.name)
                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                                    .foregroundColor(Color(hex: AppTheme.bark).opacity(0.6))
                            }
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(selectedId == avatar.id
                                          ? Color(hex: avatar.outfitColorHex).opacity(0.15)
                                          : Color(hex: AppTheme.cloud))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(selectedId == avatar.id
                                            ? Color(hex: avatar.outfitColorHex).opacity(0.6)
                                            : Color.clear,
                                            lineWidth: 2.5)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 4)
            }

            // Continue button
            Button {
                vm.completeAvatarSetup(avatarId: selectedId)
            } label: {
                Text("next")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: AppTheme.mint), Color(hex: AppTheme.mintDark)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(24)
                    .shadow(color: Color(hex: AppTheme.mint).opacity(0.3), radius: 12, y: 6)
            }
        }
        .padding(24)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                animateIn = true
            }
        }
    }
}

// MARK: - Paper Cutout Character Drawing

/// Draws a flat illustration character in the paper cutout style.
/// Matches the approved Option F v2 design: round head, simple hair, dot eyes,
/// rosy cheeks, A-line dress or shirt+pants, round hands, small shoes.
struct PaperCutoutCharacter: View {
    let avatar: AvatarConfig
    var size: CGFloat = 48
    var stepFrame: Bool = false  // For walking animation

    // Derived scale from size
    private var s: CGFloat { size / 48 }

    var body: some View {
        Canvas { context, canvasSize in
            let s = self.s
            let hairColor = Color(hex: avatar.hairColorHex)
            let skinColor = Color(hex: avatar.skinColorHex)
            let outfitColor = Color(hex: avatar.outfitColorHex)
            let shoeColor = Color(hex: "#6B5A4A")
            let cheekColor = Color(hex: "#F2A0A0").opacity(0.5)

            // === HEAD ===
            let headCenter = CGPoint(x: 24 * s, y: 14 * s)
            let headRadius = 10 * s

            // Hair (drawn first, behind head)
            drawHair(context: context, avatar: avatar, center: headCenter, radius: headRadius, s: s, hairColor: hairColor)

            // Face circle
            context.fill(
                Path(ellipseIn: CGRect(
                    x: headCenter.x - headRadius,
                    y: headCenter.y - headRadius,
                    width: headRadius * 2,
                    height: headRadius * 2
                )),
                with: .color(skinColor)
            )

            // Eyes — simple dots
            let eyeY = headCenter.y + 1 * s
            let eyeSize = 2 * s
            context.fill(
                Path(ellipseIn: CGRect(x: headCenter.x - 4 * s - eyeSize/2, y: eyeY - eyeSize/2, width: eyeSize, height: eyeSize)),
                with: .color(Color(hex: "#4A4A4A"))
            )
            context.fill(
                Path(ellipseIn: CGRect(x: headCenter.x + 4 * s - eyeSize/2, y: eyeY - eyeSize/2, width: eyeSize, height: eyeSize)),
                with: .color(Color(hex: "#4A4A4A"))
            )

            // Eye highlights
            let highlightSize = 0.8 * s
            context.fill(
                Path(ellipseIn: CGRect(x: headCenter.x - 4 * s - highlightSize/2 + 0.5*s, y: eyeY - highlightSize/2 - 0.5*s, width: highlightSize, height: highlightSize)),
                with: .color(.white)
            )
            context.fill(
                Path(ellipseIn: CGRect(x: headCenter.x + 4 * s - highlightSize/2 + 0.5*s, y: eyeY - highlightSize/2 - 0.5*s, width: highlightSize, height: highlightSize)),
                with: .color(.white)
            )

            // Smile
            var smilePath = Path()
            smilePath.move(to: CGPoint(x: headCenter.x - 3 * s, y: headCenter.y + 4 * s))
            smilePath.addQuadCurve(
                to: CGPoint(x: headCenter.x + 3 * s, y: headCenter.y + 4 * s),
                control: CGPoint(x: headCenter.x, y: headCenter.y + 6.5 * s)
            )
            context.stroke(smilePath, with: .color(Color(hex: "#C0A090")), lineWidth: 1.2 * s)

            // Rosy cheeks
            let cheekSize = 3 * s
            context.fill(
                Path(ellipseIn: CGRect(x: headCenter.x - 8 * s, y: headCenter.y + 2 * s, width: cheekSize, height: cheekSize * 0.6)),
                with: .color(cheekColor)
            )
            context.fill(
                Path(ellipseIn: CGRect(x: headCenter.x + 5 * s, y: headCenter.y + 2 * s, width: cheekSize, height: cheekSize * 0.6)),
                with: .color(cheekColor)
            )

            // Hair foreground (bangs, etc)
            drawHairForeground(context: context, avatar: avatar, center: headCenter, radius: headRadius, s: s, hairColor: hairColor)

            // Accessory
            drawAccessory(context: context, avatar: avatar, center: headCenter, radius: headRadius, s: s)

            // === BODY / OUTFIT ===
            let bodyTop = headCenter.y + headRadius - 1 * s
            drawOutfit(context: context, avatar: avatar, bodyTop: bodyTop, centerX: headCenter.x, s: s, outfitColor: outfitColor, skinColor: skinColor, shoeColor: shoeColor, stepFrame: stepFrame)
        }
        .frame(width: 48 * s, height: 48 * s)
    }

    // MARK: - Hair Styles

    private func drawHair(context: GraphicsContext, avatar: AvatarConfig, center: CGPoint, radius: CGFloat, s: CGFloat, hairColor: Color) {
        switch avatar.hairStyle {
        case .bob:
            // Short bob — rounded rectangle behind head
            let hairRect = CGRect(x: center.x - radius - 1*s, y: center.y - radius - 2*s, width: radius * 2 + 2*s, height: radius * 2 + 2*s)
            context.fill(Path(roundedRect: hairRect, cornerRadius: radius), with: .color(hairColor))

        case .long:
            // Long flowing hair behind head + shoulders
            var path = Path()
            path.addEllipse(in: CGRect(x: center.x - radius - 2*s, y: center.y - radius - 2*s, width: radius * 2 + 4*s, height: radius * 2 + 3*s))
            context.fill(path, with: .color(hairColor))
            // Long strands
            context.fill(
                Path(roundedRect: CGRect(x: center.x - radius - 2*s, y: center.y, width: 4*s, height: 14*s), cornerRadius: 2*s),
                with: .color(hairColor)
            )
            context.fill(
                Path(roundedRect: CGRect(x: center.x + radius - 2*s, y: center.y, width: 4*s, height: 14*s), cornerRadius: 2*s),
                with: .color(hairColor)
            )

        case .fluffy:
            // Big fluffy/curly hair
            let expandedRadius = radius + 3 * s
            context.fill(
                Path(ellipseIn: CGRect(x: center.x - expandedRadius, y: center.y - expandedRadius - 1*s, width: expandedRadius * 2, height: expandedRadius * 2)),
                with: .color(hairColor)
            )
            // Extra puff on top
            context.fill(
                Path(ellipseIn: CGRect(x: center.x - 5*s, y: center.y - radius - 5*s, width: 10*s, height: 6*s)),
                with: .color(hairColor)
            )

        case .spiky:
            // Short spiky hair on top
            let baseRect = CGRect(x: center.x - radius, y: center.y - radius - 3*s, width: radius * 2, height: radius + 3*s)
            context.fill(Path(roundedRect: baseRect, cornerRadius: 4*s), with: .color(hairColor))
            // Spiky tips
            for i in stride(from: -2, through: 2, by: 1) {
                let spikeX = center.x + CGFloat(i) * 3 * s
                var spike = Path()
                spike.move(to: CGPoint(x: spikeX - 2*s, y: center.y - radius - 1*s))
                spike.addLine(to: CGPoint(x: spikeX, y: center.y - radius - 5*s))
                spike.addLine(to: CGPoint(x: spikeX + 2*s, y: center.y - radius - 1*s))
                spike.closeSubpath()
                context.fill(spike, with: .color(hairColor))
            }

        case .ponytail:
            // Hair bun on top
            let baseRect = CGRect(x: center.x - radius, y: center.y - radius - 2*s, width: radius * 2, height: radius + 2*s)
            context.fill(Path(roundedRect: baseRect, cornerRadius: radius * 0.8), with: .color(hairColor))
            // Ponytail circle
            context.fill(
                Path(ellipseIn: CGRect(x: center.x + 4*s, y: center.y - radius - 6*s, width: 8*s, height: 8*s)),
                with: .color(hairColor)
            )

        case .buzzcut:
            // Very short hair — thin cap
            let capRect = CGRect(x: center.x - radius, y: center.y - radius - 1*s, width: radius * 2, height: radius * 0.7)
            context.fill(Path(roundedRect: capRect, cornerRadius: radius), with: .color(hairColor))
        }
    }

    private func drawHairForeground(context: GraphicsContext, avatar: AvatarConfig, center: CGPoint, radius: CGFloat, s: CGFloat, hairColor: Color) {
        switch avatar.hairStyle {
        case .bob:
            // Bangs
            var bangsPath = Path()
            bangsPath.addRoundedRect(in: CGRect(x: center.x - radius + 1*s, y: center.y - radius - 1*s, width: radius * 2 - 2*s, height: 5*s), cornerSize: CGSize(width: 3*s, height: 3*s))
            context.fill(bangsPath, with: .color(hairColor))

        case .long:
            // Side-swept bangs
            context.fill(
                Path(roundedRect: CGRect(x: center.x - radius, y: center.y - radius - 1*s, width: radius * 1.2, height: 5*s), cornerRadius: 2*s),
                with: .color(hairColor)
            )

        case .fluffy:
            // Fluffy bangs all across
            context.fill(
                Path(roundedRect: CGRect(x: center.x - radius - 1*s, y: center.y - radius - 1*s, width: radius * 2 + 2*s, height: 4*s), cornerRadius: 2*s),
                with: .color(hairColor)
            )

        case .spiky, .buzzcut:
            break  // No foreground bangs needed

        case .ponytail:
            // Small bangs
            context.fill(
                Path(roundedRect: CGRect(x: center.x - radius + 2*s, y: center.y - radius - 0.5*s, width: radius, height: 3.5*s), cornerRadius: 2*s),
                with: .color(hairColor)
            )
        }
    }

    // MARK: - Accessories

    private func drawAccessory(context: GraphicsContext, avatar: AvatarConfig, center: CGPoint, radius: CGFloat, s: CGFloat) {
        switch avatar.accessory {
        case .none:
            break

        case .glasses:
            // Round glasses
            let glassY = center.y + 0.5 * s
            let glassR = 3 * s
            context.stroke(
                Path(ellipseIn: CGRect(x: center.x - 7*s, y: glassY - glassR, width: glassR * 2, height: glassR * 2)),
                with: .color(Color(hex: "#4A4A4A")), lineWidth: 0.8 * s
            )
            context.stroke(
                Path(ellipseIn: CGRect(x: center.x + 1*s, y: glassY - glassR, width: glassR * 2, height: glassR * 2)),
                with: .color(Color(hex: "#4A4A4A")), lineWidth: 0.8 * s
            )
            // Bridge
            var bridge = Path()
            bridge.move(to: CGPoint(x: center.x - 1*s, y: glassY))
            bridge.addLine(to: CGPoint(x: center.x + 1*s, y: glassY))
            context.stroke(bridge, with: .color(Color(hex: "#4A4A4A")), lineWidth: 0.8 * s)

        case .hat:
            // Small round hat on top
            context.fill(
                Path(ellipseIn: CGRect(x: center.x - 8*s, y: center.y - radius - 4*s, width: 16*s, height: 4*s)),
                with: .color(Color(hex: "#E8C25E"))
            )
            context.fill(
                Path(roundedRect: CGRect(x: center.x - 5*s, y: center.y - radius - 7*s, width: 10*s, height: 5*s), cornerRadius: 3*s),
                with: .color(Color(hex: "#E8C25E"))
            )

        case .bow:
            // Cute bow on top-right
            let bowX = center.x + 6 * s
            let bowY = center.y - radius - 1 * s
            // Left wing
            context.fill(
                Path(ellipseIn: CGRect(x: bowX - 5*s, y: bowY - 2*s, width: 5*s, height: 4*s)),
                with: .color(Color(hex: AppTheme.rose))
            )
            // Right wing
            context.fill(
                Path(ellipseIn: CGRect(x: bowX, y: bowY - 2*s, width: 5*s, height: 4*s)),
                with: .color(Color(hex: AppTheme.rose))
            )
            // Center knot
            context.fill(
                Path(ellipseIn: CGRect(x: bowX - 1.5*s, y: bowY - 1*s, width: 3*s, height: 2*s)),
                with: .color(Color(hex: AppTheme.roseDark))
            )

        case .headband:
            // Thin headband across top of head
            var bandPath = Path()
            bandPath.move(to: CGPoint(x: center.x - radius, y: center.y - radius + 3*s))
            bandPath.addQuadCurve(
                to: CGPoint(x: center.x + radius, y: center.y - radius + 3*s),
                control: CGPoint(x: center.x, y: center.y - radius - 1*s)
            )
            context.stroke(bandPath, with: .color(Color(hex: AppTheme.honey)), lineWidth: 2 * s)

        case .flower:
            // Small flower on the side of head
            let fx = center.x + 8 * s
            let fy = center.y - 6 * s
            let petalR = 2 * s
            for angle in stride(from: 0.0, to: 360.0, by: 72.0) {
                let rad = angle * .pi / 180
                let px = fx + cos(rad) * 2.5 * s
                let py = fy + sin(rad) * 2.5 * s
                context.fill(
                    Path(ellipseIn: CGRect(x: px - petalR, y: py - petalR, width: petalR * 2, height: petalR * 2)),
                    with: .color(Color(hex: AppTheme.rose))
                )
            }
            context.fill(
                Path(ellipseIn: CGRect(x: fx - 1.5*s, y: fy - 1.5*s, width: 3*s, height: 3*s)),
                with: .color(Color(hex: AppTheme.honey))
            )
        }
    }

    // MARK: - Outfit Styles

    private func drawOutfit(context: GraphicsContext, avatar: AvatarConfig, bodyTop: CGFloat, centerX: CGFloat, s: CGFloat, outfitColor: Color, skinColor: Color, shoeColor: Color, stepFrame: Bool) {

        switch avatar.outfitStyle {
        case .dress:
            // A-line dress — trapezoid shape
            var dressPath = Path()
            dressPath.move(to: CGPoint(x: centerX - 6*s, y: bodyTop))
            dressPath.addLine(to: CGPoint(x: centerX + 6*s, y: bodyTop))
            dressPath.addLine(to: CGPoint(x: centerX + 10*s, y: bodyTop + 14*s))
            dressPath.addLine(to: CGPoint(x: centerX - 10*s, y: bodyTop + 14*s))
            dressPath.closeSubpath()
            context.fill(dressPath, with: .color(outfitColor))

            // Arms (round hands)
            let armY = bodyTop + 4 * s
            context.fill(
                Path(roundedRect: CGRect(x: centerX - 12*s, y: armY, width: 6*s, height: 3*s), cornerRadius: 1.5*s),
                with: .color(outfitColor)
            )
            context.fill(
                Path(roundedRect: CGRect(x: centerX + 6*s, y: armY, width: 6*s, height: 3*s), cornerRadius: 1.5*s),
                with: .color(outfitColor)
            )
            // Hands
            context.fill(
                Path(ellipseIn: CGRect(x: centerX - 14*s, y: armY - 0.5*s, width: 4*s, height: 4*s)),
                with: .color(skinColor)
            )
            context.fill(
                Path(ellipseIn: CGRect(x: centerX + 10*s, y: armY - 0.5*s, width: 4*s, height: 4*s)),
                with: .color(skinColor)
            )

        case .shirtPants:
            // Shirt (rectangle)
            context.fill(
                Path(roundedRect: CGRect(x: centerX - 7*s, y: bodyTop, width: 14*s, height: 8*s), cornerRadius: 2*s),
                with: .color(outfitColor)
            )
            // Pants (slightly darker)
            let pantsColor = outfitColor.opacity(0.7)
            context.fill(
                Path(roundedRect: CGRect(x: centerX - 7*s, y: bodyTop + 8*s, width: 6*s, height: 7*s), cornerRadius: 1*s),
                with: .color(pantsColor)
            )
            context.fill(
                Path(roundedRect: CGRect(x: centerX + 1*s, y: bodyTop + 8*s, width: 6*s, height: 7*s), cornerRadius: 1*s),
                with: .color(pantsColor)
            )
            // Arms
            let armY = bodyTop + 3 * s
            context.fill(
                Path(roundedRect: CGRect(x: centerX - 12*s, y: armY, width: 6*s, height: 3*s), cornerRadius: 1.5*s),
                with: .color(outfitColor)
            )
            context.fill(
                Path(roundedRect: CGRect(x: centerX + 6*s, y: armY, width: 6*s, height: 3*s), cornerRadius: 1.5*s),
                with: .color(outfitColor)
            )
            // Hands
            context.fill(
                Path(ellipseIn: CGRect(x: centerX - 14*s, y: armY - 0.5*s, width: 4*s, height: 4*s)),
                with: .color(skinColor)
            )
            context.fill(
                Path(ellipseIn: CGRect(x: centerX + 10*s, y: armY - 0.5*s, width: 4*s, height: 4*s)),
                with: .color(skinColor)
            )

        case .hoodie:
            // Rounded hoodie body
            context.fill(
                Path(roundedRect: CGRect(x: centerX - 8*s, y: bodyTop, width: 16*s, height: 14*s), cornerRadius: 4*s),
                with: .color(outfitColor)
            )
            // Hood hint (small arc at collar)
            context.fill(
                Path(ellipseIn: CGRect(x: centerX - 4*s, y: bodyTop - 1*s, width: 8*s, height: 4*s)),
                with: .color(outfitColor)
            )
            // Arms
            let armY = bodyTop + 4 * s
            context.fill(
                Path(roundedRect: CGRect(x: centerX - 13*s, y: armY, width: 6*s, height: 3.5*s), cornerRadius: 1.5*s),
                with: .color(outfitColor)
            )
            context.fill(
                Path(roundedRect: CGRect(x: centerX + 7*s, y: armY, width: 6*s, height: 3.5*s), cornerRadius: 1.5*s),
                with: .color(outfitColor)
            )
            // Hands
            context.fill(
                Path(ellipseIn: CGRect(x: centerX - 15*s, y: armY - 0.5*s, width: 4*s, height: 4*s)),
                with: .color(skinColor)
            )
            context.fill(
                Path(ellipseIn: CGRect(x: centerX + 11*s, y: armY - 0.5*s, width: 4*s, height: 4*s)),
                with: .color(skinColor)
            )

        case .overalls:
            // Shirt underneath
            context.fill(
                Path(roundedRect: CGRect(x: centerX - 7*s, y: bodyTop, width: 14*s, height: 6*s), cornerRadius: 2*s),
                with: .color(.white)
            )
            // Overall body
            context.fill(
                Path(roundedRect: CGRect(x: centerX - 7*s, y: bodyTop + 4*s, width: 14*s, height: 11*s), cornerRadius: 2*s),
                with: .color(outfitColor)
            )
            // Straps
            context.fill(
                Path(roundedRect: CGRect(x: centerX - 5*s, y: bodyTop + 1*s, width: 3*s, height: 5*s), cornerRadius: 1*s),
                with: .color(outfitColor)
            )
            context.fill(
                Path(roundedRect: CGRect(x: centerX + 2*s, y: bodyTop + 1*s, width: 3*s, height: 5*s), cornerRadius: 1*s),
                with: .color(outfitColor)
            )
            // Arms
            let armY = bodyTop + 3 * s
            context.fill(
                Path(roundedRect: CGRect(x: centerX - 12*s, y: armY, width: 6*s, height: 3*s), cornerRadius: 1.5*s),
                with: .color(.white)
            )
            context.fill(
                Path(roundedRect: CGRect(x: centerX + 6*s, y: armY, width: 6*s, height: 3*s), cornerRadius: 1.5*s),
                with: .color(.white)
            )
            // Hands
            context.fill(
                Path(ellipseIn: CGRect(x: centerX - 14*s, y: armY - 0.5*s, width: 4*s, height: 4*s)),
                with: .color(skinColor)
            )
            context.fill(
                Path(ellipseIn: CGRect(x: centerX + 10*s, y: armY - 0.5*s, width: 4*s, height: 4*s)),
                with: .color(skinColor)
            )
        }

        // === LEGS & SHOES (common to all outfits) ===
        let legTop = bodyTop + 14 * s
        let legOffset: CGFloat = stepFrame ? 2 * s : 0

        // Left leg
        context.fill(
            Path(roundedRect: CGRect(x: centerX - 5*s - legOffset, y: legTop, width: 4*s, height: 5*s), cornerRadius: 1*s),
            with: .color(skinColor)
        )
        // Right leg
        context.fill(
            Path(roundedRect: CGRect(x: centerX + 1*s + legOffset, y: legTop, width: 4*s, height: 5*s), cornerRadius: 1*s),
            with: .color(skinColor)
        )
        // Left shoe
        context.fill(
            Path(roundedRect: CGRect(x: centerX - 6*s - legOffset, y: legTop + 4*s, width: 6*s, height: 3*s), cornerRadius: 1.5*s),
            with: .color(shoeColor)
        )
        // Right shoe
        context.fill(
            Path(roundedRect: CGRect(x: centerX + 0*s + legOffset, y: legTop + 4*s, width: 6*s, height: 3*s), cornerRadius: 1.5*s),
            with: .color(shoeColor)
        )
    }
}
