import SwiftUI
import simd

struct MotionMeshBackground: View {
    @EnvironmentObject private var motion: MotionProvider
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { context in
            let phase = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            mesh(phase: phase)
        }
        .ignoresSafeArea()
    }

    private func mesh(phase: Double) -> some View {
        let tilt = reduceMotion ? Tilt.zero : motion.tilt
        let points = meshPoints(phase: phase, tilt: tilt)
        return MeshGradient(
            width: MotionMeshPalette.columns,
            height: MotionMeshPalette.rows,
            points: points,
            colors: MotionMeshPalette.colors,
            smoothsColors: true
        )
    }

    private func meshPoints(phase: Double, tilt: Tilt) -> [SIMD2<Float>] {
        let base = MotionMeshPalette.basePoints
        let tiltOffset = SIMD2<Float>(Float(tilt.roll), Float(tilt.pitch)) * MotionMeshPalette.tiltAmplitude
        var result: [SIMD2<Float>] = []
        result.reserveCapacity(base.count)
        for i in 0..<base.count {
            if MotionMeshPalette.isInteriorPoint(index: i) {
                let ambient = MotionMeshPalette.ambientOffset(forIndex: i, phase: phase)
                result.append(base[i] + tiltOffset + ambient)
            } else {
                result.append(base[i])
            }
        }
        return result
    }
}

#Preview {
    MotionMeshBackground()
        .environmentObject(MotionProvider())
}
