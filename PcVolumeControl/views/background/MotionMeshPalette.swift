import SwiftUI
import simd

enum MotionMeshPalette {
    static let columns = 4
    static let rows = 5

    static let tiltAmplitude: Float = 0.06
    static let ambientAmplitude: Float = 0.015

    static let basePoints: [SIMD2<Float>] = {
        var points: [SIMD2<Float>] = []
        for row in 0..<rows {
            for col in 0..<columns {
                let x = Float(col) / Float(columns - 1)
                let y = Float(row) / Float(rows - 1)
                points.append(SIMD2<Float>(x, y))
            }
        }
        return points
    }()

    static func isInteriorPoint(index: Int) -> Bool {
        let col = index % columns
        let row = index / columns
        return col > 0 && col < columns - 1 && row > 0 && row < rows - 1
    }

    private static let edgeIndigo = Color(red: 0x0A / 255.0, green: 0x0E / 255.0, blue: 0x1F / 255.0)
    private static let deepIndigo = Color(red: 0x10 / 255.0, green: 0x14 / 255.0, blue: 0x28 / 255.0)
    private static let deepBlue = Color(red: 0x1B / 255.0, green: 0x2A / 255.0, blue: 0x6B / 255.0)
    private static let violet = Color(red: 0x3A / 255.0, green: 0x1E / 255.0, blue: 0x78 / 255.0)
    private static let teal = Color(red: 0x0E / 255.0, green: 0x3B / 255.0, blue: 0x4E / 255.0)
    private static let midnight = Color(red: 0x14 / 255.0, green: 0x18 / 255.0, blue: 0x35 / 255.0)

    static let colors: [Color] = [
        edgeIndigo,  edgeIndigo,  edgeIndigo,  edgeIndigo,
        edgeIndigo,  deepBlue,    violet,      edgeIndigo,
        edgeIndigo,  teal,        midnight,    edgeIndigo,
        edgeIndigo,  deepIndigo,  deepBlue,    edgeIndigo,
        edgeIndigo,  edgeIndigo,  edgeIndigo,  edgeIndigo,
    ]

    static func ambientOffset(forIndex i: Int, phase: Double) -> SIMD2<Float> {
        let fi = Float(i)
        let fx = sin(Float(phase) * (0.22 + 0.07 * fi) + fi * 1.7)
        let fy = cos(Float(phase) * (0.18 + 0.05 * fi) + fi * 2.3)
        return SIMD2<Float>(fx, fy) * ambientAmplitude
    }
}
