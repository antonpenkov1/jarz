import XCTest
@testable import Jarz

final class SnapshotStoreTests: XCTestCase {
    private var directory: URL!

    override func setUp() {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SnapshotStoreTests-\(UUID().uuidString)")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
    }

    func testRoundTripKeepsBackupBytesAndMetadata() {
        let store = SnapshotStore(directory: directory)
        let backup = Data(#"{"categories":[{"name":"Food"}]}"#.utf8)
        let saved = store.save(backup: backup, kind: .deleteJar, detail: "Food")

        let listed = store.list()
        XCTAssertEqual(listed.count, 1)
        XCTAssertEqual(listed.first?.kind, .deleteJar)
        XCTAssertEqual(listed.first?.detail, "Food")
        XCTAssertEqual(store.backup(id: saved!.id), backup)
    }

    func testNewestFirstAndOnlyLastFiveKept() {
        let store = SnapshotStore(directory: directory)
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        for index in 0..<7 {
            store.save(backup: Data("\(index)".utf8), kind: .importData,
                       detail: "\(index)", date: base.addingTimeInterval(Double(index) * 60))
        }
        let listed = store.list()
        XCTAssertEqual(listed.count, 5)
        XCTAssertEqual(listed.map(\.detail), ["6", "5", "4", "3", "2"])
    }

    func testMissingSnapshotReturnsNil() {
        XCTAssertNil(SnapshotStore(directory: directory).backup(id: "nope"))
        XCTAssertTrue(SnapshotStore(directory: directory).list().isEmpty)
    }
}
