import CoreGraphics

/// Decides which icon ids to request, within the protocol's limits: at most
/// `maxIdsPerRequest` ids per request and `maxOutstanding` unanswered ids per connection.
struct IconRequestPlanner {
    static let maxIdsPerRequest = 32
    static let maxOutstanding = 64

    /// Ids requested on the current connection that have not been answered yet.
    private(set) var outstanding = Set<String>()
    // Ids the server had no usable image for. Kept across reconnects so they are not
    // asked for again in a loop; a new planner starts clean.
    private var unavailable = Set<String>()

    /// The requests to send now for `ids`, in order. Leaves out ids that are invalid,
    /// repeated, in `skipping` (cached or being resolved locally), already outstanding, or
    /// unavailable, and stops at the outstanding limit; the rest are planned once replies
    /// free up room. Returns nothing unless the server supports icons.
    mutating func requests(for ids: [String], supportsIcons: Bool, skipping: Set<String>) -> [[String]] {
        guard supportsIcons else { return [] }

        let capacity = Self.maxOutstanding - outstanding.count
        var planned: [String] = []
        var seen = Set<String>()
        for id in ids where planned.count < capacity {
            guard IconId.isValid(id),
                  seen.insert(id).inserted,
                  !skipping.contains(id),
                  !outstanding.contains(id),
                  !unavailable.contains(id)
            else { continue }
            planned.append(id)
        }
        outstanding.formUnion(planned)

        return stride(from: 0, to: planned.count, by: Self.maxIdsPerRequest).map {
            Array(planned[$0..<min($0 + Self.maxIdsPerRequest, planned.count)])
        }
    }

    /// Records the reply for `id`. `available` is false when the server had no image or
    /// the image could not be decoded.
    mutating func recordReply(for id: String, available: Bool) {
        outstanding.remove(id)
        if !available {
            unavailable.insert(id)
        }
    }

    /// Replies to ids requested on a dropped connection never arrive.
    mutating func connectionDropped() {
        outstanding.removeAll()
    }

    /// The edge length in pixels to request for icons drawn at `points` on a display of `scale`.
    static func pixelSize(points: CGFloat, scale: CGFloat) -> Int {
        Int(min(max((points * scale).rounded(), 16), 256))
    }
}
