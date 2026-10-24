import Foundation

@main struct Verify {
    static func main() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("NotchDesk-test-\(UUID().uuidString)")
        let desktop = root.appendingPathComponent("Desktop")
        try fm.createDirectory(at: desktop, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }
        func check(_ condition: Bool, _ message: String) throws {
            guard condition else { throw NSError(domain: "Verify", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
            print("PASS: \(message)")
        }
        let source = root.appendingPathComponent("报告.txt")
        let existing = desktop.appendingPathComponent("报告.txt")
        try Data("new".utf8).write(to: source)
        try Data("old".utf8).write(to: existing)
        let copy = try FileStore.copy(source, to: desktop)
        try check(copy.lastPathComponent == "报告 (1).txt", "重名自动编号")
        try check(try String(contentsOf: existing) == "old", "目标原件不覆盖")
        try check(try String(contentsOf: source) == "new", "来源原件不移动")
        try check(try String(contentsOf: copy) == "new", "复制内容一致")
        let again = try FileStore.copy(existing, to: desktop)
        try check(again == existing && fm.contentsOfDirectory(atPath: desktop.path).count == 2, "桌面内拖入不重复")
        let folder = root.appendingPathComponent("Folder")
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("nested".utf8).write(to: folder.appendingPathComponent("child.txt"))
        let folderCopy = try FileStore.copy(folder, to: desktop)
        try check(try String(contentsOf: folderCopy.appendingPathComponent("child.txt")) == "nested", "复制文件夹内容")
        var rejected = false
        do { _ = try FileStore.copy(root, to: desktop) } catch { rejected = true }
        try check(rejected, "拒绝递归复制")
        rejected = false
        do { _ = try FileStore.copy(root.appendingPathComponent("missing"), to: desktop) } catch { rejected = true }
        try check(rejected, "不存在的来源报告错误")
    }
}
