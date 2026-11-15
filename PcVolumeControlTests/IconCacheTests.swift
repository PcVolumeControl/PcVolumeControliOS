//
//  IconCacheTests.swift
//  PcVolumeControlTests
//
//  The on-disk icon cache and the repository that decodes and caches icons.
//

import XCTest
import UIKit
@testable import PcVolumeControl

final class IconCacheTests: XCTestCase {

    private var directory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("IconCacheTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
        try super.tearDownWithError()
    }

    private func samplePNG() throws -> Data {
        guard case .icon(let reply) = try ServerLine.classify(Data(ServerLineTests.iconImageReply.utf8)) else {
            throw XCTSkip("Sample icon reply did not decode")
        }
        return try XCTUnwrap(reply.png)
    }

    private func cachedFileNames() -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []).sorted()
    }

    // MARK: - Disk cache

    func testStoreThenLoad() {
        let disk = IconDiskCacheDataSource(directory: directory)
        let data = Data([1, 2, 3])
        disk.store(data, id: "abc123")
        XCTAssertEqual(disk.load(id: "abc123"), data)
        XCTAssertEqual(cachedFileNames(), ["abc123.png"])
    }

    func testLoadOfUnknownIdIsNil() {
        let disk = IconDiskCacheDataSource(directory: directory)
        XCTAssertNil(disk.load(id: "abc123"))
    }

    func testInvalidIdsAreNeverUsedAsPaths() {
        let disk = IconDiskCacheDataSource(directory: directory)
        for id in ["../escape", "a/b", "ABC", "", ".hidden", String(repeating: "a", count: 65)] {
            disk.store(Data([1]), id: id)
            XCTAssertNil(disk.load(id: id), id)
        }
        XCTAssertEqual(cachedFileNames(), [])
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: directory.deletingLastPathComponent().appendingPathComponent("escape.png").path
        ))
    }

    func testCacheIsBoundedByEntryCount() throws {
        let disk = IconDiskCacheDataSource(directory: directory, maxEntries: 3)
        for index in 0..<3 {
            disk.store(Data([UInt8(index)]), id: "old\(index)")
        }
        // Make the existing files clearly older than anything stored next.
        for name in cachedFileNames() {
            try FileManager.default.setAttributes(
                [.modificationDate: Date(timeIntervalSinceNow: -3600)],
                ofItemAtPath: directory.appendingPathComponent(name).path
            )
        }
        // Loading refreshes "old2", so "old0" and "old1" are the least recently used.
        XCTAssertNotNil(disk.load(id: "old2"))

        disk.store(Data([9]), id: "new0")
        disk.store(Data([9]), id: "new1")

        XCTAssertEqual(cachedFileNames(), ["new0.png", "new1.png", "old2.png"])
    }

    // MARK: - Repository

    func testRepositoryStoresDecodedIconsAndReadsThemBack() async throws {
        let png = try samplePNG()
        let repo = IconRepository(disk: IconDiskCacheDataSource(directory: directory))

        let isCachedBefore = await repo.cachedIcon(for: "6b58026ae167f8f2e802f2531657443c") != nil
        XCTAssertFalse(isCachedBefore)
        let stored = await repo.store(png: png, for: "6b58026ae167f8f2e802f2531657443c")
        XCTAssertNotNil(stored)
        XCTAssertEqual(cachedFileNames(), ["6b58026ae167f8f2e802f2531657443c.png"])

        // A fresh repository (empty memory cache) finds it on disk.
        let reloaded = IconRepository(disk: IconDiskCacheDataSource(directory: directory))
        let image = await reloaded.cachedIcon(for: "6b58026ae167f8f2e802f2531657443c")
        XCTAssertEqual(image.map { $0.size.width * $0.scale }, 16)
    }

    func testRepositoryRejectsDataThatIsNotAnImage() async {
        let repo = IconRepository(disk: IconDiskCacheDataSource(directory: directory))
        let stored = await repo.store(png: Data("not a png".utf8), for: "abc")
        XCTAssertNil(stored)
        XCTAssertEqual(cachedFileNames(), [])
    }
}
