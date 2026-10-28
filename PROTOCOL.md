# AJAZZ AK820 Pro (triple-mode, 0.85" screen, RGB): configuration protocol

Reverse engineered from the vendor's Windows driver
`AJAZZ_AK820_Pro_Triple_mode_0.85inch_Screen_RGB_V1.0.0.5` (Inno Setup 6.1 installer →
`DeviceDriver.exe`, MFC, 32-bit; GUI in `mui.dll`). The analysis was static only: the
installer was unpacked with a custom extractor and the code was disassembled. Nothing
from the package was ever run.

Confidence tags used below:

- **[C] Confirmed**: read directly from the disassembly (byte offsets, constants, order of calls).
- **[I] Inferred**: the code shows the bytes, but their *meaning* comes from UI strings, DB column
  names or context.
- **[G] Guess**: plausible, not proven by the code.
- **[T] Tested**: checked on real hardware (an AK820 Pro, USB PID 0x800A) with the macOS tool on 2026-10-23.

Code addresses (`0x4xxxxx`) refer to `DeviceDriver.exe` (image base 0x400000), so anyone
can re-check them.

---

## 1. Devices and interfaces

From `config.xml` **[C]**:

| Mode | VID | PID | Windows interface string |
|---|---|---|---|
| USB (wired) | 0x0C45 | 0x8009 | `VID_0C45&PID_8009&MI_00` |
| USB (wired) | 0x0C45 | 0x800A | `VID_0C45&PID_800A&MI_00` |
| 2.4 GHz dongle | 0x0C45 | 0xFDFD | `VID_0C45&PID_FDFD&MI_03` |

On a Mac the keyboard pairs over Bluetooth LE as VID 0x0C45 / PID 0xFEFE. The vendor app
refuses to configure over Bluetooth (language string 62: "keyboard settings are not supported
in Bluetooth mode") **[C]**.

The app uses the bundled signal11 **hidapi** (Windows backend, `hid.dll` loaded at run time,
`0x450a70`) **[C]**. When it opens the device (`0x44fa70`), it walks `hid_enumerate()` and sorts
each interface by its report sizes **[C]**:

| hidapi test | Role | Stored at |
|---|---|---|
| `feature_report_length == 0x41` (64 bytes plus report ID 0) | **command channel** (wired) | `dev+0x00` |
| `output_report_length == 0x21 && input_report_length == 0x21` (32 bytes + ID) | **dongle channel** (2.4 GHz) | `dev+0x00` |
| `usage_page == 0xFFFF && usage == 0x0001` | event listener (PC-side key actions) [I] | `dev+0x28` |
| `output_report_length == 0x1001` (4096 bytes + ID) | **bulk channel** (screen images) | `dev+0x2c` |

On macOS (USB, PID 0x800A) the interfaces show up as **[T]**:

| Usage page:usage | in / out / feature bytes | Role |
|---|---|---|
| 0x0001:0x0006 | 8 / 1 / 0 | boot keyboard |
| 0x000C:0x0001 | 16 / 1 / 1 | consumer control |
| **0xFF13:0x0001** | 64 / 64 / **64** | **command channel** |
| **0xFF68:0x0061** | 64 / **4096** / 0 | **screen data channel** |

All reports use **report ID 0** (no report ID byte on the wire) **[C][T]**. On macOS this means
`IOHIDDeviceSetReport(..., reportID: 0, 64 bytes)`.

## 2. Wired command transport

### 2.1 Primitive: `send(packet, ack)`: `0x44eed0` **[C]**

1. `Sleep(cmd_delay)`. `cmd_delay` is `dev+0x30`; layout XML sets `<cmd_delaytime value="35"/>`, so 35 ms **[I]**.
2. `HidD_SetFeature` with 64-byte payload (hidapi buffer = `00` + payload).
3. If `ack`: `Sleep(cmd_delay)`, `HidD_GetFeature` 64 bytes, success when **reply byte [3] == 0x01**.
   The reply echoes the command (`04 CC 00 01 ...`) **[T]**. For a *data* page sent with ack (clock), the
   reply is just an echo of the data, without the 0x01; the vendor app ignores it.

**Transfer checksum [T]** (not used by the vendor app): the reply to `04 02` (end) carries a
**16-bit little-endian sum of all data bytes** received since the command header in bytes 4–5.
For example, after a lighting page `01 00 AA FF ... 05 03 ... AA 55`, the reply is `04 02 00 01 B1 02`, and
0x02B1 is the byte sum of that page. Confirmed for lighting, user lighting, key map and macros. The
clock and screen uploads report 0.

Payloads longer than 64 bytes are sent as consecutive 64-byte feature reports, with
`Sleep(cmd_delay)` after each one and up to 10 retries per chunk. No ack is read for multi-chunk data **[C]**.

A faster variant (`0x44f0c0`, used for real-time lighting) uses 5 ms sleeps. It re-sends once if
reply[3] == 0xFF (busy), and gives up on data chunks after 100 ms **[C]**.

### 2.2 Framing **[C]**

- **Command packet**: `04 CC 00 00 00 00 00 00 NN 00 ...` (64 bytes). `CC` = command. `NN` (byte 8) is
  the number of 64-byte data pages that follow (byte 8–9 little-endian for the screen upload).
- **Data pages** follow with no header. Most data blocks end with the marker **`AA 55`** in their last
  two bytes (offset 0x0E for 16-byte light records, 0x3E for single 64-byte pages, 0x23E for
  576-byte blocks).
- Most write transactions are wrapped:

```
04 18            begin           (ack)
04 CC .. NN      command header  (ack)
<data pages>                    (no ack)
04 02            end             (ack)
04 F0            "commit" [G]    (no ack; only after light / keymap / user-light writes)
```

### 2.3 Command table

| CC | Purpose | Wrapped by 18/02 | Data | Source | Conf. |
|---|---|---|---|---|---|
| 0x02 | end of transaction | – | – | everywhere | C |
| 0x11 | key map, base layer | yes (+F0) | 9 pages (0x240 B) | `0x418420` | C, T |
| 0x13 | lighting mode | yes (+F0) | 1 page | `0x42b100` | C, T |
| 0x15 | macro data | after 0x19 | N pages | `0x42d6f0` | C, T |
| 0x17 | system settings | yes | 1 page | `0x414060` | C |
| 0x18 | begin transaction | – | – | everywhere | C |
| 0x19 | begin macro upload | – | – | `0x42d6f0` | C (meaning I) |
| 0x20 | real-time per-key RGB (streaming) | no (02 only) | 8 pages | `0x4329e0`, `0x427e10` | C |
| 0x23 | user lighting (stored per-key RGB) | yes (+F0) | 9 pages | `0x44ba10` | C, T |
| 0x27 | key map, Fn layer | yes (+F0) | 9 pages | `0x418420` | C |
| 0x28 | screen clock / time sync | yes | 1 page | `0x423940` | C, T |
| 0x72 | screen image/GIF upload | yes | via bulk channel | `0x422980` | C, T |
| 0xF0 | commit / exit [G] | – | – | after 0x02 | C (meaning G) |
| 0xF5 | **read** per-key RGB | no (02 after) | 9 pages read back | `0x42aee0` | C, T |

No firmware-update, factory-reset or "read firmware version" command exists in this build. The
`firmware\` folder ships empty and `<firmware version="" file="" url=""/>`. The UI's "Reset
keyboard" button re-uploads the default profile through the commands above (`0x434fa0`) [I].

## 3. Lighting (`04 13`)

Sequence **[C]** (`0x42b100`): `04 18`(ack) → `04 13 00 00 00 00 00 00 01`(ack) → data → `04 02`(ack) → `04 F0`.

Data page (64 bytes, rest zero) **[C]** (field meaning **[I]** from DB columns of `t_light_data`):

| Offset | Field |
|---|---|
| 0 | mode |
| 1, 2, 3 | R, G, B (only filled when mode ≠ 0) |
| 8 | colorful / rainbow flag (1 = multicolour) |
| 9 | brightness (0–5, `brightness_max=5`) |
| 10 | speed (0–5, `speed_max=5`) |
| 11 | direction |
| 14, 15 | `AA 55` |

Modes (`0x42b3b0`, default rows) **[C]**. The `config` value is a bitmask of which UI controls
apply **[I]**:

| mode | name | config |  | mode | name | config |
|---|---|---|---|---|---|---|
| 0 | LED off | 0x00 | | 10 | Scrolling | 0x3B |
| 1 | Static | 0x31 | | 11 | Rolling (default) | 0x37 |
| 2 | SingleOn | 0x33 | | 12 | Rotating | 0x37 |
| 3 | SingleOff | 0x33 | | 13 | Explode | 0x33 |
| 4 | Glittering | 0x33 | | 14 | Launch | 0x33 |
| 5 | Falling | 0x33 | | 15 | Ripples | 0x33 |
| 6 | Colourful | 0x03 | | 16 | Flowing | 0x37 |
| 7 | Breath | 0x33 | | 17 | Pulsating | 0x33 |
| 8 | Spectrum | 0x03 | | 18 | Tilt | 0x37 |
| 9 | Outward | 0x33 | | 19 | Shuttle | 0x33 |
| 0x80 | user lighting (per-key, see §5) | | | | | |

Defaults: mode 11, brightness 5, speed 3, colour 0x0000FF (BGR, i.e. red), rainbow on **[C]** (layout XML + `0x5751c0`).
Config bit meaning **[G]**: 0x01 brightness, 0x02 speed, 0x04 direction, 0x08 (scrolling-only), 0x10 colour, 0x20 rainbow.
Direction value range **[G]**: 0..3.

## 4. Real-time per-key RGB (`04 20`)

`0x4329e0` **[C]**: no begin. `04 20 .. [8]=8` (fast send, ack) → **512 bytes** (8 pages) → `04 02`.
Each lit key gets a 4-byte record `[light_index, R, G, B]`, packed in key-list order. Keys not
present are left out. The block has no `AA 55` marker. (When the keyboard isn't RGB, `[8]=3` and a
192-byte on/off map with 0xFD per lit key is used instead.)

## 5. User lighting, stored (`04 23`)

`0x44ba10` **[C]**:
1. Set lighting mode **0x80** with `04 13` (§3; data `[0]=0x80, [9]=brightness`, `AA 55` at 14) (`0x44b900`).
2. `04 18` → `04 23 .. [8]=9` → **576 bytes**: record at `light_index*4` = `[light_index, R, G, B]`, `AA 55` at 0x23E → `04 02` → `04 F0`.

## 6. Read per-key colours (`04 F5`), read-only

`0x42aee0`, `0x44f3a0` **[C]**: send `04 F5 .. [8]=9`, sleep 5 ms, get feature (retry ≤10, success when reply[3]==1),
then **9 × GetFeature**, each giving 64 bytes → 576-byte block in the same layout as §5 **[T]**.
The colours read back are the LED values after the firmware's own scaling (e.g. `00AAFF` reads back as `00A7FB`,
`FF0000` as `A70000`), and with an animated mode you get a snapshot of the current frame.
The app then sends `04 02` (ack). This is the safest command for testing on hardware.

## 7. Key remapping (`04 11` base layer, `04 27` Fn layer)

`0x418420` **[C]**: `04 18` → `04 11|27 .. [8]=9` → **576-byte** block → `04 02` → `04 F0`.
The record for each key is at `key_index*4` (key_index from the layout XML, see table in
`Sources/ak820/Layout.swift`). `AA 55` goes at 0x23E. A record of all zeros = the key's default
function. The app always sends the whole layer, so keys you don't specify go back to default.

Action records (4 bytes) **[C]** (meaning **[I]** from UI strings):

| Action | Bytes |
|---|---|
| default | `00 00 00 00` |
| disabled | `05 03 00 00` |
| key / combo | `02 MM KK 00`: MM = modifier mask (01 LCtrl, 02 LShift, 04 LAlt, 08 LGUI, 10 RCtrl, 20 RShift, 40 RAlt, 80 RGUI), KK = HID usage. A lone modifier is `02 bit 00 00`. |
| mouse button | `01 01 BB 00`: BB = 01 left, 02 right, 04 middle, 08 button 4, 10 button 5 (`01 01 03` = "double click") |
| mouse wheel | `01 03 01 00` (up), `01 03 FF 00` (down) |
| consumer (media) | `03 LO HI 00`: 16-bit HID consumer usage (CD play/pause, B7 stop, B6 prev, B5 next, E9 vol+, EA vol−, E2 mute, 0192 calculator, 018A mail, 0183 media player, 0194 my computer, 0223 WWW home, 0221 search, 0224 back, 0225 forward, 0226 stop, 0227 refresh, 022A favourites) |
| macro | `06 IDX MODE REPEAT`: IDX = macro slot (0-based), MODE/REPEAT from the macro's play settings (exact MODE values **[G]**) |
| type 0x0D ("multi-key"?) | `07 v1 v2 v3` **[G]** |
| PC-side action (open program / website / send text) | `05 02 NN 00`: handled by the Windows driver listening on the 0xFFFF interface; useless without that driver **[I]** |

Keys flagged `fnlayer_disable="1"` in the layout (Esc, Backspace, `|\`, Home, Win_L, Fn) can't be
changed on the Fn layer **[C]** (layout XML).

## 8. Macros (`04 19`, `04 15`)

`0x42d6f0` **[C]**:
1. `04 19`(ack). No `04 18`.
2. Build a buffer (max 0xE00 bytes):
   - **Directory** at 0x000: 100 entries × 4 bytes. Entry = `u16 offset` (little-endian) of the macro's block, upper two bytes 0.
     An empty macro has `FF FF FF FF`.
   - First block starts at **0x190**. Block = `u16 count` + 6 zero bytes, then `count` × 4-byte events:
     - key down `00 00 KK B0`, key up `00 00 KK 30` (KK = HID usage; the app converts from Windows VK)
     - mouse down `00 00 BB 90`, mouse up `00 00 BB 10` (BB: 01 left, 04 middle, 02 right)
     - delay `LO HI 00 50` (ms, little-endian; the app always writes one delay after every key/mouse event, minimum 10 ms)
   - Next block offset = `offset + 8 + count*4`.
3. `pages = ceil(len/64)` (+1 when `len` is an exact multiple of 64). Put `AA 55` in the last 2 bytes of `pages*64`.
4. `04 15 .. [8]=pages`(ack), sleep 30 ms, send `pages*64` bytes, then `04 02`(ack).

## 9. System settings (`04 17`)

`0x414060` **[C]**: `04 18` → `04 17 00 01 00 00 00 00 01`(ack) → data → `04 02`(ack).

| Offset | Value | Conf. |
|---|---|---|
| 0, 1 | `00 01` | C |
| 2 | disable Alt+Tab (checkbox) | C (meaning I) |
| 3 | disable Alt+F4 | C (meaning I) |
| 4 | disable Windows key | C (meaning I) |
| 5 | `fn_switch` | C (values G) |
| 6 | `sleep_time` (combobox item data; UI: no sleep / 1 / 5 / 30 min) | C (values G: 0..3) |
| 8 | `key_respondtime` (debounce level 1–5) | C (values G) |
| 62, 63 | `AA 55` | C |

## 10. Screen (0.85", 128 × 128)

Layout XML: `<screen gif_headlength="256" gif_maxframes="140" gif_count="1" width="128" height="128"/>` **[C]**.

### 10.1 Image / animation upload (`04 72`), `0x422980` **[C]**

Buffer (filled with `FF` first):

```
0x000  u8  frame_count (≤ 140)
0x001  u8  delay[i] = max(1, delay_ms / 2)   for each frame (units of 2 ms; UI allows 30–500 ms)
...    FF padding up to 0x100
0x100  frame 0: 128*128 pixels RGB565, little-endian, row-major from top-left
       frame 1 ...
```

RGB565 conversion (`mui.dll 0x1003c6a0`) **[C]**: `v = (R & 0xF8) << 8 | (G & 0xFC) << 3 | B >> 3`, low byte first.
Row order top-down, left to right **[T]** (a quadrant test pattern showed up correctly).

Sequence:
1. `04 18`(ack)
2. `04 72 SS 00 00 00 00 00 PL PH`(ack): SS = slot (1-based; only 1 exists), PL/PH = number of **4096-byte** pages (little-endian), `pages = ceil(len/4096)`
3. For each page: **output report** of 4096 bytes on the bulk interface, then read an input report (300 ms timeout; the reply isn't checked)
4. `04 02`(ack)

### 10.2 Clock (`04 28`), `0x423940` **[C]**

`04 18` → `04 28 .. [8]=1`(ack) → data(ack) → `04 02`(ack). Data:

| Off | Value |
|---|---|
| 0 | 0 |
| 1 | slot (1-based, from the screen list) |
| 2 | 0x5A |
| 3 | year − 2000 (`wYear % 2000`) |
| 4 | month |
| 5 | day |
| 6 | hour |
| 7 | minute |
| 8 | second |
| 9 | 0 |
| 10 | day of week (0 = Sunday) |
| 62, 63 | `AA 55` |

## 11. 2.4 GHz dongle transport (not implemented in the macOS tool)

`0x44f5f0` / `0x44f790` **[C]**: 32-byte **output** reports (report ID 0). Byte 31 (`payload[0x20]` in the app's
65-byte buffer) = 8-bit sum of the first N bytes. The app retries reads (input, 32 bytes, 5 ms timeout, up to 20×) until
bytes 0..2 of the reply echo the request. Dongle probe: payload[0] = 0x02, reply[0] must be 0x02. The command set over
the dongle is a different encoding (`0x418cc0`, `0x419000`, `0x423220`, ...) and hasn't been decoded.

## 12. Host-side features (no keyboard protocol)

Music rhythm, "Ambilight" and screen-capture lighting are computed on the PC and streamed with `04 20` (§4).
Disabling Alt+Tab etc. is also a firmware flag (§9). Profiles are stored in a local SQLite DB (`db\<name>_datav1.db`).
