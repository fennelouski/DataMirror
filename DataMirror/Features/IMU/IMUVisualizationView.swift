import SwiftUI
import CoreMotion
import UIKit
import Combine
import os

private nonisolated let logger = Logger(subsystem: "com.datamirror", category: "IMU")

// NOTE: We use a dedicated CMMotionManager for device motion updates only.
// The SensorClient already owns a CMMotionManager for accelerometer/gyro updates.
// Per Apple docs, calling startDeviceMotionUpdates on a second CMMotionManager instance
// is fine — it requests a separate data stream (device motion fusion) and does not
// interfere with startAccelerometerUpdates on another instance. iOS serializes hardware
// access transparently across manager instances.

@MainActor
final class IMUViewModel: ObservableObject {
    @Published var accelX: Double = 0
    @Published var accelY: Double = 0
    @Published var accelZ: Double = 0
    @Published var heading: Double = 0
    @Published var roll: Double = 0
    @Published var pitch: Double = 0
    @Published var yaw: Double = 0
    @Published var gravityX: Double = 0
    @Published var gravityY: Double = 0
    @Published var gravityZ: Double = -1
    @Published var isMagnetometerAvailable: Bool = false

    private let motionManager = CMMotionManager()
    private let haptic = UIImpactFeedbackGenerator(style: .light)
    private var lastHapticTime: Date = .distantPast
    private var wasLevel: Bool = false

    func start() {
        #if targetEnvironment(simulator)
        isMagnetometerAvailable = false
        #else
        guard motionManager.isDeviceMotionAvailable else {
            isMagnetometerAvailable = false
            return
        }
        isMagnetometerAvailable = true
        motionManager.deviceMotionUpdateInterval = 0.1
        motionManager.startDeviceMotionUpdates(using: .xMagneticNorthZVertical, to: .main) { [weak self] motion, error in
            guard let self, let motion else {
                if let error {
                    logger.error("Device motion update error: \(error.localizedDescription)")
                }
                return
            }
            self.accelX = motion.userAcceleration.x
            self.accelY = motion.userAcceleration.y
            self.accelZ = motion.userAcceleration.z
            self.heading = motion.heading
            self.roll = motion.attitude.roll * 180 / .pi
            self.pitch = motion.attitude.pitch * 180 / .pi
            self.yaw = motion.attitude.yaw * 180 / .pi
            self.gravityX = motion.gravity.x
            self.gravityY = motion.gravity.y
            self.gravityZ = motion.gravity.z

            let tiltAngle = sqrt(motion.gravity.x * motion.gravity.x + motion.gravity.y * motion.gravity.y) * 90
            let isLevel = tiltAngle < 2.0
            if isLevel && !self.wasLevel {
                let now = Date()
                if now.timeIntervalSince(self.lastHapticTime) >= 1.0 {
                    self.haptic.impactOccurred()
                    self.lastHapticTime = now
                }
            }
            self.wasLevel = isLevel
        }
        #endif
    }

    func stop() {
        #if !targetEnvironment(simulator)
        motionManager.stopDeviceMotionUpdates()
        #endif
    }
}

struct IMUVisualizationView: View {
    @StateObject private var viewModel = IMUViewModel()

    var body: some View {
        #if targetEnvironment(simulator)
        VStack(spacing: 8) {
            Image(systemName: "gyroscope")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(String(localized: "IMU visualization unavailable on Simulator"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        #else
        TabView {
            BubbleLevelView(viewModel: viewModel)
                .tabItem { Label(String(localized: "Level"), systemImage: "circle.circle") }

            CompassView(viewModel: viewModel)
                .tabItem { Label(String(localized: "Compass"), systemImage: "location.north.line.fill") }

            GravityArrowView(viewModel: viewModel)
                .tabItem { Label(String(localized: "Gravity"), systemImage: "arrow.down.circle.fill") }
        }
        .tabViewStyle(.page)
        .frame(height: 320)
        .onAppear { viewModel.start() }
        .onDisappear { viewModel.stop() }
        #endif
    }
}

// MARK: - Bubble Level

private struct BubbleLevelView: View {
    @ObservedObject var viewModel: IMUViewModel

    private let ringSize: CGFloat = 200
    private let bubbleSize: CGFloat = 50
    private let targetRingSize: CGFloat = 60

    private var bubbleOffset: CGSize {
        let maxOffset = (ringSize - bubbleSize) / 2 - 4
        let offsetX = CGFloat(-viewModel.gravityX) * maxOffset
        let offsetY = CGFloat(viewModel.gravityY) * maxOffset
        let distance = sqrt(offsetX * offsetX + offsetY * offsetY)
        if distance > maxOffset {
            let scale = maxOffset / distance
            return CGSize(width: offsetX * scale, height: offsetY * scale)
        }
        return CGSize(width: offsetX, height: offsetY)
    }

    private var isLevel: Bool {
        let tilt = sqrt(viewModel.gravityX * viewModel.gravityX + viewModel.gravityY * viewModel.gravityY) * 90
        return tilt < 2.0
    }

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color(.systemGray4), lineWidth: 3)
                    .frame(width: ringSize, height: ringSize)

                Circle()
                    .stroke(isLevel ? Color.green : Color(.systemGray3), lineWidth: 2)
                    .frame(width: targetRingSize, height: targetRingSize)
                    .animation(.easeInOut(duration: 0.2), value: isLevel)

                Rectangle()
                    .fill(Color(.systemGray4).opacity(0.5))
                    .frame(width: 1, height: ringSize)
                Rectangle()
                    .fill(Color(.systemGray4).opacity(0.5))
                    .frame(width: ringSize, height: 1)

                Circle()
                    .fill(isLevel ? Color.green : Color.blue)
                    .frame(width: bubbleSize, height: bubbleSize)
                    .offset(bubbleOffset)
                    .animation(.interpolatingSpring(stiffness: 100, damping: 15), value: bubbleOffset)
            }
            .frame(width: ringSize, height: ringSize)

            Text(String(format: String(localized: "Tilt: %.1f°"),
                        sqrt(viewModel.gravityX * viewModel.gravityX + viewModel.gravityY * viewModel.gravityY) * 90))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .accessibilityLabel(String(localized: "Bubble Level"))
    }
}

// MARK: - Compass

private struct CompassView: View {
    @ObservedObject var viewModel: IMUViewModel

    private var headingCardinal: String {
        let h = viewModel.heading
        switch h {
        case 0..<22.5, 337.5...360: return "N"
        case 22.5..<67.5: return "NE"
        case 67.5..<112.5: return "E"
        case 112.5..<157.5: return "SE"
        case 157.5..<202.5: return "S"
        case 202.5..<247.5: return "SW"
        case 247.5..<292.5: return "W"
        case 292.5..<337.5: return "NW"
        default: return "N"
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            if viewModel.isMagnetometerAvailable {
                Text(String(format: "%.0f° %@", viewModel.heading, headingCardinal))
                    .font(.title3.monospacedDigit().bold())

                Canvas { context, size in
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    let radius = min(size.width, size.height) / 2 - 10
                    let rotationAngle = -viewModel.heading * .pi / 180

                    context.stroke(Path(ellipseIn: CGRect(
                        x: center.x - radius, y: center.y - radius,
                        width: radius * 2, height: radius * 2
                    )), with: .color(.secondary), lineWidth: 2)

                    let cardinals: [(String, Double)] = [
                        ("N", 0), ("NE", 45), ("E", 90), ("SE", 135),
                        ("S", 180), ("SW", 225), ("W", 270), ("NW", 315),
                    ]
                    for (label, baseDeg) in cardinals {
                        let angle = (baseDeg * .pi / 180) + rotationAngle - .pi / 2
                        let isMain = ["N", "S", "E", "W"].contains(label)
                        let markerRadius = isMain ? radius - 4 : radius - 10
                        let textRadius = radius - 22

                        let markerX = center.x + cos(angle) * markerRadius
                        let markerY = center.y + sin(angle) * markerRadius
                        let outerX = center.x + cos(angle) * (radius - 2)
                        let outerY = center.y + sin(angle) * (radius - 2)

                        var path = Path()
                        path.move(to: CGPoint(x: markerX, y: markerY))
                        path.addLine(to: CGPoint(x: outerX, y: outerY))
                        context.stroke(path, with: .color(isMain ? .primary : .secondary), lineWidth: isMain ? 2 : 1)

                        let textX = center.x + cos(angle) * textRadius
                        let textY = center.y + sin(angle) * textRadius
                        let color: Color = label == "N" ? .red : .primary
                        context.draw(
                            Text(label).font(.caption2.bold()).foregroundColor(color),
                            at: CGPoint(x: textX, y: textY)
                        )
                    }

                    let northAngle = rotationAngle - .pi / 2
                    let needleTipX = center.x + cos(northAngle) * (radius - 30)
                    let needleTipY = center.y + sin(northAngle) * (radius - 30)
                    var needle = Path()
                    needle.move(to: center)
                    needle.addLine(to: CGPoint(x: needleTipX, y: needleTipY))
                    context.stroke(needle, with: .color(.red), lineWidth: 3)

                    context.fill(
                        Path(ellipseIn: CGRect(x: center.x - 4, y: center.y - 4, width: 8, height: 8)),
                        with: .color(.primary)
                    )
                }
                .frame(width: 200, height: 200)
                .animation(.linear(duration: 0.1), value: viewModel.heading)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "location.slash")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text(String(localized: "Compass unavailable"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 200, height: 200)
            }
        }
        .accessibilityLabel(String(localized: "Compass showing \(String(format: "%.0f", viewModel.heading)) degrees \(headingCardinal)"))
    }
}

// MARK: - Gravity Arrow

private struct GravityArrowView: View {
    @ObservedObject var viewModel: IMUViewModel

    private var arrowAngle: Angle {
        .radians(atan2(viewModel.gravityX, -viewModel.gravityY))
    }

    private var isFaceUp: Bool {
        abs(viewModel.gravityZ) > 0.85
    }

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color(.systemGray4), lineWidth: 2)
                    .frame(width: 160, height: 160)

                if isFaceUp {
                    Circle()
                        .fill(Color.blue.opacity(0.3))
                        .frame(width: 40, height: 40)
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                } else {
                    ArrowShape()
                        .fill(Color.blue)
                        .frame(width: 30, height: 80)
                        .rotationEffect(arrowAngle)
                        .animation(.linear(duration: 0.1), value: arrowAngle)
                }
            }
            .frame(width: 160, height: 160)

            Text(String(localized: "Gravity is constant. The direction shows your device's orientation in space."))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Text(String(localized: "9.8 m/s²"))
                .font(.caption.monospacedDigit().bold())

            HStack(spacing: 20) {
                AttitudeLabel(label: String(localized: "Roll"), value: viewModel.roll)
                AttitudeLabel(label: String(localized: "Pitch"), value: viewModel.pitch)
                AttitudeLabel(label: String(localized: "Yaw"), value: viewModel.yaw)
            }
        }
        .accessibilityLabel(String(localized: "Gravity direction visualization"))
    }
}

private struct AttitudeLabel: View {
    let label: String
    let value: Double

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(String(format: "%.1f°", value))
                .font(.caption.monospacedDigit())
        }
    }
}

private struct ArrowShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midX = rect.midX
        let headHeight = rect.height * 0.35
        let shaftWidth = rect.width * 0.3
        let shaftStart = rect.minY + headHeight

        path.move(to: CGPoint(x: midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: shaftStart))
        path.addLine(to: CGPoint(x: midX + shaftWidth / 2, y: shaftStart))
        path.addLine(to: CGPoint(x: midX + shaftWidth / 2, y: rect.maxY))
        path.addLine(to: CGPoint(x: midX - shaftWidth / 2, y: rect.maxY))
        path.addLine(to: CGPoint(x: midX - shaftWidth / 2, y: shaftStart))
        path.addLine(to: CGPoint(x: rect.minX, y: shaftStart))
        path.closeSubpath()
        return path
    }
}
