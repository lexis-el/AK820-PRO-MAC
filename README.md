# AK820 Pro for macOS: app and command-line tool

A native macOS app (**AK820 Pro.app**, SwiftUI) and command-line tool (`ak820`), written in Swift
with IOKit HID and no dependencies. Together they replace the Windows-only vendor driver *AJAZZ AK820 Pro Triple-mode 0.85" Screen RGB v1.0.0.5* for the main features:
lighting, per-key colours, key remapping, macros, the 0.85" screen (pictures, GIFs, clock), and
system settings.

The protocol was reverse engineered from the vendor software by static analysis only. See
[PROTOCOL.md](PROTOCOL.md).

This is an unofficial project, not made by or affiliated with AJAZZ. "AJAZZ" and "AK820" are used only to say
which keyboard it works with, and the app icon is the AJAZZ logo. AJAZZ's trademarks belong to AJAZZ.

## Download

Get `AK820-Pro-<version>.zip` from the **Releases** page, unzip it and drag **AK820 Pro.app** to Applications.

The app isn't notarized by Apple (that needs a paid developer account), so the first time macOS will say it
can't check it for malware. To open it anyway: open the app once, then go to **System Settings → Privacy & Security**,
scroll down and click **Open Anyway**. Or, in Terminal:

```bash
xattr -dr com.apple.quarantine "/Applications/AK820 Pro.app"
```

The command-line tool is inside the app at `AK820 Pro.app/Contents/Resources/ak820`. You can also build both from
source (below).

## Requirements

- macOS 13 or later, Apple Silicon or Intel
- Xcode Command Line Tools (`xcode-select --install`), for `swift`
- The keyboard connected **with the USB cable, in wired mode**. As with the vendor's app,
  configuration doesn't work over Bluetooth, and 2.4 GHz dongle mode isn't implemented yet.

## The app

```bash
scripts/make-app.sh --install
```

This builds `build.noindex/AK820 Pro.app` and copies it to `~/Applications`. Open it from Launchpad or
Spotlight ("AK820"). The app has panes for **Lighting**, **Key Colours** (click keys on a picture of the
keyboard and paint them), **Screen** (choose a picture or GIF, preview it animated, upload it, restore the
factory animation, sync the clock), **Key Mapping** (base and Fn layer), **Macros** and **Settings**. The status
bar shows whether the keyboard is connected over USB.

A build from source is signed ad hoc for your own Mac. The app remembers the key map and
macros you made, because the keyboard can't report them back. `"AK820 Pro" --selftest` runs a quick hardware check from
Terminal; it only reads the key colours and syncs the clock, so it never changes your settings.

It builds with only the Command Line Tools; no Xcode project is needed. The icon is the AJAZZ logo in `assets/AppIcon-source.png`; to change it, run `scripts/icon-from-image.sh <square.png>` (or `swift scripts/make-icon.swift` for a drawn keyboard icon).

**Restore Factory Animation**: the factory screen animation belongs to AJAZZ, so it isn't included. The button asks
you for the GIF from your own copy of the vendor software. If you build from source, put it at
`assets/factory-boot.gif` and the app bundles it.

## The command-line tool

```bash
swift build -c release --product ak820
```

The binary is `.build/release/ak820` (the app bundle also carries a copy in `Contents/Resources/ak820`). To put it on your PATH:

```bash
cp .build/release/ak820 ~/.local/bin/
```

If macOS refuses to open the keyboard (`kIOReturnNotPermitted`), give your terminal app
**Input Monitoring** permission (System Settings → Privacy & Security → Input Monitoring) and run
the command again.

## Usage

Every write command accepts `--dry-run`, which prints the exact packets without touching the
keyboard, and `--verbose`, which logs the traffic.

```bash
ak820 list                                  # HID interfaces of the keyboard (read-only)
ak820 read-colors                           # per-key colour table (read-only)
ak820 modes                                 # lighting mode names

ak820 light rolling --rainbow               # vendor default
ak820 light static --color 00AAFF --brightness 4
ak820 light breath --color FF00FF --speed 2
ak820 light off

ak820 key-colors --all 202020               # every key one colour (user-lighting mode)
ak820 key-colors examples/key-colors.json   # per key

ak820 clock                                 # set the screen clock to this Mac's time
ak820 screen ~/Pictures/cat.gif             # animated GIF (≤140 frames, cropped to 128×128)
ak820 screen logo.png --fit                 # letterbox instead of crop
ak820 screen-preview cat.gif /tmp/out.png   # check the conversion without a keyboard
ak820 screen assets/factory-boot.gif        # put back the factory animation

ak820 remap examples/remap-mac.json         # base layer (unlisted keys go back to default)
ak820 remap fn-layer.json --fn              # Fn layer
ak820 remap /dev/stdin <<< '{}'             # reset the base layer to defaults

ak820 macros examples/macros.json
ak820 settings --sleep 1 --response 2 --disable-win
```

### Remap file

A JSON object mapping a physical key to an action:

```json
{
  "CapsLock": "LeftCtrl",
  "LeftWin":  "LeftAlt",
  "LeftAlt":  "LeftWin",
  "F1":       "media:playpause",
  "F2":       "cmd+shift+4",
  "F3":       "mouse:back",
  "F4":       "disable",
  "PageDown": "macro:0"
}
```

- Physical key names: `Esc F1…F12 Delete Grave 1…0 Minus Equal Backspace Home Tab Q…P LeftBracket
  RightBracket Backslash PageUp CapsLock A…L Semicolon Quote Enter PageDown LeftShift Z…M Comma
  Period Slash RightShift Up LeftCtrl LeftWin LeftAlt Space RightAlt Fn RightCtrl Left Down Right`
  (aliases such as `cmd`, `option`, `return`, `pgup` also work). `Fn` can't be remapped.
- Actions:
  - a key name or HID usage (`0x2a`)
  - a combo, e.g. `ctrl+alt+delete` or `cmd+space`. Modifiers: `ctrl shift alt/option cmd/win`, with an `r` prefix for the right-hand ones.
  - `media:` followed by `playpause stop prev next volup voldown mute calculator mail mediaplayer mycomputer browserhome browsersearch browserback browserforward browserstop browserrefresh browserfavorites`
  - `mouse:` followed by `left right middle back forward doubleclick wheelup wheeldown`
  - `macro:N` (optionally `macro:N:mode:repeat`)
  - `disable` or `default`
- On the Mac the keyboard's Win key is Command and Alt is Option, so swapping them gives the Mac layout.

### Macro file

An array of macros (slot 0, 1, …). Each macro is a list of steps: `tap:K`, `down:K`, `up:K`,
`mousedown:left`, `mouseup:right`. A number sets the delay in ms after the previous step
(default and minimum 10 ms).

```json
[
  ["tap:H", "tap:I", 50, "down:LeftShift", "tap:1", "up:LeftShift"]
]
```

### Per-key colour file

```json
{ "Esc": "FF0000", "W": "00FFFF", "A": "00FFFF", "S": "00FFFF", "D": "00FFFF" }
```

## Status

Tested on 2026-10-23 with the author's keyboard on USB (PID 0x800A, macOS 27, Apple Silicon):

| Feature | Implemented | Tested on hardware |
|---|---|---|
| Detect keyboard / list interfaces | ✅ | ✅ USB and Bluetooth (Bluetooth is correctly reported as not configurable) |
| Read per-key colours (`0xF5`, read-only) | ✅ | ✅ |
| Lighting mode / colour / brightness | ✅ | ✅ static colour, verified by reading colours back |
| Lighting speed / direction / other modes | ✅ | ⚠️ sent the same way as above; not tried one by one |
| Per-key colours (user lighting) | ✅ | ✅ verified by read-back |
| Screen clock sync | ✅ | ✅ (correct time shown) |
| Screen picture / GIF upload | ✅ | ✅ orientation and colours correct; 132-frame GIF in about 2 min |
| Key remapping (base layer) | ✅ | ✅ (media key + macro key, then reset to defaults) |
| Key remapping (Fn layer) | ✅ | ❌ not tried |
| Macros | ✅ | ✅ |
| System settings (sleep, debounce, Win lock, …) | ✅ (value meanings partly guessed) | ❌ not tried |
| Real-time per-key streaming (`0x20`: music/ambilight effects) | protocol documented, no CLI | ❌ |
| 2.4 GHz dongle mode | ❌ (transport documented, command set not decoded) | ❌ |
| Bluetooth configuration | ❌ (the vendor app doesn't support it either) | – |
| PC-side key actions (open app / website / send text) | ❌ (needs a background helper) | – |
| Firmware update | ❌ (the vendor package contains no firmware) | – |

The app runs the same library code. Its background-queue I/O was checked with `--selftest` (read colours, lighting,
full screen upload), and its panes were clicked through by hand.

Every write ends with the keyboard reporting a 16-bit checksum of the data it received (reply to
`04 02`), and the tool checks it. Light, per-key colour, remap and macro writes all passed.

All write commands were checked with `--dry-run` against the byte layouts decoded from the vendor app.

## Files

- `Sources/AK820Core/`: shared library (`HID.swift` IOKit layer, `Keyboard.swift` protocol, `Layout.swift` key table, `Actions.swift` remap/macro parsing, `Image.swift` screen conversion)
- `Sources/ak820/`: the command-line tool
- `Sources/AK820App/`: the SwiftUI app (`KeyGeometry.swift` key positions come from the vendor layout)
- `scripts/make-app.sh`: builds and installs the .app; the icon is `assets/AppIcon-source.png` (made into `AppIcon.icns` by `scripts/icon-from-image.sh`; `scripts/make-icon.swift` draws an alternative); `scripts/shoot-panes.sh` screenshots every pane (`--pane <name>` opens one) for layout checks
- `PROTOCOL.md`: the reverse-engineered protocol
- `examples/`: sample remap, macro and per-key colour files
- `assets/test-quadrants.png`: the orientation test pattern

## Log file (for bug reports)

The app and the CLI both write to **`~/Library/Logs/AK820/ak820.log`**: each operation, every packet sent to and
received from the keyboard, the transfer checksums, and any error. Screen uploads get one line per 4 KB page. At
2 MB the file moves to `ak820.log.1`.

- In the app: **Help → Show Log in Finder** (or **Copy Log Path**). When something fails, the status bar also shows a **Show Log** button.
- In Terminal: `ak820 log` prints the path, `ak820 log --show` prints the last 200 lines, `ak820 log --reveal` shows it in Finder.

To report a bug, attach the log, or just the lines around the error. The log contains what you sent to the
keyboard, including your macro keystrokes, so check it first if a macro holds anything private.

## Showing your picture in wireless mode (Bluetooth / 2.4 GHz)

Uploaded pictures are stored on the keyboard. In wireless mode the screen starts on the clock/status page, but you can
switch it to your picture on the keyboard itself (confirmed on the keyboard, 2026-10-23):

1. Hold **Fn** and **press the knob**. The keyboard flashes red: you're in the screen menu.
2. Hold **Fn** and **turn the knob** to step through the menu pages. The last page shows the picture you uploaded.
3. On that page, hold **Fn** and **press the knob** again to save. The keyboard flashes red again.

The upload itself has to be done over USB (neither this app nor the vendor's can send anything over Bluetooth).

## Safety notes

- None of the commands writes firmware. Everything is stored configuration that the next command,
  or the keyboard's own Fn lighting shortcuts, can change again.
- `remap` and `macros` replace the whole layer or macro table, like the vendor app does. Run
  `ak820 remap /dev/stdin <<< '{}'` to return the base layer to defaults.

## License

MIT. See [LICENSE](LICENSE).
