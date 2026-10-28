import Foundation

/// Parse a remap target such as "LeftCtrl", "cmd+shift+4", "media:mute", "mouse:left", "macro:0", "disable", "default".
public func parseAction(_ raw: String) throws -> [UInt8] {
    let s = raw.lowercased().trimmingCharacters(in: .whitespaces)
    if s == "default" { return [0, 0, 0, 0] }
    if s == "disable" || s == "disabled" || s == "none" { return [0x05, 0x03, 0, 0] }
    if s.hasPrefix("media:") || s.hasPrefix("consumer:") {
        let n = String(s.split(separator: ":", maxSplits: 1)[1])
        guard let u = consumerUsages[n] else { throw HIDError("Unknown media key '\(n)'. Known: \(consumerUsages.keys.sorted().joined(separator: ", "))") }
        return [0x03, UInt8(u & 0xff), UInt8(u >> 8), 0]
    }
    if s.hasPrefix("mouse:") {
        switch s.dropFirst(6) {
        case "left": return [0x01, 0x01, 0x01, 0]
        case "right": return [0x01, 0x01, 0x02, 0]
        case "middle": return [0x01, 0x01, 0x04, 0]
        case "back", "button4": return [0x01, 0x01, 0x08, 0]
        case "forward", "button5": return [0x01, 0x01, 0x10, 0]
        case "doubleclick": return [0x01, 0x01, 0x03, 0]
        case "wheelup": return [0x01, 0x03, 0x01, 0]
        case "wheeldown": return [0x01, 0x03, 0xff, 0]
        default: throw HIDError("Unknown mouse action '\(raw)' (left, right, middle, back, forward, doubleclick, wheelup, wheeldown)")
        }
    }
    if s.hasPrefix("macro:") {
        // macro:<slot>[:<mode>[:<repeat>]]
        let parts = s.split(separator: ":").dropFirst().map { Int($0) }
        guard let slot = parts.first ?? nil, (0..<100).contains(slot) else { throw HIDError("Bad macro target '\(raw)': use macro:<0-99>[:mode[:repeat]]") }
        let mode = parts.count > 1 ? (parts[1] ?? 1) : 1
        let rep = parts.count > 2 ? (parts[2] ?? 1) : 1
        return [0x06, UInt8(slot), UInt8(mode & 0xff), UInt8(rep & 0xff)]
    }
    // key or combo: mod+mod+key
    let parts = s.split(separator: "+").map(String.init)
    var mods: UInt8 = 0
    for m in parts.dropLast() {
        guard let b = modifierBits[m] else { throw HIDError("Unknown modifier '\(m)' in '\(raw)'") }
        mods |= b
    }
    guard let last = parts.last, let code = hidUsage(named: last) else { throw HIDError("Unknown key '\(raw)'") }
    if mods == 0, (0xe0...0xe7).contains(code) {
        return [0x02, UInt8(1) << (code - 0xe0), 0, 0]   // lone modifier
    }
    return [0x02, mods, code, 0]
}

/// Macro tokens: "tap:A", "down:A", "up:A", "mousedown:left", "mouseup:left", or a number (delay in ms after the previous event).
public func parseMacro(_ items: [Any], name: String) throws -> [[UInt8]] {
    var actions: [(ev: [UInt8], delay: Int)] = []
    func key(_ n: String) throws -> UInt8 {
        guard let c = hidUsage(named: n) else { throw HIDError("Macro \(name): unknown key '\(n)'") }
        return c
    }
    func button(_ n: String) throws -> UInt8 {
        switch n.lowercased() { case "left": return 1; case "right": return 2; case "middle": return 4
        default: throw HIDError("Macro \(name): unknown mouse button '\(n)'") }
    }
    for it in items {
        if let n = it as? NSNumber {
            guard !actions.isEmpty else { throw HIDError("Macro \(name): a delay can't come first") }
            actions[actions.count - 1].delay = n.intValue
            continue
        }
        guard let t = it as? String else { throw HIDError("Macro \(name): items must be strings or numbers") }
        let p = t.split(separator: ":", maxSplits: 1).map(String.init)
        guard p.count == 2 else { throw HIDError("Macro \(name): bad item '\(t)'") }
        switch p[0].lowercased() {
        case "tap": let k = try key(p[1]); actions.append(([0, 0, k, 0xB0], 10)); actions.append(([0, 0, k, 0x30], 10))
        case "down": actions.append(([0, 0, try key(p[1]), 0xB0], 10))
        case "up": actions.append(([0, 0, try key(p[1]), 0x30], 10))
        case "mousedown": actions.append(([0, 0, try button(p[1]), 0x90], 10))
        case "mouseup": actions.append(([0, 0, try button(p[1]), 0x10], 10))
        default: throw HIDError("Macro \(name): bad item '\(t)'")
        }
    }
    var out: [[UInt8]] = []
    for a in actions {
        out.append(a.ev)
        let d = min(65535, max(10, a.delay))
        out.append([UInt8(d & 0xff), UInt8(d >> 8), 0, 0x50])
    }
    return out
}

