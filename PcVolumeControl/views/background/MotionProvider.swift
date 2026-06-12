import Foundation
import CoreMotion
import Combine

struct Tilt: Equatable {
    var roll: Double
    var pitch: Double

    static let zero = Tilt(roll: 0, pitch: 0)
}

protocol MotionSource: AnyObject {
    var isAvailable: Bool { get }
    func start(handler: @escaping (_ roll: Double, _ pitch: Double) -> Void)
    func stop()
}

final class CoreMotionSource: MotionSource {
    private let manager = CMMotionManager()

    init(updateInterval: TimeInterval = 1.0 / 30.0) {
        manager.deviceMotionUpdateInterval = updateInterval
    }

    var isAvailable: Bool { manager.isDeviceMotionAvailable }

    func start(handler: @escaping (Double, Double) -> Void) {
        guard manager.isDeviceMotionAvailable else { return }
        guard !manager.isDeviceMotionActive else { return }
        manager.startDeviceMotionUpdates(to: .main) { motion, _ in
            guard let motion else { return }
            handler(motion.attitude.roll, motion.attitude.pitch)
        }
    }

    func stop() {
        guard manager.isDeviceMotionActive else { return }
        manager.stopDeviceMotionUpdates()
    }
}

@MainActor
final class MotionProvider: ObservableObject {
    @Published private(set) var tilt: Tilt = .zero

    private let source: MotionSource
    private let smoothing: Double
    private let maxAngleRadians: Double
    private var isRunning = false

    init(
        source: MotionSource = CoreMotionSource(),
        smoothing: Double = 0.12,
        maxAngleDegrees: Double = 25
    ) {
        self.source = source
        self.smoothing = smoothing
        self.maxAngleRadians = maxAngleDegrees * .pi / 180
    }

    func start() {
        guard !isRunning else { return }
        guard source.isAvailable else { return }
        isRunning = true
        source.start { [weak self] roll, pitch in
            Task { @MainActor in
                self?.consume(roll: roll, pitch: pitch)
            }
        }
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        source.stop()
        decayToZero()
    }

    private func consume(roll rawRoll: Double, pitch rawPitch: Double) {
        let clampedRoll = clamp(rawRoll, to: maxAngleRadians)
        let clampedPitch = clamp(rawPitch, to: maxAngleRadians)
        let targetRoll = clampedRoll / maxAngleRadians
        let targetPitch = clampedPitch / maxAngleRadians
        let newRoll = tilt.roll + smoothing * (targetRoll - tilt.roll)
        let newPitch = tilt.pitch + smoothing * (targetPitch - tilt.pitch)
        tilt = Tilt(roll: newRoll, pitch: newPitch)
    }

    private func decayToZero() {
        tilt = Tilt(
            roll: tilt.roll + smoothing * (0 - tilt.roll),
            pitch: tilt.pitch + smoothing * (0 - tilt.pitch)
        )
    }

    private func clamp(_ value: Double, to magnitude: Double) -> Double {
        return max(-magnitude, min(magnitude, value))
    }

    func _testIngest(roll: Double, pitch: Double) {
        consume(roll: roll, pitch: pitch)
    }
}
