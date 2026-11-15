import Foundation

protocol IconDiskCacheDataSourceProtocol {
    func load(id: String, size: Int) -> Data?
    func store(_ png: Data, id: String, size: Int)
}

/// Icon PNGs on disk, one file per icon id and requested pixel size, bounded by file
/// count. When the bound is exceeded the least recently used files are evicted down to
/// three quarters of it. Invalid ids are never turned into paths. Not thread-safe: use
/// from one isolation domain.
final class IconDiskCacheDataSource: IconDiskCacheDataSourceProtocol {
    private let directory: URL
    private let maxEntries: Int
    // Counted from the directory on first store, then maintained; eviction recounts.
    private var entryCount: Int?

    init(
        directory: URL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AppIcons", isDirectory: true),
        maxEntries: Int = 256
    ) {
        self.directory = directory
        self.maxEntries = maxEntries
    }

    func load(id: String, size: Int) -> Data? {
        guard let url = fileURL(for: id, size: size), let data = try? Data(contentsOf: url) else { return nil }
        // The modification date doubles as the last-used date for eviction.
        try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: url.path)
        return data
    }

    func store(_ png: Data, id: String, size: Int) {
        guard let url = fileURL(for: id, size: size) else { return }
        let isNewFile = !FileManager.default.fileExists(atPath: url.path)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try png.write(to: url, options: .atomic)
        } catch {
            appLog("Failed to cache icon \(id): \(error)")
            return
        }
        let count = entryCount.map { $0 + (isNewFile ? 1 : 0) } ?? cachedFiles().count
        entryCount = count
        if count > maxEntries {
            evict()
        }
    }

    private func fileURL(for id: String, size: Int) -> URL? {
        guard IconId.isValid(id) else { return nil }
        return directory.appendingPathComponent("\(id)_\(size).png", isDirectory: false)
    }

    private func cachedFiles() -> [URL] {
        (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        )) ?? []
    }

    private func evict() {
        let files = cachedFiles()
        let keep = maxEntries * 3 / 4
        let byLastUse = files
            .map { url in
                (url, (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast)
            }
            .sorted { $0.1 < $1.1 }
        var removed = 0
        for (url, _) in byLastUse.prefix(max(files.count - keep, 0)) {
            if (try? FileManager.default.removeItem(at: url)) != nil {
                removed += 1
            }
        }
        entryCount = files.count - removed
    }
}
