import Foundation
import AppKit
import ApplicationServices

// One source of truth = the bash scripts. This wraps `manager/core/adapter-control.sh` via
// Process and parses its `key=value` output. Static metadata is read from the adapter JSON.
@MainActor
final class Manager: ObservableObject {
    @Published var adapters: [Adapter] = []
    @Published var live: [String: AdapterLive] = [:]
    @Published var busy = false
    @Published var axTrusted = false
    @Published var loadError: String?

    // Experimental read-only scan of other Electron apps (off by default).
    @Published var scanExpanded = false
    @Published var scanOutput = ""

    let managerVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "dev"

    // The repo root that holds manager/ + official-runtime/ + dist/payload.js. When bundled, this
    // is the app's Resources dir (build.sh copies the runtime there); in dev it's the checkout.
    private lazy var repo: URL? = Self.resolveRepo()
    private var control: String? { repo.map { $0.appendingPathComponent("manager/core/adapter-control.sh").path } }
    private var scanScript: String? { repo.map { $0.appendingPathComponent("manager/core/app-status.sh").path } }
    var docsURL: URL? { repo?.appendingPathComponent("docs/APP_ADAPTERS.md") }

    private static func resolveRepo() -> URL? {
        let marker = "manager/core/adapter-control.sh"
        let fm = FileManager.default
        // 1) explicit override
        if let p = ProcessInfo.processInfo.environment["RTL_MANAGER_REPO"] {
            let u = URL(fileURLWithPath: p)
            if fm.fileExists(atPath: u.appendingPathComponent(marker).path) { return u }
        }
        // 2) bundled Resources (self-contained .app)
        if let r = Bundle.main.resourceURL,
           fm.fileExists(atPath: r.appendingPathComponent(marker).path) { return r }
        // 3) walk up from the executable (dev: swift run / .build/**/RTLManager)
        var dir = URL(fileURLWithPath: Bundle.main.executablePath ?? CommandLine.arguments[0])
            .deletingLastPathComponent()
        for _ in 0..<8 {
            if fm.fileExists(atPath: dir.appendingPathComponent(marker).path) { return dir }
            dir = dir.deletingLastPathComponent()
        }
        return nil
    }

    // GUI/launchd processes start with a bare PATH — give bash the usual tools.
    private var env: [String: String] {
        var e = ProcessInfo.processInfo.environment
        e["PATH"] = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        return e
    }

    func refresh() async {
        axTrusted = AXIsProcessTrusted()

        guard let control else {
            loadError = "Could not locate the RTL repo (manager/core/adapter-control.sh). "
                + "Set RTL_MANAGER_REPO to your checkout."
            return
        }
        loadError = nil

        if adapters.isEmpty { adapters = loadAdapters() }

        for a in adapters {
            var l = AdapterLive()
            parse(await capture("/bin/bash", [control, "status", a.id]), into: &l)
            parse(await capture("/bin/bash", [control, "verify", a.id]), into: &l)
            parse(await capture("/bin/bash", [control, "watch-status", a.id]), into: &l)
            live[a.id] = l
        }
    }

    private func loadAdapters() -> [Adapter] {
        guard let repo else { return [] }
        let dir = repo.appendingPathComponent("manager/adapters")
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        let decoded: [Adapter] = files
            .filter { $0.pathExtension == "json" }
            .compactMap { url in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? JSONDecoder().decode(Adapter.self, from: data)
            }
        // Stable order: supported first, then candidate, then research; by name within a tier.
        let rank: [AdapterStatus: Int] = [.supported: 0, .candidate: 1, .research: 2]
        return decoded.sorted { (rank[$0.status] ?? 9, $0.name) < (rank[$1.status] ?? 9, $1.name) }
    }

    private func parse(_ out: String, into l: inout AdapterLive) {
        for line in out.split(separator: "\n") {
            guard let eq = line.firstIndex(of: "=") else { continue }
            let key = String(line[..<eq])
            let val = String(line[line.index(after: eq)...])
            switch key {
            case "installed":     l.installed = (val == "yes")
            case "version":       l.version = val
            case "teamId":        l.teamId = val
            case "teamOk":        l.teamOk = (val == "yes")
            case "running":       l.running = (val == "yes")
            case "rtl":           l.rtl = RtlState(rawValue: val) ?? .unknown
            case "lastSuccessAt": l.lastSuccessAt = val
            case "watch":         l.watch = WatchState(rawValue: val) ?? .unknown
            default: break
            }
        }
    }

    // MARK: - Actions (mutating verbs only ever hit the Claude adapter)
    func reapply(_ id: String) async {
        guard let control else { return }
        busy = true
        _ = await capture("/bin/bash", [control, "reapply", id])
        await refresh()
        busy = false
    }

    func setWatch(_ id: String, _ on: Bool) async {
        guard let control else { return }
        busy = true
        _ = await capture("/bin/bash", [control, "watch", id, on ? "on" : "off"])
        await refresh()
        busy = false
    }

    func openLogs(_ id: String) {
        guard let control else { return }
        Task {
            let out = await capture("/bin/bash", [control, "logs-path", id])
            let path = out.split(separator: "\n")
                .first { $0.hasPrefix("logs=") }
                .map { String($0.dropFirst("logs=".count)) } ?? ""
            let url = URL(fileURLWithPath: path)
            if FileManager.default.fileExists(atPath: path) {
                NSWorkspace.shared.open(url)
            } else {
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
            }
        }
    }

    func promptAccessibility() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        axTrusted = AXIsProcessTrustedWithOptions(opts)
        NSWorkspace.shared.open(URL(string:
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    func runScan() async {
        guard let scanScript else { return }
        scanOutput = "Scanning…"
        scanOutput = await capture("/bin/bash", [scanScript])
    }

    // MARK: - exec
    private func capture(_ tool: String, _ args: [String]) async -> String {
        let environment = env
        return await withCheckedContinuation { cont in
            DispatchQueue.global().async {
                let p = Process()
                p.executableURL = URL(fileURLWithPath: tool)
                p.arguments = args
                p.environment = environment
                let pipe = Pipe()
                p.standardOutput = pipe
                p.standardError = pipe
                do { try p.run() } catch { cont.resume(returning: "launch failed: \(error)\n"); return }
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                p.waitUntilExit()
                cont.resume(returning: String(data: data, encoding: .utf8) ?? "")
            }
        }
    }
}
