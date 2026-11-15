import Foundation

protocol IconDiskCacheDataSourceProtocol {
    func load(id: String) -> Data?
    func store(_ png: Data, id: String)
}

/// Icon PNGs on disk, one file per icon id, bounded by file count. The least recently
/// used files are evicted first. Invalid ids are never turned into paths.
struct IconDiskCacheDataSource: IconDiskCacheDataSourceProtocol {
    private let directory: URL
    private let maxEntries: Int

    init(
        directory: URL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AppIcons", isDirectory: true),
        maxEntries: Int = 256
    ) {
        self.directory = directory
        self.maxEntries = maxEntries
    }

    func load(id: String) -> Data? {
        guard let url = fileURL(for: id), let data = try? Data(contentsOf: url) else { return nil }
        // The modification date doubles as the last-used date for eviction.
        try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: url.path)
        return data
    }

    func store(_ png: Data, id: String) {
        guard let url = fileURL(for: id) else { return }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try png.write(to: url, options: .atomic)
        } catch {
            appLog("Failed to cache icon \(id): \(error)")
            return
        }
        evictIfNeeded()
    }

    private func fileURL(for id: String) -> URL? {
        guard IconId.isValid(id) else { return nil }
        return directory.appendingPathComponent("\(id).png", isDirectory: false)
    }

    private func evictIfNeeded() {
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        ), files.count > maxEntries else { return }

        let byLastUse = files
            .map { url in
                (url, (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast)
            }
            .sorted { $0.1 < $1.1 }
        for (url, _) in byLastUse.prefix(files.count - maxEntries) {
            try? fileManager.removeItem(at: url)
        }
    }
}
