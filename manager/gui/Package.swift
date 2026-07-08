// swift-tools-version: 5.9
import PackageDescription

// Multi-app RTL adapter manager: a menu-bar SwiftUI app that wraps the read-only
// `manager/core/adapter-control.sh` surface and the official-runtime scripts. Builds with the
// Command Line Tools — no full Xcode needed: `swift build -c release`, then `manager/gui/build.sh`
// assembles "RTL Manager.app" (LSUIElement menu-bar agent). Ad-hoc signed — no Apple Developer
// Program needed. See docs/APP_ADAPTERS.md "Menu-Bar Control Panel".
let package = Package(
    name: "RTLManager",
    platforms: [.macOS(.v13)], // MenuBarExtra
    targets: [
        .executableTarget(name: "RTLManager", path: "Sources/RTLManager")
    ]
)
