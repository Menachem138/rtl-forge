import SwiftUI
import AppKit

@main
struct RTLManagerApp: App {
    @StateObject private var runner = Manager()

    var body: some Scene {
        MenuBarExtra {
            ContentView(runner: runner)
                .task { await runner.refresh() }
        } label: {
            Image(systemName: "text.alignright")
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - Brand styling (matches the copy-patch gui/ app: warm terracotta, never neon-orange)
enum Brand {
    static let gradient = LinearGradient(
        colors: [Color(red: 0.84, green: 0.40, blue: 0.28), Color(red: 0.74, green: 0.27, blue: 0.18)],
        startPoint: .topLeading, endPoint: .bottomTrailing)
}

struct BrandButton: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(Brand.gradient.opacity(configuration.isPressed ? 0.85 : 1),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .shadow(color: Color(red: 0.91, green: 0.28, blue: 0.13).opacity(0.22), radius: 4, y: 2)
            .opacity(enabled ? 1 : 0.45)
            .saturation(enabled ? 1 : 0.3)
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - Window height tracking
// MenuBarExtra(.window) grows its panel to fit content but never shrinks it back (the
// "high-water-mark" bug), leaving a transparent gap when a section collapses. We measure the
// SwiftUI content's intrinsic height and force the hosting panel to exactly that (top-anchored),
// so it grows AND shrinks cleanly on every machine.
private struct HeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

private struct WindowResizer: NSViewRepresentable {
    var height: CGFloat
    func makeNSView(context: Context) -> NSView { NSView(frame: .zero) }
    func updateNSView(_ nsView: NSView, context: Context) {
        let target = height
        guard target > 1 else { return }
        DispatchQueue.main.async {
            guard let win = nsView.window, abs(win.frame.height - target) > 0.5 else { return }
            var f = win.frame
            let top = f.maxY                 // keep the top edge anchored to the menu bar
            f.size.height = target
            f.origin.y = top - target
            win.setFrame(f, display: true)
        }
    }
}

extension View {
    func measuredHeight() -> some View {
        modifier(MeasuredHeight())
    }
}

private struct MeasuredHeight: ViewModifier {
    @State private var height: CGFloat = 0
    func body(content: Content) -> some View {
        content
            .background(GeometryReader { g in
                Color.clear.preference(key: HeightKey.self, value: g.size.height)
            })
            .onPreferenceChange(HeightKey.self) { height = $0 }
            .background(WindowResizer(height: height))
    }
}
