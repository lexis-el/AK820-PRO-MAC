import Foundation

/// A physical key on the AK820 Pro, from the vendor's `layouts/rgb-keyboard.xml`.
/// `index` is both key_index (key map slot) and light_index (LED slot); they are equal for every key.
public struct LayoutKey {
    public let name: String       // name used on the command line
    public let hid: UInt8         // default HID usage
    public let index: Int
    public let fnLocked: Bool     // fnlayer_disable="1": can't be remapped on the Fn layer
}

public let layout: [LayoutKey] = [
    LayoutKey(name: "Esc", hid: 0x29, index: 1, fnLocked: true),
    LayoutKey(name: "F1", hid: 0x3a, index: 2, fnLocked: false),
    LayoutKey(name: "F2", hid: 0x3b, index: 3, fnLocked: false),
    LayoutKey(name: "F3", hid: 0x3c, index: 4, fnLocked: false),
    LayoutKey(name: "F4", hid: 0x3d, index: 5, fnLocked: false),
    LayoutKey(name: "F5", hid: 0x3e, index: 6, fnLocked: false),
    LayoutKey(name: "F6", hid: 0x3f, index: 7, fnLocked: false),
    LayoutKey(name: "F7", hid: 0x40, index: 8, fnLocked: false),
    LayoutKey(name: "F8", hid: 0x41, index: 9, fnLocked: false),
    LayoutKey(name: "F9", hid: 0x42, index: 10, fnLocked: false),
    LayoutKey(name: "F10", hid: 0x43, index: 11, fnLocked: false),
    LayoutKey(name: "F11", hid: 0x44, index: 12, fnLocked: false),
    LayoutKey(name: "F12", hid: 0x45, index: 13, fnLocked: false),
    LayoutKey(name: "Delete", hid: 0x4c, index: 119, fnLocked: false),
    LayoutKey(name: "Grave", hid: 0x35, index: 19, fnLocked: false),
    LayoutKey(name: "1", hid: 0x1e, index: 20, fnLocked: false),
    LayoutKey(name: "2", hid: 0x1f, index: 21, fnLocked: false),
    LayoutKey(name: "3", hid: 0x20, index: 22, fnLocked: false),
    LayoutKey(name: "4", hid: 0x21, index: 23, fnLocked: false),
    LayoutKey(name: "5", hid: 0x22, index: 24, fnLocked: false),
    LayoutKey(name: "6", hid: 0x23, index: 25, fnLocked: false),
    LayoutKey(name: "7", hid: 0x24, index: 26, fnLocked: false),
    LayoutKey(name: "8", hid: 0x25, index: 27, fnLocked: false),
    LayoutKey(name: "9", hid: 0x26, index: 28, fnLocked: false),
    LayoutKey(name: "0", hid: 0x27, index: 29, fnLocked: false),
    LayoutKey(name: "Minus", hid: 0x2d, index: 30, fnLocked: false),
    LayoutKey(name: "Equal", hid: 0x2e, index: 31, fnLocked: false),
    LayoutKey(name: "Backspace", hid: 0x2a, index: 103, fnLocked: true),
    LayoutKey(name: "Home", hid: 0x4a, index: 117, fnLocked: true),
    LayoutKey(name: "Tab", hid: 0x2b, index: 37, fnLocked: false),
    LayoutKey(name: "Q", hid: 0x14, index: 38, fnLocked: false),
    LayoutKey(name: "W", hid: 0x1a, index: 39, fnLocked: false),
    LayoutKey(name: "E", hid: 0x08, index: 40, fnLocked: false),
    LayoutKey(name: "R", hid: 0x15, index: 41, fnLocked: false),
    LayoutKey(name: "T", hid: 0x17, index: 42, fnLocked: false),
    LayoutKey(name: "Y", hid: 0x1c, index: 43, fnLocked: false),
    LayoutKey(name: "U", hid: 0x18, index: 44, fnLocked: false),
    LayoutKey(name: "I", hid: 0x0c, index: 45, fnLocked: false),
    LayoutKey(name: "O", hid: 0x12, index: 46, fnLocked: false),
    LayoutKey(name: "P", hid: 0x13, index: 47, fnLocked: false),
    LayoutKey(name: "LeftBracket", hid: 0x2f, index: 48, fnLocked: false),
    LayoutKey(name: "RightBracket", hid: 0x30, index: 49, fnLocked: false),
    LayoutKey(name: "Backslash", hid: 0x31, index: 67, fnLocked: true),
    LayoutKey(name: "PageUp", hid: 0x4b, index: 118, fnLocked: false),
    LayoutKey(name: "CapsLock", hid: 0x39, index: 55, fnLocked: false),
    LayoutKey(name: "A", hid: 0x04, index: 56, fnLocked: false),
    LayoutKey(name: "S", hid: 0x16, index: 57, fnLocked: false),
    LayoutKey(name: "D", hid: 0x07, index: 58, fnLocked: false),
    LayoutKey(name: "F", hid: 0x09, index: 59, fnLocked: false),
    LayoutKey(name: "G", hid: 0x0a, index: 60, fnLocked: false),
    LayoutKey(name: "H", hid: 0x0b, index: 61, fnLocked: false),
    LayoutKey(name: "J", hid: 0x0d, index: 62, fnLocked: false),
    LayoutKey(name: "K", hid: 0x0e, index: 63, fnLocked: false),
    LayoutKey(name: "L", hid: 0x0f, index: 64, fnLocked: false),
    LayoutKey(name: "Semicolon", hid: 0x33, index: 65, fnLocked: false),
    LayoutKey(name: "Quote", hid: 0x34, index: 66, fnLocked: false),
    LayoutKey(name: "Enter", hid: 0x28, index: 85, fnLocked: false),
    LayoutKey(name: "PageDown", hid: 0x4e, index: 121, fnLocked: false),
    LayoutKey(name: "LeftShift", hid: 0xe1, index: 73, fnLocked: false),
    LayoutKey(name: "Z", hid: 0x1d, index: 74, fnLocked: false),
    LayoutKey(name: "X", hid: 0x1b, index: 75, fnLocked: false),
    LayoutKey(name: "C", hid: 0x06, index: 76, fnLocked: false),
    LayoutKey(name: "V", hid: 0x19, index: 77, fnLocked: false),
    LayoutKey(name: "B", hid: 0x05, index: 78, fnLocked: false),
    LayoutKey(name: "N", hid: 0x11, index: 79, fnLocked: false),
    LayoutKey(name: "M", hid: 0x10, index: 80, fnLocked: false),
    LayoutKey(name: "Comma", hid: 0x36, index: 81, fnLocked: false),
    LayoutKey(name: "Period", hid: 0x37, index: 82, fnLocked: false),
    LayoutKey(name: "Slash", hid: 0x38, index: 83, fnLocked: false),
    LayoutKey(name: "RightShift", hid: 0xe5, index: 84, fnLocked: false),
    LayoutKey(name: "Up", hid: 0x52, index: 101, fnLocked: false),
    LayoutKey(name: "LeftCtrl", hid: 0xe0, index: 91, fnLocked: false),
    LayoutKey(name: "LeftWin", hid: 0xe3, index: 92, fnLocked: true),
    LayoutKey(name: "LeftAlt", hid: 0xe2, index: 93, fnLocked: false),
    LayoutKey(name: "Space", hid: 0x2c, index: 94, fnLocked: false),
    LayoutKey(name: "RightAlt", hid: 0xe6, index: 95, fnLocked: false),
    LayoutKey(name: "Fn", hid: 0xaf, index: 96, fnLocked: true),
    LayoutKey(name: "RightCtrl", hid: 0xe4, index: 98, fnLocked: false),
    LayoutKey(name: "Left", hid: 0x50, index: 99, fnLocked: false),
    LayoutKey(name: "Down", hid: 0x51, index: 100, fnLocked: false),
    LayoutKey(name: "Right", hid: 0x4f, index: 102, fnLocked: false),
]

/// Aliases accepted for physical keys (Mac-friendly names).
public let keyAliases: [String: String] = [
    "escape": "esc", "backtick": "grave", "tilde": "grave", "`": "grave",
    "-": "minus", "=": "equal", "[": "leftbracket", "]": "rightbracket", "\\": "backslash",
    ";": "semicolon", "'": "quote", ",": "comma", ".": "period", "/": "slash",
    "return": "enter", "del": "delete", "pgup": "pageup", "pgdn": "pagedown", "caps": "capslock",
    "leftcmd": "leftwin", "lcmd": "leftwin", "cmd": "leftwin", "lwin": "leftwin",
    "leftoption": "leftalt", "loption": "leftalt", "option": "leftalt", "lalt": "leftalt",
    "rightoption": "rightalt", "roption": "rightalt", "ralt": "rightalt",
    "lctrl": "leftctrl", "control": "leftctrl", "ctrl": "leftctrl", "rctrl": "rightctrl",
    "lshift": "leftshift", "shift": "leftshift", "rshift": "rightshift", "bksp": "backspace",
]

public func layoutKey(named raw: String) -> LayoutKey? {
    var n = raw.lowercased()
    if let a = keyAliases[n] { n = a }
    return layout.first { $0.name.lowercased() == n }
}

/// HID keyboard usages (page 0x07) accepted as remap targets and in macros.
public let hidUsages: [String: UInt8] = {
    var t: [String: UInt8] = [:]
    for (i, c) in "ABCDEFGHIJKLMNOPQRSTUVWXYZ".enumerated() { t[String(c).lowercased()] = UInt8(0x04 + i) }
    for (i, c) in "1234567890".enumerated() { t[String(c)] = UInt8(0x1e + i) }
    for i in 1...12 { t["f\(i)"] = UInt8(0x3a + i - 1) }
    for i in 13...24 { t["f\(i)"] = UInt8(0x68 + i - 13) }
    let named: [(String, UInt8)] = [
        ("enter", 0x28), ("esc", 0x29), ("backspace", 0x2a), ("tab", 0x2b), ("space", 0x2c),
        ("minus", 0x2d), ("equal", 0x2e), ("leftbracket", 0x2f), ("rightbracket", 0x30),
        ("backslash", 0x31), ("semicolon", 0x33), ("quote", 0x34), ("grave", 0x35),
        ("comma", 0x36), ("period", 0x37), ("slash", 0x38), ("capslock", 0x39),
        ("printscreen", 0x46), ("scrolllock", 0x47), ("pause", 0x48), ("insert", 0x49),
        ("home", 0x4a), ("pageup", 0x4b), ("delete", 0x4c), ("end", 0x4d), ("pagedown", 0x4e),
        ("right", 0x4f), ("left", 0x50), ("down", 0x51), ("up", 0x52), ("numlock", 0x53),
        ("kpslash", 0x54), ("kpasterisk", 0x55), ("kpminus", 0x56), ("kpplus", 0x57), ("kpenter", 0x58),
        ("kp1", 0x59), ("kp2", 0x5a), ("kp3", 0x5b), ("kp4", 0x5c), ("kp5", 0x5d),
        ("kp6", 0x5e), ("kp7", 0x5f), ("kp8", 0x60), ("kp9", 0x61), ("kp0", 0x62), ("kpdot", 0x63),
        ("iso", 0x64), ("menu", 0x65), ("application", 0x65),
        ("leftctrl", 0xe0), ("leftshift", 0xe1), ("leftalt", 0xe2), ("leftwin", 0xe3),
        ("rightctrl", 0xe4), ("rightshift", 0xe5), ("rightalt", 0xe6), ("rightwin", 0xe7),
    ]
    for (k, v) in named { t[k] = v }
    t["rightcmd"] = 0xe7; t["rcmd"] = 0xe7; t["rwin"] = 0xe7
    return t
}()

public func hidUsage(named raw: String) -> UInt8? {
    var n = raw.lowercased()
    if let a = keyAliases[n] { n = a }
    if let v = hidUsages[n] { return v }
    if n.hasPrefix("0x"), let v = UInt8(n.dropFirst(2), radix: 16) { return v }
    return nil
}

/// Modifier bits used in key-combo actions (HID boot modifier byte).
public let modifierBits: [String: UInt8] = [
    "ctrl": 0x01, "control": 0x01, "lctrl": 0x01, "leftctrl": 0x01,
    "shift": 0x02, "lshift": 0x02, "leftshift": 0x02,
    "alt": 0x04, "option": 0x04, "opt": 0x04, "lalt": 0x04, "leftalt": 0x04,
    "win": 0x08, "cmd": 0x08, "command": 0x08, "gui": 0x08, "lwin": 0x08, "leftwin": 0x08, "lcmd": 0x08,
    "rctrl": 0x10, "rightctrl": 0x10, "rshift": 0x20, "rightshift": 0x20,
    "ralt": 0x40, "rightalt": 0x40, "roption": 0x40, "rwin": 0x80, "rcmd": 0x80, "rightwin": 0x80,
]

/// HID consumer usages (page 0x0C), from the vendor app's tables (0x418866 and 0x419310).
public let consumerUsages: [String: UInt16] = [
    "playpause": 0xcd, "play": 0xcd, "stop": 0xb7, "prev": 0xb6, "previous": 0xb6, "next": 0xb5,
    "volup": 0xe9, "volumeup": 0xe9, "voldown": 0xea, "volumedown": 0xea, "mute": 0xe2,
    "calculator": 0x192, "mail": 0x18a, "mediaplayer": 0x183, "mycomputer": 0x194,
    "browserhome": 0x223, "browsersearch": 0x221, "browserback": 0x224, "browserforward": 0x225,
    "browserstop": 0x226, "browserrefresh": 0x227, "browserfavorites": 0x22a,
]

public let lightModes: [(Int, String)] = [
    (0, "off"), (1, "static"), (2, "singleon"), (3, "singleoff"), (4, "glittering"),
    (5, "falling"), (6, "colourful"), (7, "breath"), (8, "spectrum"), (9, "outward"),
    (10, "scrolling"), (11, "rolling"), (12, "rotating"), (13, "explode"), (14, "launch"),
    (15, "ripples"), (16, "flowing"), (17, "pulsating"), (18, "tilt"), (19, "shuttle"),
]
