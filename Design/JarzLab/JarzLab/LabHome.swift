import SwiftUI

// MARK: - Paper Glow design tokens

enum Lab {
    static let paper = Color(red: 0.968, green: 0.965, blue: 0.949)
    static let card = Color.white
    static let ink = Color(red: 0.090, green: 0.088, blue: 0.080)
    static let secondary = Color(red: 0.52, green: 0.51, blue: 0.47)
    static let hairline = Color(red: 0.884, green: 0.874, blue: 0.842)
    static let green = Color(red: 0.09, green: 0.63, blue: 0.37)
    static let greenDeep = Color(red: 0.03, green: 0.45, blue: 0.26)
    static let amber = Color(red: 0.875, green: 0.63, blue: 0.20)
    static let amberDeep = Color(red: 0.76, green: 0.48, blue: 0.08)

    static func serif(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
}

struct JarModel: Identifiable {
    let id = UUID()
    let name: String
    let amount: String
    let fill: Double
    let isGoal: Bool
    var goalTotal: String?
    var paceDate: String?
}

// MARK: - Root

struct LabHome: View {
    private let jars: [JarModel] = [
        .init(name: "Trips", amount: "25 000", fill: 0.25, isGoal: true, goalTotal: "100 000", paceDate: "≈ 8 Jun"),
        .init(name: "Savings", amount: "12 000", fill: 0.20, isGoal: true, goalTotal: "60 000", paceDate: "≈ 14 Mar"),
        .init(name: "Sport", amount: "3 500", fill: 0.85, isGoal: false),
        .init(name: "Gifts", amount: "3 000", fill: 0.25, isGoal: false),
    ]

    private let listJars: [JarModel] = [
        .init(name: "Apartment", amount: "40 000", fill: 0.95, isGoal: false),
        .init(name: "Bills", amount: "16 000", fill: 0.60, isGoal: false),
        .init(name: "Trips", amount: "25 000", fill: 0.25, isGoal: true, goalTotal: "100 000", paceDate: "≈ 8 Jun"),
        .init(name: "Savings", amount: "12 000", fill: 0.20, isGoal: true, goalTotal: "60 000", paceDate: "≈ 14 Mar"),
    ]

    @State private var focusedCard: Int? = 0
    @State private var appeared = false

    private let autoAdvance = Timer.publish(every: 2.6, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Lab.paper.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    FoodHeroCard(appeared: appeared)
                    SectionCaps("Jars · swipe")
                    carousel
                    SectionCaps("Jars · list")
                    listCard
                    footer
                }
                .padding(.horizontal, 18)
                .padding(.top, 6)
                .padding(.bottom, 90)
            }
            tabBar
        }
        .onAppear {
            withAnimation(.spring(duration: 1.2)) { appeared = true }
        }
        .onReceive(autoAdvance) { _ in
            withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                focusedCard = ((focusedCard ?? 0) + 1) % jars.count
            }
        }
    }

    private var header: some View {
        HStack {
            Text("JARZ")
                .font(.system(size: 13, weight: .semibold))
                .tracking(4)
                .foregroundStyle(Lab.secondary)
            Spacer()
            Text("30 350 RSD")
                .font(Lab.serif(15))
                .foregroundStyle(Lab.secondary)
        }
        .padding(.top, 8)
    }

    private var carousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 14) {
                ForEach(Array(jars.enumerated()), id: \.element.id) { index, jar in
                    JarSceneCard(jar: jar, appeared: appeared)
                        .containerRelativeFrame(.horizontal, count: 10, span: 7, spacing: 14)
                        .id(index)
                        .scrollTransition { content, phase in
                            content
                                .scaleEffect(phase.isIdentity ? 1 : 0.92)
                                .opacity(phase.isIdentity ? 1 : 0.75)
                        }
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $focusedCard, anchor: .center)
        .frame(height: 320)
        .padding(.horizontal, -18)
        .safeAreaPadding(.horizontal, 42)
        .overlay(alignment: .bottom) {
            HStack(spacing: 6) {
                ForEach(0..<jars.count, id: \.self) { index in
                    Circle()
                        .fill(index == (focusedCard ?? 0) ? Lab.ink : Lab.hairline)
                        .frame(width: 6, height: 6)
                }
            }
            .offset(y: 14)
        }
    }

    private var listCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(listJars.enumerated()), id: \.element.id) { index, jar in
                GlowBarRow(jar: jar, appeared: appeared, delay: Double(index) * 0.15)
                if index < listJars.count - 1 {
                    Rectangle().fill(Lab.hairline).frame(height: 1)
                        .padding(.leading, 18)
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: 24).fill(Lab.card)
            .shadow(color: .black.opacity(0.05), radius: 18, y: 8))
    }

    private var footer: some View {
        HStack {
            Text("TOTAL PLANNED")
                .font(.system(size: 11, weight: .semibold))
                .tracking(2.2)
                .foregroundStyle(Lab.secondary)
            Spacer()
            Text("128 350 RSD")
                .font(Lab.serif(19))
                .foregroundStyle(Lab.ink)
        }
        .padding(.top, 4)
    }

    private var tabBar: some View {
        VStack {
            Spacer()
            HStack {
                tabItem("house.fill", "Home", active: true)
                tabItem("tray.and.arrow.down", "Income", active: false)
                tabItem("scalemass", "Revision", active: false)
                tabItem("gearshape", "Settings", active: false)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 26)
            .background(Capsule().fill(.white).shadow(color: .black.opacity(0.10), radius: 20, y: 6))
            .padding(.bottom, 12)
        }
    }

    private func tabItem(_ icon: String, _ title: String, active: Bool) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 17, weight: .medium))
            Text(title).font(.system(size: 10, weight: .medium))
        }
        .foregroundStyle(active ? Lab.greenDeep : Lab.secondary)
        .frame(maxWidth: .infinity)
    }
}

struct SectionCaps: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .tracking(2.4)
            .foregroundStyle(Lab.secondary)
    }
}

// MARK: - Food hero: glowing ring + runway

struct FoodHeroCard: View {
    let appeared: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 18) {
                GlowRing(progress: appeared ? 0.85 : 0.02, color: Lab.green, deep: Lab.greenDeep, line: 9)
                    .frame(width: 96, height: 96)
                    .overlay(
                        VStack(spacing: 0) {
                            Text("1 350").font(Lab.serif(24)).foregroundStyle(Lab.ink)
                            Text("RSD").font(.system(size: 9, weight: .semibold)).tracking(1.5)
                                .foregroundStyle(Lab.secondary)
                        }
                    )
                VStack(alignment: .leading, spacing: 5) {
                    Text("FOOD").font(.system(size: 11, weight: .semibold)).tracking(2.2)
                        .foregroundStyle(Lab.secondary)
                    Text("left for today, 21 Sep")
                        .font(.system(size: 15))
                        .foregroundStyle(Lab.ink)
                    Text("85% of today’s envelope")
                        .font(.system(size: 12))
                        .foregroundStyle(Lab.greenDeep)
                }
                Spacer()
            }
            Runway(appeared: appeared)
            Text("27 days planned ahead · until 18 Oct")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Lab.greenDeep)
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 24).fill(Lab.card)
            .shadow(color: .black.opacity(0.05), radius: 18, y: 8))
    }
}

struct Runway: View {
    let appeared: Bool
    var body: some View {
        HStack(spacing: 3.5) {
            ForEach(0..<27, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(index < 24 ? Lab.green : Lab.hairline)
                    .frame(height: 10)
                    .shadow(color: index < 24 ? Lab.green.opacity(0.55) : .clear, radius: 4)
                    .opacity(appeared ? 1 : 0.15)
                    .animation(.easeOut(duration: 0.35).delay(Double(index) * 0.035), value: appeared)
            }
        }
    }
}

struct GlowRing: View {
    let progress: Double
    let color: Color
    let deep: Color
    var line: CGFloat = 8

    var body: some View {
        ZStack {
            Circle().stroke(Lab.hairline.opacity(0.6), lineWidth: line)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(colors: [deep, color], center: .center,
                                    startAngle: .degrees(0), endAngle: .degrees(320)),
                    style: StrokeStyle(lineWidth: line, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: color.opacity(0.55), radius: 8)
                .shadow(color: color.opacity(0.25), radius: 16)
            Circle()
                .frame(width: line + 2, height: line + 2)
                .foregroundStyle(color)
                .shadow(color: color.opacity(0.9), radius: 6)
                .offset(y: -ringRadius)
                .rotationEffect(.degrees(progress * 360 - 90 + 90))
        }
        .animation(.spring(response: 1.4, dampingFraction: 0.85), value: progress)
    }

    private var ringRadius: CGFloat { 48 - line / 2 }
}

// MARK: - Carousel jar card with live liquid

struct JarSceneCard: View {
    let jar: JarModel
    let appeared: Bool

    private var tint: Color { jar.isGoal ? Lab.amber : Lab.green }
    private var deep: Color { jar.isGoal ? Lab.amberDeep : Lab.greenDeep }

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 26).fill(Lab.card)
                .shadow(color: .black.opacity(0.06), radius: 18, y: 8)

            LiquidFill(level: appeared ? jar.fill : 0.02, color: tint)
                .clipShape(RoundedRectangle(cornerRadius: 26))
                .animation(.spring(response: 1.6, dampingFraction: 0.8), value: appeared)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(jar.name.uppercased())
                        .font(.system(size: 12, weight: .semibold)).tracking(2)
                        .foregroundStyle(Lab.secondary)
                    Spacer()
                    if jar.isGoal {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Lab.amber)
                            .shadow(color: Lab.amber.opacity(0.8), radius: 5)
                    }
                }
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(jar.amount).font(Lab.serif(34)).foregroundStyle(Lab.ink)
                    if let total = jar.goalTotal {
                        Text("/ \(total)").font(Lab.serif(15)).foregroundStyle(Lab.secondary)
                    }
                }
                if let pace = jar.paceDate {
                    Text("\(pace) · at your pace")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(deep)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Capsule().fill(tint.opacity(0.14)))
                        .overlay(Capsule().stroke(tint.opacity(0.35), lineWidth: 1))
                        .shadow(color: tint.opacity(0.35), radius: 8)
                } else {
                    Text("\(Int(jar.fill * 100))% of plan left")
                        .font(.system(size: 12))
                        .foregroundStyle(Lab.secondary)
                }
                Spacer()
            }
            .padding(18)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .frame(height: 300)
    }
}

/// Continuously sloshing liquid surface drawn in a TimelineView canvas.
struct LiquidFill: View {
    let level: Double
    let color: Color

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let surfaceY = size.height * (1 - level)
                var path = Path()
                path.move(to: CGPoint(x: 0, y: size.height))
                path.addLine(to: CGPoint(x: 0, y: surfaceY))
                let amplitude: CGFloat = 5
                let waveLength = size.width / 1.3
                var x: CGFloat = 0
                while x <= size.width {
                    let relative = x / waveLength
                    let y = surfaceY
                        + sin(relative * .pi * 2 + t * 1.7) * amplitude
                        + sin(relative * .pi * 4 + t * 0.9) * amplitude * 0.4
                    path.addLine(to: CGPoint(x: x, y: y))
                    x += 3
                }
                path.addLine(to: CGPoint(x: size.width, y: size.height))
                path.closeSubpath()

                let gradient = Gradient(stops: [
                    .init(color: color.opacity(0.34), location: 0),
                    .init(color: color.opacity(0.16), location: 1),
                ])
                ctx.fill(path, with: .linearGradient(
                    gradient,
                    startPoint: CGPoint(x: 0, y: surfaceY),
                    endPoint: CGPoint(x: 0, y: size.height)))

                // luminous surface line
                var surface = Path()
                x = 0
                surface.move(to: CGPoint(x: 0, y: surfaceY + sin(t * 1.7) * amplitude))
                while x <= size.width {
                    let relative = x / waveLength
                    let y = surfaceY
                        + sin(relative * .pi * 2 + t * 1.7) * amplitude
                        + sin(relative * .pi * 4 + t * 0.9) * amplitude * 0.4
                    surface.addLine(to: CGPoint(x: x, y: y))
                    x += 3
                }
                ctx.stroke(surface, with: .color(color.opacity(0.85)), lineWidth: 2)
                ctx.addFilter(.blur(radius: 4))
                ctx.stroke(surface, with: .color(color.opacity(0.6)), lineWidth: 5)
            }
        }
    }
}

// MARK: - List row with glowing progress bar under text

struct GlowBarRow: View {
    let jar: JarModel
    let appeared: Bool
    let delay: Double

    private var tint: Color { jar.isGoal ? Lab.amber : Lab.green }
    private var deep: Color { jar.isGoal ? Lab.amberDeep : Lab.greenDeep }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                Text(jar.name).font(.system(size: 16)).foregroundStyle(Lab.ink)
                if jar.isGoal {
                    Image(systemName: "star.fill").font(.system(size: 9)).foregroundStyle(Lab.amber)
                }
                Spacer()
                Text("\(jar.amount) RSD").font(Lab.serif(16)).foregroundStyle(Lab.ink)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Lab.hairline.opacity(0.55)).frame(height: 5)
                    Capsule()
                        .fill(LinearGradient(colors: [deep, tint], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(10, geo.size.width * (appeared ? jar.fill : 0.02)), height: 5)
                        .shadow(color: tint.opacity(0.65), radius: 5)
                        .shadow(color: tint.opacity(0.30), radius: 12)
                    Circle()
                        .fill(.white)
                        .frame(width: 11, height: 11)
                        .overlay(Circle().stroke(tint, lineWidth: 3))
                        .shadow(color: tint.opacity(0.9), radius: 5)
                        .offset(x: max(10, geo.size.width * (appeared ? jar.fill : 0.02)) - 5.5)
                    if jar.isGoal, let pace = jar.paceDate {
                        Text(pace)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(deep)
                            .offset(x: geo.size.width - 44, y: -16)
                    }
                }
                .animation(.spring(response: 1.1, dampingFraction: 0.8).delay(delay), value: appeared)
            }
            .frame(height: 12)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }
}

#Preview {
    LabHome()
}
