import SwiftUI
import AppKit
import UniformTypeIdentifiers
import AK820Core

private func paneHeader(_ text: String) -> some View {
    // No fixedSize here: measured at a tiny width it would ask for a huge height and push the whole
    // window's layout off screen (that's what blanked the panes).
    Text(text).foregroundColor(.secondary).lineLimit(4).multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
}

// MARK: Lighting

struct LightingPane: View {
    @EnvironmentObject var model: KeyboardModel
    @AppStorage("light.mode") private var mode = 1
    @AppStorage("light.rainbow") private var rainbow = false
    @AppStorage("light.brightness") private var brightness = 5.0
    @AppStorage("light.speed") private var speed = 3.0
    @AppStorage("light.direction") private var direction = 0
    @AppStorage("light.color") private var colorHex = "00AAFF"

    private var color: Binding<Color> {
        Binding(get: { hexColor(colorHex).color }, set: { colorHex = hexString(RGB($0)) })
    }

    var body: some View {
        Form {
            Section {
                Picker("Effect", selection: $mode) {
                    ForEach(lightModes, id: \.0) { m in Text(m.1.capitalized).tag(m.0) }
                }
                ColorPicker("Colour", selection: color, supportsOpacity: false).disabled(rainbow || mode == 0)
                Toggle("Rainbow (multicolour)", isOn: $rainbow).disabled(mode == 0)
                LabeledContent("Brightness") {
                    Slider(value: $brightness, in: 0...5, step: 1) { EmptyView() } minimumValueLabel: { Text("0") } maximumValueLabel: { Text("5") }
                }
                LabeledContent("Speed") {
                    Slider(value: $speed, in: 0...5, step: 1) { EmptyView() } minimumValueLabel: { Text("0") } maximumValueLabel: { Text("5") }
                }
                Picker("Direction", selection: $direction) {
                    ForEach(0..<4) { Text("\($0)").tag($0) }
                }.pickerStyle(.segmented)
            } footer: {
                paneHeader("Static colour and brightness were tested on the keyboard. The other effects use the same command but haven't each been tried.")
            }
            HStack {
                Spacer()
                Button("Apply to Keyboard") { apply() }.keyboardShortcut(.defaultAction)
            }
        }
        .formStyle(.grouped)
    }

    private func apply() {
        let c = hexColor(colorHex)
        let (m, rb, br, sp, dir) = (UInt8(mode), rainbow, UInt8(brightness), UInt8(speed), UInt8(direction))
        model.run("Setting lighting", done: "Lighting set: \(lightModes[mode].1).") { kb, _ in
            try kb.setLighting(mode: m, r: c.r, g: c.g, b: c.b, rainbow: rb, brightness: br, speed: sp, direction: dir)
        }
    }
}

func hexColor(_ s: String) -> RGB {
    let v = UInt32(s, radix: 16) ?? 0
    return RGB(r: UInt8(v >> 16 & 0xff), g: UInt8(v >> 8 & 0xff), b: UInt8(v & 0xff))
}
func hexString(_ c: RGB) -> String { String(format: "%02X%02X%02X", c.r, c.g, c.b) }

// MARK: Key colours

struct KeyColorsPane: View {
    @EnvironmentObject var model: KeyboardModel
    @Local private var selection: Set<Int> = []
    @Local private var paint: Color = .cyan
    @AppStorage("keyColors.brightness") private var brightness = 5.0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            paneHeader("Give each key its own colour. Click a key, or ⌘-click to pick several, then choose a colour. The colours are stored on the keyboard (user-lighting mode).")
            KeyboardView(selection: $selection, fill: { k in model.keyColors[k.index].map(\.color) })
                .frame(minHeight: 220)
            HStack(spacing: 8) {
                ColorPicker("Colour", selection: $paint, supportsOpacity: false).fixedSize()
                Button("Paint Selected") { setColor(RGB(paint), on: selection) }.disabled(selection.isEmpty)
                Button("Paint All") { setColor(RGB(paint), on: Set(layout.map(\.index))) }
                Button("Turn Off Selected") { setColor(.black, on: selection) }.disabled(selection.isEmpty).fixedSize()
                Spacer()
                Button("Select All") { selection = Set(layout.map(\.index)) }
                Button("Clear Selection") { selection = [] }.disabled(selection.isEmpty)
            }
            HStack(spacing: 10) {
                Text("Brightness")
                Slider(value: $brightness, in: 0...5, step: 1).frame(width: 160)
                Spacer()
                Button("Read from Keyboard") { read() }
                Button("Apply to Keyboard") { apply() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
    }

    private func setColor(_ c: RGB, on keys: Set<Int>) {
        var m = model.keyColors
        for k in keys { m[k] = c }
        model.keyColors = m
    }

    private func read() {
        model.run("Reading key colours", done: "Read the keyboard's current key colours.") { kb, _ in
            let d = try kb.readKeyColors()
            var m: [Int: RGB] = [:]
            for k in layout { m[k.index] = RGB(r: d[k.index * 4 + 1], g: d[k.index * 4 + 2], b: d[k.index * 4 + 3]) }
            DispatchQueue.main.async { model.keyColors = m }
        }
    }

    private func apply() {
        let colors = model.keyColors.mapValues { ($0.r, $0.g, $0.b) }
        let br = UInt8(brightness)
        model.run("Storing key colours", done: "Key colours stored on the keyboard.") { kb, _ in
            try kb.setUserLighting(colors, brightness: br)
        }
    }
}

// MARK: Screen

struct ScreenPane: View {
    @EnvironmentObject var model: KeyboardModel
    @Local private var path: String?
    @Local private var fill = true
    @Local private var frames: [[UInt8]] = []
    @Local private var delays: [Int] = []
    @Local private var previews: [CGImage] = []
    @Local private var loadError: String?

    // The factory GIF is AJAZZ's, so public builds don't include it; the user picks it from their own vendor package.
    private var factoryURL: URL? { Bundle.main.url(forResource: "factory-boot", withExtension: "gif") }

    var body: some View {
        HStack(alignment: .top, spacing: 24) {
            VStack(spacing: 8) {
                AnimatedPreview(images: previews, delays: delays)
                    .frame(width: 256, height: 256)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Text(frames.isEmpty ? "No picture chosen" : "\(frames.count) frame\(frames.count == 1 ? "" : "s"), 128 × 128")
                    .foregroundColor(.secondary).font(.callout)
            }
            VStack(alignment: .leading, spacing: 14) {
                paneHeader("Show a picture or an animated GIF (up to 140 frames) on the keyboard's 0.85\" screen. It's scaled to 128 × 128. A long GIF takes a couple of minutes to upload.")
                HStack {
                    Button("Choose Picture or GIF…") { choose() }
                    if let p = path { Text((p as NSString).lastPathComponent).foregroundColor(.secondary).lineLimit(1) }
                }
                Picker("Scaling", selection: $fill) {
                    Text("Fill (crop)").tag(true)
                    Text("Fit (letterbox)").tag(false)
                }
                .pickerStyle(.segmented).frame(width: 260)
                .onChange(of: fill) { _ in if let p = path { load(p) } }
                if let e = loadError { Text(e).foregroundColor(.red) }
                HStack {
                    Button("Upload to Keyboard") { upload(frames, delays) }
                        .keyboardShortcut(.defaultAction).disabled(frames.isEmpty)
                    Button(factoryURL == nil ? "Restore Factory Animation…" : "Restore Factory Animation") { restoreFactory() }
                }
                Divider()
                HStack {
                    Button("Sync Clock") { syncClock() }
                    Text("Sets the screen clock to this Mac's time.").foregroundColor(.secondary)
                }
            }
        }
        .padding(20)
    }

    private func choose() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url { path = url.path; load(url.path) }
    }

    private func load(_ p: String) {
        do {
            let r = try loadScreenFrames(path: p, fill: fill, defaultDelayMs: 100)
            frames = r.frames; delays = r.delays
            previews = r.frames.compactMap { previewImage(frame: $0) }
            loadError = nil
        } catch {
            frames = []; previews = []; loadError = "\(error)"
        }
    }

    private func upload(_ f: [[UInt8]], _ d: [Int]) {
        model.run("Uploading to the screen", done: "Screen updated.") { kb, progress in
            try kb.uploadScreen(frames: f, delaysMs: d) { done, total in progress(Double(done) / Double(total)) }
        }
    }

    private func restoreFactory() {
        var url = factoryURL
        if url == nil {
            let panel = NSOpenPanel()
            panel.allowedContentTypes = [.gif]
            panel.message = "Choose the factory animation GIF from the AJAZZ vendor software package."
            if panel.runModal() == .OK { url = panel.url }
        }
        guard let url else { return }
        do {
            let r = try loadScreenFrames(path: url.path, fill: true, defaultDelayMs: 100)
            loadError = nil
            upload(r.frames, r.delays)
        } catch {
            loadError = "\(error)"
        }
    }

    private func syncClock() {
        model.run("Setting the clock", done: "Screen clock set to this Mac's time.") { kb, _ in try kb.syncClock() }
    }
}

struct AnimatedPreview: View {
    let images: [CGImage]
    let delays: [Int]
    @Local private var index = 0
    @Local private var timer: Timer?

    var body: some View {
        Group {
            if images.indices.contains(index) {
                Image(decorative: images[index], scale: 1).resizable().interpolation(.none)
            } else {
                Image(systemName: "photo").font(.largeTitle).foregroundColor(.gray)
            }
        }
        .onAppear(perform: restart)
        .onChange(of: images.count) { _ in restart() }
        .onDisappear { timer?.invalidate() }
    }

    private func restart() {
        timer?.invalidate(); index = 0
        guard images.count > 1 else { return }
        schedule()
    }
    private func schedule() {
        let d = Double(delays.indices.contains(index) ? delays[index] : 100) / 1000
        timer = Timer.scheduledTimer(withTimeInterval: d, repeats: false) { _ in
            index = (index + 1) % max(1, images.count)
            schedule()
        }
    }
}

// MARK: Key mapping

enum ActionKind: String, CaseIterable, Identifiable {
    case standard = "Default", key = "Key / Shortcut", media = "Media", mouse = "Mouse", macro = "Macro", disable = "Disabled"
    var id: String { rawValue }
}

let mouseActions = ["left", "right", "middle", "back", "forward", "doubleclick", "wheelup", "wheeldown"]
let targetKeyNames: [String] = hidUsages.keys.sorted { a, b in
    (a.count, a) < (b.count, b)
}

/// Editable form of an action string such as "cmd+shift+4", "media:mute", "macro:2".
struct ActionDraft: Equatable {
    var kind: ActionKind = .standard
    var mods: Set<String> = []
    var key = "a"
    var media = "playpause"
    var mouse = "left"
    var macro = 0

    init() {}
    init(_ s: String) {
        let l = s.lowercased()
        if l.isEmpty || l == "default" { kind = .standard }
        else if l == "disable" { kind = .disable }
        else if l.hasPrefix("media:") { kind = .media; media = String(l.dropFirst(6)) }
        else if l.hasPrefix("mouse:") { kind = .mouse; mouse = String(l.dropFirst(6)) }
        else if l.hasPrefix("macro:") { kind = .macro; macro = Int(l.split(separator: ":")[1]) ?? 0 }
        else {
            kind = .key
            let parts = l.split(separator: "+").map(String.init)
            key = parts.last ?? "a"
            mods = Set(parts.dropLast())
        }
    }

    var string: String {
        switch kind {
        case .standard: return "default"
        case .disable: return "disable"
        case .media: return "media:" + media
        case .mouse: return "mouse:" + mouse
        case .macro: return "macro:\(macro)"
        case .key: return (["ctrl", "shift", "alt", "cmd"].filter { mods.contains($0) } + [key]).joined(separator: "+")
        }
    }
}

func shortLabel(_ action: String) -> String {
    let d = ActionDraft(action)
    switch d.kind {
    case .standard: return ""
    case .disable: return "off"
    case .media: return "♫ " + d.media
    case .mouse: return "🖱 " + d.mouse
    case .macro: return "M\(d.macro)"
    case .key:
        let sym: [String: String] = ["ctrl": "⌃", "shift": "⇧", "alt": "⌥", "cmd": "⌘"]
        return ["ctrl", "shift", "alt", "cmd"].filter { d.mods.contains($0) }.map { sym[$0]! }.joined() + d.key.uppercased()
    }
}

struct KeyMapPane: View {
    @EnvironmentObject var model: KeyboardModel
    @Local private var fnLayer = false
    @Local private var selection: Set<Int> = []
    @Local private var draft = ActionDraft()

    private var map: [String: String] { fnLayer ? model.fnMap : model.baseMap }
    private var selectedKey: LayoutKey? {
        selection.count == 1 ? layout.first { $0.index == selection.first! } : nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Picker("Layer", selection: $fnLayer) {
                    Text("Base layer").tag(false)
                    Text("Fn layer").tag(true)
                }
                .pickerStyle(.segmented).frame(width: 240)
                .onChange(of: fnLayer) { _ in selection = [] }
                Spacer()
                paneHeader("On a Mac, Win is ⌘ Command and Alt is ⌥ Option.")
            }
            KeyboardView(selection: $selection,
                         fill: { k in map[k.name].map { ActionDraft($0).kind == .standard ? nil : Color.accentColor.opacity(0.25) } ?? nil },
                         badge: { k in map[k.name].map(shortLabel) },
                         disabled: { k in k.name == "Fn" || (fnLayer && k.fnLocked) })
                .frame(minHeight: 220)
            if let k = selectedKey {
                editor(for: k)
            } else {
                paneHeader("Click a key to change what it does. Keys you don't change keep their normal function.")
                    .frame(height: 70, alignment: .top)
            }
            HStack {
                Button("Reset Layer to Defaults") {
                    if fnLayer { model.fnMap = [:] } else { model.baseMap = [:] }
                    apply()
                }
                Spacer()
                Button("Apply to Keyboard") { apply() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .onChange(of: selection) { _ in
            if let k = selectedKey { draft = ActionDraft(map[k.name] ?? "default") }
        }
    }

    @ViewBuilder
    private func editor(for k: LayoutKey) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Text(k.name).font(.headline).frame(width: 110, alignment: .leading)
            Picker("", selection: $draft.kind) {
                ForEach(ActionKind.allCases) { Text($0.rawValue).tag($0) }
            }.frame(width: 150)
            switch draft.kind {
            case .key:
                ForEach([("ctrl", "⌃ Ctrl"), ("shift", "⇧ Shift"), ("alt", "⌥ Alt"), ("cmd", "⌘ Cmd")], id: \.0) { m in
                    Toggle(m.1, isOn: Binding(get: { draft.mods.contains(m.0) },
                                              set: { if $0 { draft.mods.insert(m.0) } else { draft.mods.remove(m.0) } }))
                }
                Picker("", selection: $draft.key) {
                    ForEach(targetKeyNames, id: \.self) { Text($0.uppercased()).tag($0) }
                }.frame(width: 140)
            case .media:
                Picker("", selection: $draft.media) {
                    ForEach(consumerUsages.keys.sorted(), id: \.self) { Text($0).tag($0) }
                }.frame(width: 180)
            case .mouse:
                Picker("", selection: $draft.mouse) {
                    ForEach(mouseActions, id: \.self) { Text($0).tag($0) }
                }.frame(width: 160)
            case .macro:
                Picker("", selection: $draft.macro) {
                    ForEach(Array(model.macros.enumerated()), id: \.offset) { i, m in Text("\(i): \(m.name)").tag(i) }
                    if model.macros.isEmpty { Text("No macros yet (see Macros)").tag(0) }
                }.frame(width: 220)
            case .standard, .disable:
                EmptyView()
            }
            Spacer()
        }
        .frame(height: 70)
        .onChange(of: draft) { d in
            var m = map
            m[k.name] = d.kind == .standard ? nil : d.string
            if fnLayer { model.fnMap = m } else { model.baseMap = m }
        }
    }

    private func apply() {
        let fn = fnLayer
        var actions: [Int: [UInt8]] = [:]
        do {
            for (name, a) in map {
                guard let k = layoutKey(named: name) else { continue }
                actions[k.index] = try parseAction(a)
            }
        } catch { model.fail("\(error)"); return }
        let n = actions.count
        model.run("Writing the \(fn ? "Fn" : "base") layer", done: "\(fn ? "Fn" : "Base") layer written: \(n) key\(n == 1 ? "" : "s") changed.") { kb, _ in
            try kb.setKeyMap(fnLayer: fn, actions: actions)
        }
    }
}

// MARK: Macros

struct MacrosPane: View {
    @EnvironmentObject var model: KeyboardModel
    @Local private var selected: UUID?

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                List(selection: $selected) {
                    ForEach(Array(model.macros.enumerated()), id: \.element.id) { i, m in
                        Text("\(i): \(m.name)").tag(m.id)
                    }
                }
                HStack {
                    Button { add() } label: { Image(systemName: "plus") }
                    Button { remove() } label: { Image(systemName: "minus") }.disabled(selected == nil)
                    Spacer()
                }
                .buttonStyle(.borderless).padding(8)
            }
            .frame(width: 200)
            Divider()
            VStack(alignment: .leading, spacing: 10) {
                if let i = model.macros.firstIndex(where: { $0.id == selected }) {
                    TextField("Name", text: $model.macros[i].name).textFieldStyle(.roundedBorder)
                    TextEditor(text: $model.macros[i].steps)
                        .font(.system(.body, design: .monospaced))
                        .border(Color.secondary.opacity(0.3))
                } else {
                    Text(model.macros.isEmpty ? "No macros yet. Click + to add one." : "Select a macro on the left to edit it.")
                        .font(.title3).foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                paneHeader("One step per line: tap:K, down:K, up:K, mousedown:left, mouseup:left, or a number for a pause in ms after the previous step. Key names: a–z, 0–9, f1…f24, enter, space, tab, esc, leftshift, leftctrl, leftalt, leftwin (⌘), …\nAssign a macro to a key under Key Mapping → Macro.")
                HStack {
                    Spacer()
                    Button("Upload All Macros") { upload() }.keyboardShortcut(.defaultAction)
                }
            }
            .padding(20)
        }
    }

    private func add() {
        let m = Macro(name: "Macro \(model.macros.count)", steps: "tap:h\ntap:i\n")
        model.macros.append(m); selected = m.id
    }
    private func remove() {
        model.macros.removeAll { $0.id == selected }; selected = nil
    }

    private func upload() {
        var built: [[[UInt8]]] = []
        do {
            for (i, m) in model.macros.enumerated() {
                let items: [Any] = m.steps.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                    .map { s -> Any in Int(s).map { NSNumber(value: $0) } ?? s }
                built.append(try parseMacro(items, name: "\(i) (\(m.name))"))
            }
        } catch { model.fail("\(error)"); return }
        let n = built.count
        model.run("Uploading macros", done: "\(n) macro\(n == 1 ? "" : "s") uploaded.") { kb, _ in try kb.setMacros(built) }
    }
}

// MARK: Settings

struct SettingsPane: View {
    @EnvironmentObject var model: KeyboardModel
    @AppStorage("settings.disableWin") private var disableWin = false
    @AppStorage("settings.disableAltTab") private var disableAltTab = false
    @AppStorage("settings.disableAltF4") private var disableAltF4 = false
    @AppStorage("settings.sleep") private var sleep = 0
    @AppStorage("settings.response") private var response = 1
    @AppStorage("settings.fnSwitch") private var fnSwitch = 0

    var body: some View {
        Form {
            Section {
                Toggle("Disable the Windows (⌘) key", isOn: $disableWin)
                Toggle("Disable Alt+Tab", isOn: $disableAltTab)
                Toggle("Disable Alt+F4", isOn: $disableAltF4)
                Picker("Sleep after", selection: $sleep) {
                    Text("Never").tag(0); Text("1 minute").tag(1); Text("5 minutes").tag(2); Text("30 minutes").tag(3)
                }
                Picker("Key response (debounce)", selection: $response) {
                    ForEach(1...5, id: \.self) { Text("Level \($0)").tag($0) }
                }
                Picker("Fn switch", selection: $fnSwitch) {
                    Text("0").tag(0); Text("1").tag(1)
                }
            } footer: {
                paneHeader("Untested: these values come from the vendor app's code, but what some of them mean is guessed (sleep times and the Fn switch especially). The keyboard takes all settings at once.")
            }
            HStack {
                Spacer()
                Button("Apply to Keyboard") { apply() }.keyboardShortcut(.defaultAction)
            }
        }
        .formStyle(.grouped)
    }

    private func apply() {
        let (w, t, f, s, r, fs) = (disableWin, disableAltTab, disableAltF4, UInt8(sleep), UInt8(response), UInt8(fnSwitch))
        model.run("Sending settings", done: "Settings sent.") { kb, _ in
            try kb.setSettings(disableAltTab: t, disableAltF4: f, disableWin: w, fnSwitch: fs, sleepTime: s, responseLevel: r)
        }
    }
}
