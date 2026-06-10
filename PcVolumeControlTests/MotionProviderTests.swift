import XCTest
@testable import PcVolumeControl

final class FakeMotionSource: MotionSource {
    var isAvailable: Bool
    var handler: ((Double, Double) -> Void)?
    var isStarted = false
    var stopCount = 0

    init(isAvailable: Bool = true) {
        self.isAvailable = isAvailable
    }

    func start(handler: @escaping (Double, Double) -> Void) {
        self.handler = handler
        isStarted = true
    }

    func stop() {
        stopCount += 1
        isStarted = false
        handler = nil
    }

    func emit(roll: Double, pitch: Double) {
        handler?(roll, pitch)
    }
}

@MainActor
final class MotionProviderTests: XCTestCase {

    func test_tilt_starts_at_zero() {
        let provider = MotionProvider(source: FakeMotionSource())
        XCTAssertEqual(provider.tilt, .zero)
    }

    func test_unavailable_source_keeps_tilt_at_zero() {
        let source = FakeMotionSource(isAvailable: false)
        let provider = MotionProvider(source: source)
        provider.start()
        XCTAssertFalse(source.isStarted, "Should not start when source is unavailable")
        XCTAssertEqual(provider.tilt, .zero)
    }

    func test_step_input_damps_over_samples() {
        let provider = MotionProvider(source: FakeMotionSource(), smoothing: 0.5, maxAngleDegrees: 90)
        let target: Double = .pi / 2
        provider._testIngest(roll: target, pitch: target)
        XCTAssertEqual(provider.tilt.roll, 0.5, accuracy: 0.001, "First sample should be half-way to 1.0")
        provider._testIngest(roll: target, pitch: target)
        XCTAssertEqual(provider.tilt.roll, 0.75, accuracy: 0.001)
        provider._testIngest(roll: target, pitch: target)
        XCTAssertEqual(provider.tilt.roll, 0.875, accuracy: 0.001)
    }

    func test_input_beyond_max_saturates_at_one() {
        let provider = MotionProvider(
            source: FakeMotionSource(),
            smoothing: 1.0,
            maxAngleDegrees: 25
        )
        let twoX: Double = (50.0 * .pi / 180.0)
        provider._testIngest(roll: twoX, pitch: twoX)
        XCTAssertEqual(provider.tilt.roll, 1.0, accuracy: 0.001)
        XCTAssertEqual(provider.tilt.pitch, 1.0, accuracy: 0.001)
        provider._testIngest(roll: -twoX, pitch: -twoX)
        XCTAssertEqual(provider.tilt.roll, -1.0, accuracy: 0.001)
        XCTAssertEqual(provider.tilt.pitch, -1.0, accuracy: 0.001)
    }

    func test_stop_is_idempotent_and_releases_source() {
        let source = FakeMotionSource()
        let provider = MotionProvider(source: source)
        provider.start()
        XCTAssertTrue(source.isStarted)
        provider.stop()
        provider.stop()
        XCTAssertEqual(source.stopCount, 1, "Stop should be idempotent")
        XCTAssertFalse(source.isStarted)
    }

    func test_start_is_idempotent() {
        let source = FakeMotionSource()
        let provider = MotionProvider(source: source)
        provider.start()
        provider.start()
        XCTAssertTrue(source.isStarted)
        provider.stop()
    }

    func test_consume_via_source_callback_updates_tilt() {
        let source = FakeMotionSource()
        let provider = MotionProvider(source: source, smoothing: 1.0, maxAngleDegrees: 25)
        provider.start()
        let oneRadAtMax: Double = (25.0 * .pi / 180.0)
        let exp = expectation(description: "tilt updated")
        Task { @MainActor in
            source.emit(roll: oneRadAtMax, pitch: -oneRadAtMax)
            try? await Task.sleep(nanoseconds: 20_000_000)
            XCTAssertEqual(provider.tilt.roll, 1.0, accuracy: 0.001)
            XCTAssertEqual(provider.tilt.pitch, -1.0, accuracy: 0.001)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }
}
