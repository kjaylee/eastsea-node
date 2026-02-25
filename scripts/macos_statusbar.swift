import Cocoa
import Darwin

@main
final class EastseaStatusBarApp: NSObject, NSApplicationDelegate {
    static func main() {
        let app = NSApplication.shared
        let delegate = EastseaStatusBarApp()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }

    private let dashboardURL = URL(string: "http://127.0.0.1:8545")!
    private let coreName = "eastsea-production"
    private var statusItem: NSStatusItem?
    private var startStopItem: NSMenuItem?
    private var restartItem: NSMenuItem?
    private var coreProcess: Process?
    private let shutdownTimeoutSec = 1.2

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
        startCore()
    }

    func applicationWillTerminate(_ notification: Notification) {
        stopCore()
    }

    private var corePath: String {
        let bundleDir = Bundle.main.executablePath.map { URL(fileURLWithPath: $0).deletingLastPathComponent() }
        if let dir = bundleDir {
            return dir.appendingPathComponent(coreName).path
        }
        return ""
    }

    private var isCoreRunning: Bool {
        if let proc = coreProcess {
            return proc.isRunning
        }
        return false
    }

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = statusItem?.button else {
            return
        }

        if let image = NSImage(systemSymbolName: "server.rack", accessibilityDescription: "Eastsea Node") {
            image.isTemplate = true
            image.size = NSSize(width: 18, height: 18)
            button.image = image
        } else {
            button.title = "⛓"
        }

        let statusMenu = NSMenu(title: "Eastsea Node")

        let openDashboard = NSMenuItem(
            title: "🌐 Dashboard 열기",
            action: #selector(openDashboard(_:)),
            keyEquivalent: ""
        )
        openDashboard.target = self
        statusMenu.addItem(openDashboard)

        let startStop = NSMenuItem(
            title: "🚀 노드 시작",
            action: #selector(toggleNode(_:)),
            keyEquivalent: ""
        )
        startStop.target = self
        statusMenu.addItem(startStop)
        startStopItem = startStop

        let checkUpdate = NSMenuItem(
            title: "🔄 최신 업데이트 확인",
            action: #selector(checkUpdate(_:)),
            keyEquivalent: ""
        )
        checkUpdate.target = self
        statusMenu.addItem(checkUpdate)

        let restart = NSMenuItem(
            title: "♻️ 노드 재시작",
            action: #selector(restartNode(_:)),
            keyEquivalent: ""
        )
        restart.target = self
        statusMenu.addItem(restart)
        restartItem = restart

        statusMenu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: "종료",
            action: #selector(quitApp(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = self
        statusMenu.addItem(quitItem)

        statusItem?.menu = statusMenu
        updateMenu()
    }

    private func updateMenu() {
        let running = isCoreRunning
        let startTitle = running ? "⏹ 노드 중지" : "🚀 노드 시작"
        startStopItem?.title = startTitle
        restartItem?.isEnabled = true
    }

    @objc
    private func openDashboard(_ sender: Any?) {
        NSWorkspace.shared.open(dashboardURL)
    }

    @objc
    private func toggleNode(_ sender: Any?) {
        if isCoreRunning {
            stopCore()
        } else {
            startCore()
        }
        updateMenu()
    }

    @objc
    private func restartNode(_ sender: Any?) {
        stopCore()
        startCore()
        updateMenu()
    }

    @objc
    private func checkUpdate(_ sender: Any?) {
        runOneShot(args: ["--check-update"])
    }

    @objc
    private func quitApp(_ sender: Any?) {
        stopCore()
        NSApplication.shared.terminate(self)
    }

    private func startCore() {
        guard !isCoreRunning else {
            return
        }

        let binary = corePath
        guard !binary.isEmpty, FileManager.default.isExecutableFile(atPath: binary) else {
            NSLog("Eastsea Node core not found: %@", binary)
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: binary)
        process.arguments = []
        process.standardOutput = nil
        process.standardError = nil

        process.terminationHandler = { [weak self] proc in
            DispatchQueue.main.async {
                if self?.coreProcess === proc {
                    self?.coreProcess = nil
                    self?.updateMenu()
                }
            }
        }

        do {
            try process.run()
            coreProcess = process
            updateMenu()
        } catch {
            NSLog("Eastsea Node launch failed: %@", error.localizedDescription)
        }
    }

    private func stopCore() {
        guard let process = coreProcess else { return }
        if process.isRunning {
            process.terminate()
            let end = Date().addingTimeInterval(shutdownTimeoutSec)
            while process.isRunning && Date() < end {
                Thread.sleep(forTimeInterval: 0.05)
            }
            if process.isRunning {
                kill(process.processIdentifier, SIGTERM)
            }
        }
        let forceEnd = Date().addingTimeInterval(0.4)
        while process.isRunning && Date() < forceEnd {
            Thread.sleep(forTimeInterval: 0.05)
        }
        if process.isRunning {
            kill(process.processIdentifier, SIGKILL)
        }
        coreProcess = nil
        updateMenu()
    }

    private func runOneShot(args: [String]) {
        let binary = corePath
        guard !binary.isEmpty, FileManager.default.isExecutableFile(atPath: binary) else {
            NSLog("Eastsea Node core not found: %@", binary)
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: binary)
        process.arguments = args
        process.standardOutput = nil
        process.standardError = nil

        do {
            try process.run()
        } catch {
            NSLog("Eastsea Node one-shot failed: %@", error.localizedDescription)
        }
    }
}
