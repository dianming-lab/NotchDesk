import Foundation

/// All imports copy; neither the source nor an existing destination is overwritten.
enum FileStore {
    static func copy(_ source: URL, to directory: URL) throws -> URL {
        let fm = FileManager.default
        let source = source.standardizedFileURL
        if source.deletingLastPathComponent().resolvingSymlinksInPath() == directory.resolvingSymlinksInPath() {
            return source
        }
        let resolvedSource = source.resolvingSymlinksInPath().path
        let resolvedDirectory = directory.resolvingSymlinksInPath().path
        if resolvedDirectory == resolvedSource || resolvedDirectory.hasPrefix(resolvedSource + "/") {
            throw NSError(domain: "NotchDesk", code: 1, userInfo: [NSLocalizedDescriptionKey: "不能把文件夹复制到它自己里面。"])
        }
        let ext = source.pathExtension
        let stem = ext.isEmpty ? source.lastPathComponent : source.deletingPathExtension().lastPathComponent
        for number in 0..<10000 {
            let name = number == 0 ? source.lastPathComponent : "\(stem) (\(number))" + (ext.isEmpty ? "" : ".\(ext)")
            let destination = directory.appendingPathComponent(name)
            if fm.fileExists(atPath: destination.path) { continue }
            do {
                try fm.copyItem(at: source, to: destination)
                return destination
            } catch let error as NSError {
                // Another process may have created this name after the existence check.
                if error.domain == NSCocoaErrorDomain && error.code == NSFileWriteFileExistsError { continue }
                throw error
            }
        }
        throw NSError(domain: "NotchDesk", code: 2, userInfo: [NSLocalizedDescriptionKey: "同名文件过多，无法保存。"])
    }
}
