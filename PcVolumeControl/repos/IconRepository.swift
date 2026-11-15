import UIKit

/// Decoded application icons by icon id, cached in memory (bounded) and on disk. Ids are
/// content-derived, so entries never need invalidating. Decoding runs on this actor,
/// off the main thread.
actor IconRepository {
    private let disk: IconDiskCacheDataSourceProtocol
    private let memory = NSCache<NSString, UIImage>()

    init(disk: IconDiskCacheDataSourceProtocol = IconDiskCacheDataSource()) {
        self.disk = disk
        memory.countLimit = 128
    }

    /// The cached icon for `id` from memory or disk, or nil if it is not cached.
    func cachedIcon(for id: String) -> UIImage? {
        if let image = memory.object(forKey: id as NSString) {
            return image
        }
        guard let png = disk.load(id: id), let image = Self.decode(png) else { return nil }
        memory.setObject(image, forKey: id as NSString)
        return image
    }

    /// Decodes `png` and caches it under `id`. Returns nil, caching nothing, when the data
    /// is not a usable image.
    func store(png: Data, for id: String) -> UIImage? {
        guard let image = Self.decode(png) else { return nil }
        memory.setObject(image, forKey: id as NSString)
        disk.store(png, id: id)
        return image
    }

    private static func decode(_ png: Data) -> UIImage? {
        UIImage(data: png)?.preparingForDisplay()
    }
}
