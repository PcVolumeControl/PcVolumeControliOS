import UIKit

/// Decoded application icons by icon id and requested pixel size, cached in memory
/// (bounded) and on disk. Ids are content-derived, so entries never need invalidating.
/// Decoding runs on this actor, off the main thread.
actor IconRepository {
    private let disk: IconDiskCacheDataSourceProtocol
    private let memory = NSCache<NSString, UIImage>()

    init(disk: IconDiskCacheDataSourceProtocol = IconDiskCacheDataSource()) {
        self.disk = disk
        memory.countLimit = 128
    }

    /// The icons among `ids` that are cached at `size`, from memory or disk.
    func cachedIcons(for ids: [String], size: Int) -> [String: UIImage] {
        var found: [String: UIImage] = [:]
        for id in ids {
            let key = Self.key(id, size)
            if let image = memory.object(forKey: key) {
                found[id] = image
            } else if let png = disk.load(id: id, size: size), let image = Self.decode(png) {
                memory.setObject(image, forKey: key)
                found[id] = image
            }
        }
        return found
    }

    /// Decodes `png`, requested at `size`, and caches it under `id`. Returns nil, caching
    /// nothing, when the data is not a usable image.
    func store(png: Data, for id: String, size: Int) -> UIImage? {
        guard let image = Self.decode(png) else { return nil }
        memory.setObject(image, forKey: Self.key(id, size))
        disk.store(png, id: id, size: size)
        return image
    }

    private static func key(_ id: String, _ size: Int) -> NSString {
        NSString(string: "\(id)_\(size)")
    }

    private static func decode(_ png: Data) -> UIImage? {
        UIImage(data: png)?.preparingForDisplay()
    }
}
