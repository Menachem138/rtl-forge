import Foundation

// Static adapter metadata — decoded straight from manager/adapters/*.json. Unknown keys
// (sourcePath, teamId on some, etc.) are ignored by the synthesized Decodable.
enum AdapterStatus: String, Decodable {
    case supported   // proven runtime injection (Claude)
    case candidate   // a safe route exists but isn't shipped here (Hermes source patch)
    case research    // no safe public route yet (Codex)
}

struct Adapter: Decodable, Identifiable {
    let id: String
    let name: String
    let platform: String
    let bundleId: String
    let defaultPath: String
    let status: AdapterStatus
    let safeRoute: String
    let apply: String?          // "official-debugger" | "electron-cdp" | "electron-cdp-experimental" | nil
    let teamId: String?
    let notes: [String]?

    var canApply: Bool { apply != nil }
    var isExperimental: Bool { apply == "electron-cdp-experimental" }
    var hasWatchdog: Bool { apply == "official-debugger" }
    var relaunchesApp: Bool { apply == "electron-cdp" || apply == "electron-cdp-experimental" }
}

// Live, per-refresh state — parsed from adapter-control.sh `key=value` output.
struct AdapterLive {
    var installed = false
    var version = "—"
    var teamId = "—"
    var teamOk: Bool? = nil
    var running = false
    var rtl: RtlState = .unknown
    var lastSuccessAt: String? = nil
    var watch: WatchState = .unknown
}

// Honest RTL states — see cmd_verify in adapter-control.sh.
enum RtlState: String {
    case active       // Claude running == the exact instance we injected into
    case stale        // Claude running but restarted/updated since — reapply needed
    case inactive     // Claude running, never injected this session
    case notRunning   // Claude not running
    case unsupported  // non-Claude adapter (no runtime injection route)
    case unknown
}

enum WatchState: String {
    case on           // LaunchAgent installed AND loaded
    case off          // not installed
    case installed    // plist present but not currently loaded
    case unsupported  // non-Claude adapter
    case unknown
}
