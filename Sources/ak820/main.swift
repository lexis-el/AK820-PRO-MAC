import Foundation
import AK820Core

let usage = """
ak820: configure the AJAZZ AK820 Pro (wired USB) on macOS

USAGE: ak820 <command> [options] [--verbose] [--dry-run]

  --dry-run   print the packets a write command would send, without touching the keyboard

Read-only:
  list                         Show the keyboard's HID interfaces (any connection mode)
  modes                        List lighting modes
  log [--show] [--reveal]      Print the log file's path (--show: last 200 lines, --reveal: show it in Finder)
  read-colors                  Read the per-key colour table from the keyboard
  screen-preview <img> <out.png> [--fit]
                               Convert an image like `screen` would, without a keyboard

Write (reversible from this tool or the keyboard's Fn shortcuts):
  light <mode> [--color RRGGBB] [--rainbow] [--brightness 0-5] [--speed 0-5] [--direction 0-3]
  key-colors (<file.json> | --all RRGGBB) [--brightness 0-5]
                               Per-key colours, e.g. {"Esc":"FF0000","W":"00FF00"}
  clock [--slot 1]             Set the screen clock to this Mac's time
  screen <image|gif> [--fit] [--delay ms] [--slot 1]
                               Upload a picture or animated GIF (≤140 frames) to the 0.85" screen
  remap <file.json> [--fn]     Replace the base (or Fn) layer key map; unlisted keys go back to default
  macros <file.json>           Replace all macros (up to 100)
  settings --sleep N --response N [--fn-switch N] [--disable-win] [--disable-alt-tab] [--disable-alt-f4]

See README.md for the JSON formats and PROTOCOL.md for the protocol.
"""

func fail(_ msg: String) -> Never {
    DiagLog.error(msg)
    FileHandle.standardError.write("error: \(msg)\n".data(using: .utf8)!)
    exit(1)
}

struct Args {
    var positional: [String] = []
    var options: [String: String] = [:]
    var flags: Set<String> = []
    init(_ argv: [String], valued: Set<String>) {
        var i = 0
        while i < argv.count {
            let a = argv[i]
            if a.hasPrefix("--") {
                let k = String(a.dropFirst(2))
                if valued.contains(k) {
                    guard i + 1 < argv.count else { fail("--\(k) needs a value") }
                    options[k] = argv[i + 1]; i += 1
                } else { flags.insert(k) }
            } else { positional.append(a) }
            i += 1
        }
    }
    func int(_ k: String, _ def: Int, _ range: ClosedRange<Int>) -> Int {
        guard let s = options[k] else { return def }
        guard let v = Int(s), range.contains(v) else { fail("--\(k) must be a number in \(range.lowerBound)...\(range.upperBound)") }
        return v
    }
}

func parseColor(_ s: String) -> (UInt8, UInt8, UInt8) {
    var h = s.trimmingCharacters(in: .whitespaces)
    if h.hasPrefix("#") { h.removeFirst() }
    guard h.count == 6, let v = UInt32(h, radix: 16) else { fail("Bad colour '\(s)': use RRGGBB") }
    return (UInt8(v >> 16 & 0xff), UInt8(v >> 8 & 0xff), UInt8(v & 0xff))
}

func readJSON(_ path: String) -> Any {
    let d: Data
    if path == "-" || path == "/dev/stdin" {
        d = FileHandle.standardInput.readDataToEndOfFile()
    } else {
        guard let f = FileManager.default.contents(atPath: path) else { fail("Can't read \(path)") }
        d = f
    }
    do { return try JSONSerialization.jsonObject(with: d) } catch { fail("\(path) isn't valid JSON: \(error.localizedDescription)") }
}

func confirmWired() -> Keyboard {
    if args.flags.contains("dry-run") { return Keyboard(command: nil, bulk: nil) }
    do { return try Keyboard.find() } catch { fail("\(error)") }
}

// MARK: main

var argv = Array(CommandLine.arguments.dropFirst())
if argv.first != "log" && !argv.contains("--dry-run") { DiagLog.start(source: "cli", version: ak820Version) }
guard let cmd = argv.first else { print(usage); exit(0) }
argv.removeFirst()
let args = Args(argv, valued: ["color", "brightness", "speed", "direction", "all", "slot", "delay", "sleep", "response", "fn-switch"])
let verbose = args.flags.contains("verbose")

do {
    switch cmd {
    case "help", "-h", "--help":
        print(usage)

    case "list":
        let all = HIDEnumerator.interfaces(vendorID: vendorID)
        if all.isEmpty { print("No device with vendor ID 0C45 found.") }
        for i in all {
            var role = ""
            if wiredPIDs.contains(i.productID) {
                if i.maxFeature == 64 || i.maxFeature == 65 { role = "  <- command channel" }
                if i.maxOutput == 4096 || i.maxOutput == 4097 { role = "  <- screen data channel" }
            } else if i.productID == donglePID { role = "  (2.4 GHz dongle)" }
            else if i.productID == bluetoothPID { role = "  (Bluetooth: not configurable)" }
            print(i.summary + role)
        }

    case "log":
        let path = DiagLog.fileURL.path
        if args.flags.contains("show") {
            let text = (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
            print(text.split(separator: "\n", omittingEmptySubsequences: false).suffix(200).joined(separator: "\n"))
        } else if args.flags.contains("reveal") {
            NSWorkspace_reveal(path)
        } else {
            print(path)
        }

    case "modes":
        for (v, n) in lightModes { print(String(format: "%2d  %@", v, n)) }

    case "read-colors":
        let kb = confirmWired(); kb.verbose = verbose
        let data = try kb.readKeyColors()
        for k in layout.sorted(by: { $0.index < $1.index }) {
            let o = k.index * 4
            print(String(format: "%-13@ idx %3d  slot-id %3d  #%02X%02X%02X", k.name as NSString, k.index, data[o], data[o + 1], data[o + 2], data[o + 3]))
        }
        if verbose {
            for row in stride(from: 0, to: data.count, by: 32) {
                print(data[row..<min(row + 32, data.count)].map { String(format: "%02x", $0) }.joined(separator: " "))
            }
        }

    case "light":
        guard let m = args.positional.first else { fail("light needs a mode (number or name, see `ak820 modes`)") }
        let mode: Int
        if let v = Int(m) { mode = v } else if let e = lightModes.first(where: { $0.1 == m.lowercased() }) { mode = e.0 } else { fail("Unknown mode '\(m)'") }
        guard (0...19).contains(mode) else { fail("Mode must be 0...19") }
        let (r, g, b) = parseColor(args.options["color"] ?? "FF0000")
        let rainbow = args.flags.contains("rainbow")
        let kb = confirmWired(); kb.verbose = verbose
        try kb.setLighting(mode: UInt8(mode), r: r, g: g, b: b, rainbow: rainbow,
                           brightness: UInt8(args.int("brightness", 5, 0...5)),
                           speed: UInt8(args.int("speed", 3, 0...5)),
                           direction: UInt8(args.int("direction", 0, 0...3)))
        print("Lighting set: mode \(mode) (\(lightModes[mode].1)).")

    case "key-colors":
        var colors: [Int: (UInt8, UInt8, UInt8)] = [:]
        if let all = args.options["all"] {
            let c = parseColor(all)
            for k in layout { colors[k.index] = c }
        } else if let path = args.positional.first {
            guard let obj = readJSON(path) as? [String: String] else { fail("\(path) must be an object like {\"Esc\":\"FF0000\"}") }
            for (name, hex) in obj {
                guard let k = layoutKey(named: name) else { fail("Unknown key '\(name)'") }
                colors[k.index] = parseColor(hex)
            }
        } else { fail("key-colors needs a JSON file or --all RRGGBB") }
        let kb = confirmWired(); kb.verbose = verbose
        try kb.setUserLighting(colors, brightness: UInt8(args.int("brightness", 5, 0...5)))
        print("Per-key colours stored for \(colors.count) keys (user lighting mode).")

    case "clock":
        let kb = confirmWired(); kb.verbose = verbose
        try kb.syncClock(slot: UInt8(args.int("slot", 1, 1...255)))
        print("Screen clock set to \(Date()).")

    case "screen":
        guard let path = args.positional.first else { fail("screen needs an image or GIF path") }
        let (frames, delays) = try loadScreenFrames(path: path, fill: !args.flags.contains("fit"),
                                                    defaultDelayMs: args.int("delay", 100, 30...500))
        let kb = confirmWired(); kb.verbose = verbose
        print("Uploading \(frames.count) frame(s)...")
        var lastPct = -1
        try kb.uploadScreen(frames: frames, delaysMs: delays, slot: UInt8(args.int("slot", 1, 1...255))) { done, total in
            let pct = done * 100 / total
            guard pct != lastPct else { return }
            lastPct = pct
            print("\r  \(pct)%", terminator: done == total ? "\n" : ""); fflush(stdout)
        }
        print("Screen updated.")

    case "screen-preview":
        guard args.positional.count == 2 else { fail("screen-preview <image|gif> <out.png> [--fit]") }
        let (frames, delays) = try loadScreenFrames(path: args.positional[0], fill: !args.flags.contains("fit"),
                                                    defaultDelayMs: args.int("delay", 100, 30...500))
        try writePreview(frame: frames[0], to: args.positional[1])
        print("\(frames.count) frame(s), delays \(delays.prefix(8).map(String.init).joined(separator: ","))\(delays.count > 8 ? ",..." : "") ms; first frame written to \(args.positional[1])")

    case "remap":
        guard let path = args.positional.first else { fail("remap needs a JSON file") }
        guard let obj = readJSON(path) as? [String: String] else { fail("\(path) must be an object like {\"CapsLock\":\"LeftCtrl\"}") }
        let fn = args.flags.contains("fn")
        var actions: [Int: [UInt8]] = [:]
        for (src, target) in obj {
            guard let k = layoutKey(named: src) else { fail("Unknown key '\(src)'") }
            if fn && k.fnLocked { fail("\(k.name) can't be changed on the Fn layer") }
            if k.name == "Fn" { fail("Remapping the Fn key isn't allowed (you could lose access to the Fn layer)") }
            actions[k.index] = try parseAction(target)
        }
        let kb = confirmWired(); kb.verbose = verbose
        try kb.setKeyMap(fnLayer: fn, actions: actions)
        print("\(fn ? "Fn" : "Base") layer updated: \(actions.count) key(s) remapped, all others reset to default.")

    case "macros":
        guard let path = args.positional.first else { fail("macros needs a JSON file") }
        guard let list = readJSON(path) as? [[Any]] else { fail("\(path) must be an array of macros, each an array of steps") }
        guard list.count <= 100 else { fail("At most 100 macros") }
        let macros = try list.enumerated().map { try parseMacro($0.element, name: "#\($0.offset)") }
        let kb = confirmWired(); kb.verbose = verbose
        try kb.setMacros(macros)
        print("\(macros.count) macro(s) uploaded. Assign one to a key with remap: \"F1\": \"macro:0\".")

    case "settings":
        guard args.options["sleep"] != nil, args.options["response"] != nil else {
            fail("settings needs --sleep and --response (the keyboard takes all settings at once)")
        }
        let kb = confirmWired(); kb.verbose = verbose
        try kb.setSettings(disableAltTab: args.flags.contains("disable-alt-tab"),
                           disableAltF4: args.flags.contains("disable-alt-f4"),
                           disableWin: args.flags.contains("disable-win"),
                           fnSwitch: UInt8(args.int("fn-switch", 0, 0...255)),
                           sleepTime: UInt8(args.int("sleep", 0, 0...255)),
                           responseLevel: UInt8(args.int("response", 1, 0...255)))
        print("Settings sent.")

    default:
        fail("Unknown command '\(cmd)'. Run `ak820 help`.")
    }
} catch {
    fail("\(error)")
}

/// Show a file in Finder (`open -R`), without linking AppKit into the CLI.
func NSWorkspace_reveal(_ path: String) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    p.arguments = ["-R", path]
    try? p.run(); p.waitUntilExit()
}
