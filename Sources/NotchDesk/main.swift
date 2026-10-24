import AppKit

final class FileListView: NSView {
    override var isFlipped: Bool { true }
}

final class ShelfPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class FileRow: NSView, NSDraggingSource {
    let url: URL
    weak var owner: ShelfController?
    private var down: NSEvent?
    private var hovered = false
    private var hoverArea: NSTrackingArea?
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverArea { removeTrackingArea(hoverArea) }
        let area = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
        addTrackingArea(area)
        hoverArea = area
    }
    override func mouseEntered(with event: NSEvent) { hovered = true; needsDisplay = true }
    override func mouseExited(with event: NSEvent) { hovered = false; needsDisplay = true }
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        if hovered {
            NSColor.labelColor.withAlphaComponent(0.065).setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: 10, yRadius: 10).fill()
        }
    }
    init(url: URL, owner: ShelfController, width: CGFloat) {
        self.url = url
        self.owner = owner
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: 52))
        let icon = NSImageView(frame: NSRect(x: 10, y: 10, width: 32, height: 32))
        icon.image = NSWorkspace.shared.icon(forFile: url.path)
        addSubview(icon)
        let label = NSTextField(labelWithString: url.lastPathComponent)
        label.frame = NSRect(x: 54, y: 23, width: width - 68, height: 19)
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.lineBreakMode = .byTruncatingMiddle
        addSubview(label)
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
        let detail = NSTextField(labelWithString: values?.isDirectory == true ? "文件夹" : "\(ByteCountFormatter.string(fromByteCount: Int64(values?.fileSize ?? 0), countStyle: .file))")
        detail.frame = NSRect(x: 54, y: 6, width: width - 68, height: 16)
        detail.font = .systemFont(ofSize: 11)
        detail.textColor = .secondaryLabelColor
        addSubview(detail)
        toolTip = url.path
    }
    required init?(coder: NSCoder) { fatalError() }
    override func hitTest(_ point: NSPoint) -> NSView? { bounds.contains(convert(point, from: superview)) ? self : nil }
    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 { NSWorkspace.shared.open(url); return }
        down = event
    }
    override func mouseDragged(with event: NSEvent) {
        guard let start = down, hypot(event.locationInWindow.x - start.locationInWindow.x, event.locationInWindow.y - start.locationInWindow.y) > 4 else { return }
        down = nil
        owner?.exporting = true
        let item = NSDraggingItem(pasteboardWriter: url as NSURL)
        let p = convert(event.locationInWindow, from: nil)
        item.setDraggingFrame(NSRect(x: p.x - 16, y: p.y - 16, width: 32, height: 32), contents: NSWorkspace.shared.icon(forFile: url.path))
        beginDraggingSession(with: [item], event: event, source: self)
    }
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation { .copy }
    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) { owner?.exporting = false }
    override func rightMouseDown(with event: NSEvent) {
        let menu = NSMenu()
        let item = menu.addItem(withTitle: "在 Finder 中显示", action: #selector(reveal), keyEquivalent: "")
        item.target = self
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }
    @objc private func reveal() { NSWorkspace.shared.activateFileViewerSelecting([url]) }
}

final class DropView: NSVisualEffectView {
    weak var owner: ShelfController?
    private var dropHighlighted = false
    private func updateRim() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.borderWidth = dropHighlighted ? 2 : 0.5
            layer?.borderColor = dropHighlighted
                ? NSColor.controlAccentColor.cgColor
                : NSColor.labelColor.withAlphaComponent(0.16).cgColor
        }
    }
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateRim()
    }
    override init(frame: NSRect) {
        super.init(frame: frame)
        material = .sidebar
        blendingMode = .behindWindow
        state = .active
        wantsLayer = true
        layer?.cornerRadius = 22
        layer?.masksToBounds = true
        // Mask the material itself, not only its backing layer. The window
        // compositor also uses this alpha mask to shape the window shadow.
        let mask = NSImage(size: NSSize(width: 46, height: 46), flipped: false) { rect in
            NSColor.white.setFill()
            NSBezierPath(roundedRect: rect, xRadius: 22, yRadius: 22).fill()
            return true
        }
        mask.capInsets = NSEdgeInsets(top: 22, left: 22, bottom: 22, right: 22)
        mask.resizingMode = .stretch
        maskImage = mask
        updateRim()
        registerForDraggedTypes([.fileURL] + NSFilePromiseReceiver.readableDraggedTypes.map { NSPasteboard.PasteboardType($0) })
    }
    required init?(coder: NSCoder) { fatalError() }
    private func accepts(_ info: NSDraggingInfo) -> Bool {
        info.draggingPasteboard.canReadObject(forClasses: [NSURL.self, NSFilePromiseReceiver.self], options: [.urlReadingFileURLsOnly: true])
    }
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard accepts(sender), sender.draggingSourceOperationMask.contains(.copy) else { return [] }
        owner?.receiving = true
        owner?.expand()
        dropHighlighted = true
        updateRim()
        owner?.message.stringValue = "松手即可存到桌面"
        return .copy
    }
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation { accepts(sender) && sender.draggingSourceOperationMask.contains(.copy) ? .copy : [] }
    override func draggingExited(_ sender: NSDraggingInfo?) { reset() }
    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool { accepts(sender) }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        defer { reset() }
        guard let owner else { return false }
        let board = sender.draggingPasteboard
        if let promises = board.readObjects(forClasses: [NSFilePromiseReceiver.self], options: nil) as? [NSFilePromiseReceiver], !promises.isEmpty {
            owner.receive(promises)
            return true
        }
        let urls = (board.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]) ?? []
        guard !urls.isEmpty else { return false }
        owner.importFiles(urls)
        return true
    }
    override func concludeDragOperation(_ sender: NSDraggingInfo?) { reset() }
    private func reset() { owner?.receiving = false; dropHighlighted = false; updateRim() }
}

final class ShelfController: NSObject {
    let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]
    let panel = ShelfPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    let root = DropView(frame: .zero)
    let content = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 350))
    let message = NSTextField(labelWithString: "拖入存到桌面 · 拖出到其他应用")
    let count = NSTextField(labelWithString: "")
    let scroll = NSScrollView(frame: NSRect(x: 14, y: 49, width: 392, height: 230))
    var screen: NSScreen?
    var expanded = false
    var exporting = false
    var receiving = false
    var busy = 0
    var outsideSince: Date?
    var timer: Timer?
    var hoverActivity: NSObjectProtocol?
    var refreshInFlight = false
    let scanQueue = DispatchQueue(label: "NotchDesk.scan", qos: .utility)
    var watcher: DispatchSourceFileSystemObject?
    var rowsSignature = ""
    let fileQueue = DispatchQueue(label: "NotchDesk.files", qos: .userInitiated)
    let promiseQueue: OperationQueue = { let q = OperationQueue(); q.maxConcurrentOperationCount = 1; return q }()
    var lastRefresh = Date.distantPast
    var errorText: String?

    override init() {
        super.init()
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.animationBehavior = .none
        // Inherit system light/dark appearance, including accessibility settings.
        panel.appearance = nil
        panel.acceptsMouseMovedEvents = true
        root.owner = self
        panel.contentView = root
        root.addSubview(content)
        let desktopIcon = NSImageView(frame: NSRect(x: 23, y: 299, width: 26, height: 28))
        desktopIcon.image = NSImage(systemSymbolName: "desktopcomputer", accessibilityDescription: "桌面")
        desktopIcon.contentTintColor = .secondaryLabelColor
        content.addSubview(desktopIcon)
        let title = NSTextField(labelWithString: "桌面")
        title.font = .systemFont(ofSize: 17, weight: .semibold)
        title.frame = NSRect(x: 61, y: 311, width: 240, height: 23)
        content.addSubview(title)
        count.frame = NSRect(x: 61, y: 293, width: 290, height: 16)
        count.font = .systemFont(ofSize: 11)
        count.textColor = .secondaryLabelColor
        content.addSubview(count)
        for y: CGFloat in [283, 47] {
            let separator = NSBox(frame: NSRect(x: 22, y: y, width: 376, height: 1))
            separator.boxType = .separator
            content.addSubview(separator)
        }
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.autohidesScrollers = true
        content.addSubview(scroll)
        message.frame = NSRect(x: 22, y: 18, width: 278, height: 18)
        message.font = .systemFont(ofSize: 11)
        message.textColor = .secondaryLabelColor
        message.lineBreakMode = .byTruncatingTail
        content.addSubview(message)
        let button = NSButton(title: "打开", target: self, action: #selector(openDesktop))
        button.bezelStyle = .rounded
        button.controlSize = .small
        button.font = .systemFont(ofSize: 11, weight: .medium)
        button.image = NSImage(systemSymbolName: "arrow.up.forward", accessibilityDescription: nil)
        button.imagePosition = .imageTrailing
        button.toolTip = "在 Finder 中打开桌面"
        button.frame = NSRect(x: 320, y: 13, width: 78, height: 28)
        content.addSubview(button)
        NotificationCenter.default.addObserver(self, selector: #selector(reposition), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        reposition()
        refresh()
        startWatcher()
        // A hidden menu-bar utility must remain responsive to its hover timer.
        hoverActivity = ProcessInfo.processInfo.beginActivity(options: .userInitiatedAllowingIdleSystemSleep, reason: "Respond immediately when the pointer reaches the notch")
        timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(timer!, forMode: .common)
    }
    @objc func openDesktop() { NSWorkspace.shared.open(desktop) }
    @objc func reposition() {
        screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.screens.first
        layout()
    }
    private var notchWidth: CGFloat {
        guard let screen, let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea else { return 180 }
        return max(120, right.minX - left.maxX)
    }
    private var top: CGFloat {
        guard let screen else { return 0 }
        return screen.frame.maxY - max(screen.safeAreaInsets.top, 25)
    }
    private func layout() {
        guard let screen else { return }
        // Keep polling the notch hot zone while collapsed, without rendering
        // a strip or intercepting clicks in the foreground application.
        guard expanded else {
            panel.orderOut(nil)
            return
        }
        let size = NSSize(width: 420, height: 350)
        panel.setFrame(NSRect(x: screen.frame.midX - size.width / 2, y: top - size.height, width: size.width, height: size.height), display: true)
        root.frame = NSRect(origin: .zero, size: size)
        content.isHidden = false
        root.layer?.cornerRadius = 22
        panel.orderFrontRegardless()
    }
    func expand() {
        outsideSince = nil
        guard !expanded else { return }
        expanded = true
        layout()
        refresh()
    }
    @objc func showShelf() { expand(); outsideSince = Date().addingTimeInterval(2) }
    private func tick() {
        guard let screen else { return }
        let point = NSEvent.mouseLocation
        let hotZone = NSRect(x: screen.frame.midX - (notchWidth + 70) / 2, y: top - 12, width: notchWidth + 70, height: screen.frame.maxY - top + 12)
        if hotZone.contains(point) { expand() }
        else if expanded && !panel.frame.insetBy(dx: -12, dy: -12).contains(point) && !exporting && !receiving && busy == 0 {
            if outsideSince == nil { outsideSince = Date() }
            if let since = outsideSince, Date().timeIntervalSince(since) > 0.15 { expanded = false; layout() }
        } else { outsideSince = nil }
        if expanded && !exporting && Date().timeIntervalSince(lastRefresh) > 2 { refresh() }
    }
    private func startWatcher() {
        let fd = open(desktop.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write, .rename, .delete, .attrib], queue: .main)
        source.setEventHandler { [weak self] in
            guard let self, !self.exporting else { return }
            self.refresh()
        }
        source.setCancelHandler { close(fd) }
        source.resume()
        watcher = source
    }
    func refresh() {
        guard !refreshInFlight else { return }
        refreshInFlight = true
        lastRefresh = Date()
        scanQueue.async { [self] in
            let result: Result<[(URL, String)], Error> = Result {
                let files = try FileManager.default.contentsOfDirectory(at: desktop, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey], options: [.skipsHiddenFiles]).sorted {
                    $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
                }
                return files.map { url in
                    let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
                    return (url, "\(url.path)|\(values?.contentModificationDate?.timeIntervalSince1970 ?? 0)|\(values?.fileSize ?? 0)")
                }
            }
            DispatchQueue.main.async {
                self.refreshInFlight = false
                // Keep the source views alive until an outgoing drag finishes.
                guard !self.exporting else { return }
                self.render(result)
            }
        }
    }
    private func render(_ result: Result<[(URL, String)], Error>) {
        do {
            let entries = try result.get()
            let files = entries.map { $0.0 }
            errorText = nil
            let signature = entries.map { $0.1 }.joined(separator: "\n")
            count.stringValue = "\(files.count) 个项目 · 与桌面同步"
            guard signature != rowsSignature || scroll.documentView == nil else { return }
            rowsSignature = signature
            let y = scroll.contentView.bounds.origin.y
            let document = FileListView(frame: NSRect(x: 0, y: 0, width: 374, height: max(236, CGFloat(files.count) * 54)))
            for (index, url) in files.enumerated() {
                let row = FileRow(url: url, owner: self, width: 374)
                row.frame.origin.y = CGFloat(index) * 54
                document.addSubview(row)
            }
            if files.isEmpty { addEmpty("桌面还是空的\n把文件拖到这里，就能存到桌面", to: document) }
            scroll.documentView = document
            scroll.contentView.scroll(to: NSPoint(x: 0, y: min(y, max(0, document.frame.height - scroll.contentSize.height))))
            scroll.reflectScrolledClipView(scroll.contentView)
        } catch {
            count.stringValue = "需要授权"
            rowsSignature = ""
            errorText = error.localizedDescription
            let document = FileListView(frame: NSRect(x: 0, y: 0, width: 374, height: 236))
            addEmpty("无法读取桌面\n请在系统设置 → 隐私与安全性 → 文件与文件夹\n允许 NotchDesk 访问桌面，然后重新打开应用。", to: document)
            scroll.documentView = document
        }
    }
    private func addEmpty(_ text: String, to view: NSView) {
        let label = NSTextField(wrappingLabelWithString: text)
        label.frame = NSRect(x: 10, y: 75, width: 354, height: 100)
        label.alignment = .center
        label.textColor = .secondaryLabelColor
        label.font = .systemFont(ofSize: 13)
        view.addSubview(label)
    }
    func importFiles(_ urls: [URL]) {
        busy += 1
        message.stringValue = "正在复制到桌面…"
        fileQueue.async { [self] in
            var failures: [String] = []
            for url in urls {
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                do { _ = try FileStore.copy(url, to: desktop) }
                catch { failures.append("\(url.lastPathComponent)：\(error.localizedDescription)") }
            }
            let errors = failures
            DispatchQueue.main.async { self.finish(errors: errors, total: urls.count) }
        }
    }
    func receive(_ promises: [NSFilePromiseReceiver]) {
        for promise in promises {
            // Each promised file is staged separately from Desktop, then imported with collision protection.
            let staging = FileManager.default.temporaryDirectory.appendingPathComponent("NotchDesk-\(UUID().uuidString)", isDirectory: true)
            do { try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true) }
            catch { showError(error.localizedDescription); continue }
            busy += 1
            message.stringValue = "正在接收文件…"
            var remaining = max(1, promise.fileNames.count)
            var failures: [String] = []
            let total = remaining
            promise.receivePromisedFiles(atDestination: staging, options: [:], operationQueue: promiseQueue) { [self] url, error in
                do {
                    if let error { throw error }
                    _ = try FileStore.copy(url, to: desktop)
                } catch { failures.append(error.localizedDescription) }
                remaining -= 1
                if remaining == 0 {
                    try? FileManager.default.removeItem(at: staging)
                    let errors = failures
                    DispatchQueue.main.async { self.finish(errors: errors, total: total) }
                }
            }
        }
    }
    private func finish(errors: [String], total: Int) {
        busy = max(0, busy - 1)
        refresh()
        message.stringValue = errors.isEmpty ? "已存到桌面 · \(total) 个项目" : "\(errors.count) 个项目保存失败"
        if !errors.isEmpty { showError(errors.joined(separator: "\n")) }
    }
    private func showError(_ text: String) {
        let alert = NSAlert()
        alert.messageText = "部分文件未能保存"
        alert.informativeText = text
        alert.addButton(withTitle: "好")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var shelf: ShelfController!
    var status: NSStatusItem!
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        shelf = ShelfController()
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        status.button?.image = NSImage(systemSymbolName: "tray.full", accessibilityDescription: "NotchDesk 桌面文件")
        let menu = NSMenu()
        let show = menu.addItem(withTitle: "展开桌面文件", action: #selector(ShelfController.showShelf), keyEquivalent: "")
        show.target = shelf
        let open = menu.addItem(withTitle: "在 Finder 中打开桌面", action: #selector(ShelfController.openDesktop), keyEquivalent: "")
        open.target = shelf
        menu.addItem(.separator())
        let quit = menu.addItem(withTitle: "退出 NotchDesk", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        status.menu = menu
        if !UserDefaults.standard.bool(forKey: "didWelcome") {
            shelf.showShelf()
            UserDefaults.standard.set(true, forKey: "didWelcome")
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
