import SwiftUI
import AK820Core

enum Pane: String, CaseIterable, Identifiable {
    case lighting = "Lighting", keyColors = "Key Colours", screen = "Screen", keys = "Key Mapping",
         macros = "Macros", settings = "Settings"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .lighting: return "lightbulb"
        case .keyColors: return "paintpalette"
        case .screen: return "photo"
        case .keys: return "keyboard"
        case .macros: return "repeat"
        case .settings: return "gearshape"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var model: KeyboardModel
    @Local private var pane: Pane? = {
        // `--pane <name>` opens a given pane (used to screenshot panes when debugging layout).
        let a = CommandLine.arguments
        if let i = a.firstIndex(of: "--pane"), i + 1 < a.count,
           let p = Pane.allCases.first(where: { $0.rawValue.lowercased().contains(a[i + 1].lowercased()) }) { return p }
        return .lighting
    }()

    var body: some View {
        NavigationSplitView {
            List(Pane.allCases, selection: $pane) { p in
                Label(p.rawValue, systemImage: p.icon).tag(p)
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 180)
        } detail: {
            VStack(spacing: 10) {
                Group {
                    switch pane ?? .lighting {
                    case .lighting: LightingPane()
                    case .keyColors: KeyColorsPane()
                    case .screen: ScreenPane()
                    case .keys: KeyMapPane()
                    case .macros: MacrosPane()
                    case .settings: SettingsPane()
                    }
                }
                .scrollContentBackground(.hidden)  // let the glass panel show through the Forms
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .glassPanel()
                .disabled(model.busy)
                StatusBar().glassCapsule()
            }
            .padding(12)
            .navigationTitle(pane?.rawValue ?? "")
        }
        .frame(minWidth: 900, minHeight: 600)
        .translucentWindow()
    }
}

struct StatusBar: View {
    @EnvironmentObject var model: KeyboardModel
    var body: some View {
        HStack(spacing: 10) {
            Circle().fill(model.connection.color).frame(width: 9, height: 9)
            Text(model.connection.label).foregroundColor(.secondary)
            Spacer()
            if model.busy {
                if let p = model.progress { ProgressView(value: p).frame(width: 140) } else { ProgressView().controlSize(.small) }
            }
            Text(model.status)
                .foregroundColor(model.statusIsError ? .red : .secondary)
                .lineLimit(2)
                .textSelection(.enabled)
            if model.statusIsError {
                Button("Show Log") { model.revealLog() }.controlSize(.small)
            }
        }
        .font(.callout)
        .padding(.horizontal, 14).padding(.vertical, 8)
    }
}

// Closing the window quits the app. Otherwise it stayed running with no window, and a Dock click
// (a reopen event) didn't bring one back, so it had to be force quit.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

struct AK820App: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var model = KeyboardModel()
    var body: some Scene {
        WindowGroup("AK820 Pro") {
            ContentView().environmentObject(model)
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .help) {
                Divider()
                Button("Show Log in Finder") { model.revealLog() }
                Button("Copy Log Path") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(DiagLog.fileURL.path, forType: .string)
                }
            }
        }
    }
}

if !CommandLine.arguments.contains("--pane") { DiagLog.start(source: "app", version: ak820Version) }

// `--selftest`: run real operations through KeyboardModel's background queue (no UI), print results, exit.
// It changes nothing you set: it reads the key colours and sets the screen clock to the Mac's time.
if CommandLine.arguments.contains("--selftest") {
    let model = KeyboardModel()
    let steps: [(String, (Keyboard, @escaping (Double) -> Void) throws -> Void)] = [
        ("read colours", { kb, _ in
            let d = try kb.readKeyColors()
            print("  Esc colour #" + d[5...7].map { String(format: "%02X", $0) }.joined())
        }),
        ("sync clock", { kb, _ in try kb.syncClock() }),
    ]
    func next(_ i: Int) {
        guard i < steps.count else { print("selftest done"); DiagLog.info("selftest passed"); exit(0) }
        print("- \(steps[i].0)")
        model.run(steps[i].0, done: "ok", steps[i].1) { next(i + 1) }
        // completion only runs on success; report failures and stop.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { watch(i) }
    }
    func watch(_ i: Int) {
        if model.busy { DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { watch(i) }; return }
        if model.statusIsError { print("  FAILED: \(model.status)"); exit(1) }
    }
    DispatchQueue.main.async { next(0) }
    RunLoop.main.run()
}

// Started as a plain executable (no Xcode project), so make it a regular foreground app first.
NSApplication.shared.setActivationPolicy(.regular)
DispatchQueue.main.async { NSApplication.shared.activate(ignoringOtherApps: true) }
AK820App.main()
