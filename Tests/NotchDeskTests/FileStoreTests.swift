import XCTest
@testable import NotchDesk

final class FileStoreTests: XCTestCase {
    var root: URL!
    var desktop: URL!
    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        desktop = root.appendingPathComponent("Desktop")
        try FileManager.default.createDirectory(at: desktop, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: root) }
    func testCollisionPreservesBothFilesAndSource() throws {
        let source = root.appendingPathComponent("报告.txt")
        try Data("new".utf8).write(to: source)
        let existing = desktop.appendingPathComponent("报告.txt")
        try Data("old".utf8).write(to: existing)
        let copy = try FileStore.copy(source, to: desktop)
        XCTAssertEqual(copy.lastPathComponent, "报告 (1).txt")
        XCTAssertEqual(try String(contentsOf: existing), "old")
        XCTAssertEqual(try String(contentsOf: copy), "new")
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
    }
    func testAlreadyOnDesktopDoesNotDuplicate() throws {
        let source = desktop.appendingPathComponent("same.txt")
        try Data().write(to: source)
        XCTAssertEqual(try FileStore.copy(source, to: desktop), source)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: desktop.path).count, 1)
    }
    func testFolderCopyAndRecursiveCopyProtection() throws {
        let folder = root.appendingPathComponent("Folder")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("nested".utf8).write(to: folder.appendingPathComponent("file.txt"))
        let copied = try FileStore.copy(folder, to: desktop)
        XCTAssertEqual(try String(contentsOf: copied.appendingPathComponent("file.txt")), "nested")
        XCTAssertThrowsError(try FileStore.copy(root, to: desktop))
    }
    func testMissingSourceReportsFailure() {
        XCTAssertThrowsError(try FileStore.copy(root.appendingPathComponent("missing"), to: desktop))
    }
}
