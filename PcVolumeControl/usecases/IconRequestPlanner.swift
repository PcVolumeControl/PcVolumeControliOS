import CoreGraphics

/// Decides which icon ids to request, within the protocol's limits: at most
/// `maxIdsPerRequest` ids per request and `maxOutstanding` unanswered ids per connection.
struct IconRequestPlanner {
    static let maxIdsPerRequest = 32
    static let maxOutstanding = 64

    /// Ids requested on the current connection and not answered yet, with the pixel size
    /// each was requested at.
    private(set) var outstanding: [String: Int] = [:]
    // Ids the server had no usable image for. Kept across reconnects so they are not
    // asked for again in a loop; a new planner starts clean.
    private var unavailable = Set<String>()

    /// True when a full request fits under the outstanding limit.
    var hasRoomForFullBatch: Bool {
        outstanding.count + Self.maxIdsPerRequest <= Self.maxOutstanding
    }

    /// The requests to send now for `ids`, in order, at `size` pixels. Leaves out ids that
    /// are invalid, repeated, in `skipping` (cached or being resolved locally), already
    /// outstanding, or unavailable, and stops at the outstanding limit; the rest are
    /// planned once replies free up room. Returns nothing unless the server supports icons.
    mutating func requests(for ids: [String], size: Int, supportsIcons: Bool, skipping: Set<String>) -> [[String]] {
        guard supportsIcons else { return [] }

        let capacity = Self.maxOutstanding - outstanding.count
        var planned: [String] = []
        var seen = Set<String>()
        for id in ids where planned.count < capacity {
            guard IconId.isValid(id),
                  seen.insert(id).inserted,
                  !skipping.contains(id),
                  outstanding[id] == nil,
                  !unavailable.contains(id)
            else { continue }
            planned.append(id)
        }
        for id in planned {
            outstanding[id] = size
        }

        return stride(from: 0, to: planned.count, by: Self.maxIdsPerRequest).map {
            Array(planned[$0..<min($0 + Self.maxIdsPerRequest, planned.count)])
        }
    }

    /// Records the reply for `id` and returns the pixel size it was requested at, or nil
    /// when `id` was not outstanding (a reply nobody asked for). `available` is false when
    /// the server had no image.
    mutating func recordReply(for id: String, available: Bool) -> Int? {
        guard let size = outstanding.removeValue(forKey: id) else { return nil }
        if !available {
            unavailable.insert(id)
        }
        return size
    }

    /// For an image that arrived but could not be decoded.
    mutating func markUnavailable(_ id: String) {
        unavailable.insert(id)
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
