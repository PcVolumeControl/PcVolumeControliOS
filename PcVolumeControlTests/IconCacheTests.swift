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
        disk.store(data, id: "abc123", size: 66)
        XCTAssertEqual(disk.load(id: "abc123", size: 66), data)
        XCTAssertEqual(cachedFileNames(), ["abc123_66.png"])
    }

    func testLoadOfUnknownIdOrSizeIsNil() {
        let disk = IconDiskCacheDataSource(directory: directory)
        XCTAssertNil(disk.load(id: "abc123", size: 66))
        disk.store(Data([1]), id: "abc123", size: 66)
        XCTAssertNil(disk.load(id: "abc123", size: 132))
    }

    func testInvalidIdsAreNeverUsedAsPaths() {
        let disk = IconDiskCacheDataSource(directory: directory)
        for id in ["../escape", "a/b", "ABC", "", ".hidden", String(repeating: "a", count: 65)] {
            disk.store(Data([1]), id: id, size: 66)
            XCTAssertNil(disk.load(id: id, size: 66), id)
        }
        XCTAssertEqual(cachedFileNames(), [])
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: directory.deletingLastPathComponent().appendingPathComponent("escape_66.png").path
        ))
    }

    func testCacheIsBoundedByEntryCount() throws {
        let disk = IconDiskCacheDataSource(directory: directory, maxEntries: 4)
        for index in 0..<4 {
            disk.store(Data([UInt8(index)]), id: "old\(index)", size: 66)
        }
        // Make the existing files clearly older than anything stored next, oldest first.
        for (offset, name) in cachedFileNames().enumerated() {
            try FileManager.default.setAttributes(
                [.modificationDate: Date(timeIntervalSinceNow: Double(offset - 10) * 60)],
                ofItemAtPath: directory.appendingPathComponent(name).path
            )
        }
        // Loading refreshes "old0", so "old1" and "old2" are now the least recently used.
        XCTAssertNotNil(disk.load(id: "old0", size: 66))

        // Exceeding 4 entries evicts down to 3 (three quarters).
        disk.store(Data([9]), id: "new0", size: 66)
        XCTAssertEqual(cachedFileNames(), ["new0_66.png", "old0_66.png", "old3_66.png"])

        disk.store(Data([9]), id: "new1", size: 66)
        XCTAssertEqual(cachedFileNames(), ["new0_66.png", "new1_66.png", "old0_66.png", "old3_66.png"])
    }

    func testRewritingAnEntryDoesNotCountTwice() {
        let disk = IconDiskCacheDataSource(directory: directory, maxEntries: 2)
        disk.store(Data([1]), id: "a", size: 66)
        disk.store(Data([2]), id: "b", size: 66)
        disk.store(Data([3]), id: "b", size: 66)
        XCTAssertEqual(cachedFileNames(), ["a_66.png", "b_66.png"])
    }

    // MARK: - Repository

    func testRepositoryStoresDecodedIconsAndReadsThemBack() async throws {
        let png = try samplePNG()
        let id = "6b58026ae167f8f2e802f2531657443c"
        let repo = IconRepository(disk: IconDiskCacheDataSource(directory: directory))

        let before = await repo.cachedIcons(for: [id], size: 16)
        XCTAssertTrue(before.isEmpty)
        let stored = await repo.store(png: png, for: id, size: 16)
        XCTAssertNotNil(stored)
        XCTAssertEqual(cachedFileNames(), ["\(id)_16.png"])

        // A fresh repository (empty memory cache) finds it on disk, at that size only.
        let reloaded = IconRepository(disk: IconDiskCacheDataSource(directory: directory))
        let found = await reloaded.cachedIcons(for: [id, "other"], size: 16)
        XCTAssertEqual(Array(found.keys), [id])
        XCTAssertEqual(found[id].map { $0.size.width * $0.scale }, 16)
        let otherSize = await reloaded.cachedIcons(for: [id], size: 32)
        XCTAssertTrue(otherSize.isEmpty)
    }

    func testRepositoryRejectsDataThatIsNotAnImage() async {
        let repo = IconRepository(disk: IconDiskCacheDataSource(directory: directory))
        let stored = await repo.store(png: Data("not a png".utf8), for: "abc", size: 16)
        XCTAssertNil(stored)
        XCTAssertEqual(cachedFileNames(), [])
    }
}
