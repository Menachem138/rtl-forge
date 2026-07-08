import SwiftUI
import AppKit

struct ContentView: View {
    @ObservedObject var runner: Manager

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            VStack(alignment: .leading, spacing: 12) {
                if let err = runner.loadError { errorBanner(err) }
                if !runner.axTrusted { axBanner }
                ForEach(runner.adapters) { adapter in
                    AdapterCard(runner: runner, adapter: adapter)
                }
                scanSection
                footer
            }
            .padding(14)
        }
        .frame(width: 344)
        .fixedSize(horizontal: false, vertical: true)
        .measuredHeight()
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(Color(red: 0.99, green: 0.97, blue: 0.94))
                    .shadow(color: .black.opacity(0.16), radius: 3, y: 1)
                Image(systemName: "text.alignright")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Brand.gradient)
            }
            .frame(width: 46, height: 46)
            VStack(alignment: .leading, spacing: 2) {
                Text("Claude RTL Manager").font(.headline)
                Text("Right-to-left for your desktop apps").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
    }

    private func errorBanner(_ text: String) -> some View {
        Label(text, systemImage: "exclamationmark.triangle.fill")
            .font(.caption).foregroundStyle(.orange)
            .fixedSize(horizontal: false, vertical: true)
            .padding(10).frame(maxWidth: .infinity, alignment: .leading)
            .background(.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    // Reapply and the watchdog both click Claude's Developer menu, which needs Accessibility.
    private var axBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "hand.raised.fill").foregroundStyle(.orange)
                Text("Grant Accessibility so RTL can be applied automatically.")
                    .font(.caption).fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Spacer()
                Button("Open Accessibility…") { runner.promptAccessibility() }
                    .controlSize(.small).buttonStyle(.bordered)
            }
        }
        .padding(10).frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    // MARK: - Experimental scanner
    private var scanSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button { runner.scanExpanded.toggle(); if runner.scanExpanded && runner.scanOutput.isEmpty { Task { await runner.runScan() } } } label: {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.right")
                        .rotationEffect(.degrees(runner.scanExpanded ? 90 : 0)).font(.caption2)
                    Text("Scan installed apps"); Spacer()
                    Text("read-only").font(.caption2).foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle()).foregroundStyle(.secondary)
            }
            .buttonStyle(.plain).font(.caption)

            if runner.scanExpanded {
                ScrollView {
                    Text(runner.scanOutput.isEmpty ? "—" : runner.scanOutput)
                        .font(.system(.caption2, design: .monospaced))
                        .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 120).padding(8)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
                HStack {
                    Button { Task { await runner.runScan() } } label: { Label("Rescan", systemImage: "arrow.clockwise") }
                    Spacer()
                }.controlSize(.small).buttonStyle(.borderless)
            }
        }
    }

    private var footer: some View {
        HStack {
            Text("Manager v\(runner.managerVersion)").font(.caption2).foregroundStyle(.secondary)
            if runner.busy {
                ProgressView().controlSize(.mini)
                Text("Working…").font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            Button { Task { await runner.refresh() } } label: { Label("Refresh", systemImage: "arrow.clockwise") }
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
        .controlSize(.small).buttonStyle(.borderless).padding(.top, 2)
    }
}

// MARK: - One adapter card
private struct AdapterCard: View {
    @ObservedObject var runner: Manager
    let adapter: Adapter

    private var live: AdapterLive { runner.live[adapter.id] ?? AdapterLive() }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(adapter.name).font(.callout.weight(.semibold))
                Spacer()
                statusPill
            }
            if !live.installed {
                Text("Not installed").font(.caption).foregroundStyle(.secondary)
            } else {
                metaRow
                if adapter.canApply { applyControls }
                if adapter.status != .supported { otherNote }
            }
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(.quaternary))
    }

    private var statusPill: some View {
        let (label, color): (String, Color) = {
            switch adapter.status {
            case .supported: return ("Supported", .green)
            case .candidate: return ("Candidate", .orange)
            case .research:  return ("Research", .secondary)
            }
        }()
        return Text(label).font(.caption2.weight(.semibold)).foregroundStyle(color)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color.opacity(0.14), in: Capsule())
    }

    private var metaRow: some View {
        HStack(spacing: 8) {
            Text("v\(live.version)").font(.caption).foregroundStyle(.secondary)
            if let ok = live.teamOk {
                Label(ok ? "signed" : "unexpected signer", systemImage: ok ? "checkmark.seal.fill" : "xmark.seal.fill")
                    .font(.caption2).foregroundStyle(ok ? .green : .red)
            }
            Spacer()
            Circle().fill(live.running ? .green : .secondary).frame(width: 6, height: 6)
            Text(live.running ? "running" : "not running").font(.caption2).foregroundStyle(.secondary)
        }
    }

    // MARK: Apply controls (any adapter with an apply route)
    private var applyControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            rtlBadge
            if adapter.isExperimental { experimentalNote }
            applyButton
            if adapter.relaunchesApp {
                Text("Applying relaunches \(adapter.name) with a local (127.0.0.1) debug port.")
                    .font(.caption2).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if adapter.hasWatchdog { watchdogToggle }
            footerRow
        }
    }

    private var applyButton: some View {
        let label = live.rtl == .stale
            ? "Reapply RTL"
            : (adapter.isExperimental ? "Apply RTL (experimental)" : "Apply RTL now")
        return Group {
            if adapter.isExperimental {
                Button { Task { await runner.reapply(adapter.id) } } label: {
                    Label(label, systemImage: "flask").frame(maxWidth: .infinity)
                }
                .controlSize(.large).buttonStyle(.bordered).tint(.orange)
            } else {
                Button { Task { await runner.reapply(adapter.id) } } label: {
                    Label(label, systemImage: "arrow.clockwise")
                }
                .buttonStyle(BrandButton())
            }
        }
        .disabled(runner.busy || live.rtl == .notRunning)
    }

    private var experimentalNote: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange).font(.caption)
            Text("Experimental — relaunches this signed app with a debug port. Opt-in; nothing on disk is changed.")
                .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .padding(8).frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 6))
    }

    private var watchdogToggle: some View {
        Toggle(isOn: Binding(
            get: { live.watch == .on || live.watch == .installed },
            set: { v in Task { await runner.setWatch(adapter.id, v) } }
        )) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Keep RTL after updates")
                Text("Re-applies automatically when \(adapter.name) relaunches").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .toggleStyle(.switch).controlSize(.small).font(.callout).disabled(runner.busy)
    }

    private var footerRow: some View {
        HStack {
            if adapter.hasWatchdog {
                Button { runner.openLogs(adapter.id) } label: { Label("Logs", systemImage: "doc.text") }
            }
            Spacer()
            if let at = live.lastSuccessAt, live.rtl != .notRunning {
                Text("applied \(short(at))").font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .controlSize(.small).buttonStyle(.borderless)
    }

    private var rtlBadge: some View {
        let (text, icon, color): (String, String, Color) = {
            switch live.rtl {
            case .active:     return ("RTL is active", "checkmark.circle.fill", .green)
            case .stale:      return ("RTL needs reapply — Claude relaunched", "exclamationmark.circle.fill", .orange)
            case .inactive:   return ("RTL not applied yet", "circle.dashed", .secondary)
            case .notRunning: return ("Open \(adapter.name), then apply RTL", "moon.zzz", .secondary)
            default:          return ("Checking…", "hourglass", .secondary)
            }
        }()
        return HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(color)
            Text(text).font(.caption.weight(.medium))
            Spacer()
        }
        .padding(.horizontal, 10).padding(.vertical, 8).frame(maxWidth: .infinity)
        .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    // MARK: Candidate / research note
    private var otherNote: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(adapter.status == .candidate
                 ? "Source-level fix — build the app from source. This manager does not inject at runtime."
                 : "No safe public route yet. The signed app must not be patched or re-signed.")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let docs = runner.docsURL {
                Button { NSWorkspace.shared.open(docs) } label: { Label("Learn more", systemImage: "info.circle") }
                    .controlSize(.small).buttonStyle(.borderless)
            }
        }
    }

    private func short(_ iso: String) -> String {
        // "2026-07-08T11:20:31+0300" -> "11:20"
        guard let t = iso.split(separator: "T").last, t.count >= 5 else { return iso }
        return String(t.prefix(5))
    }
}
