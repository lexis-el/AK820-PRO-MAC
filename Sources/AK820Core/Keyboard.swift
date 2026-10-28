import Foundation

public let vendorID = 0x0C45
public let wiredPIDs = [0x8009, 0x800A]
public let donglePID = 0xFDFD
public let bluetoothPID = 0xFEFE

/// Wired AK820 Pro. See PROTOCOL.md for the byte layouts; section numbers are noted below.
public final class Keyboard {
    public let cmdIF: HIDInterface?       // 64-byte feature reports; nil = dry run (print packets only)
    public let bulk: HIDInterface?        // 4096-byte output reports (screen data)
    public var delay: TimeInterval = 0.035  // <cmd_delaytime value="35"/>
    public var verbose = false

    public var dryRun: Bool { cmdIF == nil }

    public init(command: HIDInterface?, bulk: HIDInterface?) {
        self.cmdIF = command
        self.bulk = bulk
    }

    public static func find() throws -> Keyboard {
        let all = HIDEnumerator.interfaces(vendorID: vendorID)
        let wired = all.filter { wiredPIDs.contains($0.productID) }
        guard let cmd = wired.first(where: { $0.maxFeature == 64 || $0.maxFeature == 65 }) else {
            if all.contains(where: { $0.productID == bluetoothPID }) {
                throw HIDError("The keyboard is only connected over Bluetooth. The vendor protocol doesn't work over Bluetooth: connect the USB cable (and switch the keyboard to wired mode).")
            }
            if all.contains(where: { $0.productID == donglePID }) {
                throw HIDError("Only the 2.4 GHz dongle was found. Dongle mode isn't supported yet: connect the USB cable.")
            }
            DiagLog.info("no wired keyboard; HID devices with VID 0C45: " + (all.isEmpty ? "none" : all.map { String(format: "%04X page %04X:%04X (%@)", $0.productID, $0.usagePage, $0.usage, $0.transport) }.joined(separator: "; ")))
            throw HIDError("No AK820 Pro found on USB (VID 0C45, PID 8009/800A). Connect the USB cable and put the keyboard in wired mode.")
        }
        let bulk = wired.first(where: { $0.maxOutput == 4096 || $0.maxOutput == 4097 })
        DiagLog.info("keyboard found: " + wired.map { String(format: "%04X:%04X page %04X:%04X in/out/feat %d/%d/%d", $0.vendorID, $0.productID, $0.usagePage, $0.usage, $0.maxInput, $0.maxOutput, $0.maxFeature) }.joined(separator: "; "))
        try cmd.open()
        try bulk?.open()
        return Keyboard(command: cmd, bulk: bulk)
    }

    // MARK: transport (PROTOCOL.md §2)

    /// Note for the diagnostic log (and stderr with --verbose).
    private func log(_ s: @autoclosure () -> String) {
        let line = s()
        if !dryRun { DiagLog.info(line) }
        if verbose { FileHandle.standardError.write((line + "\n").data(using: .utf8)!) }
    }
    /// A packet for the diagnostic log (full, trailing zeros trimmed) and stderr with --verbose (first 16 bytes).
    private func trace(_ dir: String, _ b: [UInt8], channel: String = "feature") {
        if !dryRun { DiagLog.packet(dir, b, channel: channel) }
        if verbose { FileHandle.standardError.write((dir + " " + hex(Array(b.prefix(16))) + "\n").data(using: .utf8)!) }
    }
    private func hex(_ b: [UInt8]) -> String { b.map { String(format: "%02x", $0) }.joined(separator: " ") }

    public static func pad(_ b: [UInt8], to n: Int = 64, fill: UInt8 = 0) -> [UInt8] {
        b.count >= n ? Array(b.prefix(n)) : b + [UInt8](repeating: fill, count: n - b.count)
    }

    /// Sum of the data bytes sent since the last command header. The keyboard echoes this
    /// 16-bit sum in bytes 4-5 of its reply to `04 02`, which lets end() verify the transfer.
    private var dataSum = 0

    /// Send one 64-byte packet; with `ack`, read the reply (the keyboard sets byte 3 to 1 on success).
    @discardableResult
    public func exchange(_ packet: [UInt8], ack: Bool) throws -> [UInt8]? {
        let p = Keyboard.pad(packet)
        guard let cmdIF = cmdIF else {
            var n = p.count
            while n > 2 && p[n - 1] == 0 { n -= 1 }
            print("feature\(ack ? " +ack" : "     "): " + hex(Array(p.prefix(n))))
            return ack ? Keyboard.pad([p[0], p[1], 0, 1]) : nil
        }
        Thread.sleep(forTimeInterval: delay)
        trace(">", p)
        do { try cmdIF.setFeature(p) } catch { log("send failed: \(error)"); throw error }
        guard ack else { return nil }
        Thread.sleep(forTimeInterval: delay)
        let r: [UInt8]
        do { r = try cmdIF.getFeature(length: 64) } catch { log("read failed: \(error)"); throw error }
        trace("<", r)
        return r
    }

    @discardableResult
    public func send(_ packet: [UInt8], ack: Bool) throws -> Bool {
        guard let r = try exchange(packet, ack: ack) else { return true }
        return r.count > 3 && r[3] == 0x01
    }

    /// Send a data packet (counted in the transfer checksum). The keyboard echoes data packets
    /// instead of acking them, so with `ack` the reply is read but not checked (like the vendor app).
    public func data(_ packet: [UInt8], ack: Bool = false) throws {
        let p = Keyboard.pad(packet)
        dataSum += p.reduce(0) { $0 + Int($1) }
        try exchange(p, ack: ack)
    }

    /// Send a command header and require an ack.
    public func command(_ cmd: UInt8, pages: Int = 0, extra: [Int: UInt8] = [:]) throws {
        var p = [UInt8](repeating: 0, count: 64)
        p[0] = 0x04; p[1] = cmd; p[8] = UInt8(pages & 0xff)
        for (k, v) in extra { p[k] = v }
        dataSum = 0
        if !(try send(p, ack: true)) {
            log(String(format: "no ack for command 0x%02X", cmd))
            throw HIDError(String(format: "The keyboard didn't acknowledge command 0x%02X", cmd))
        }
    }

    /// Send a data block as consecutive 64-byte feature reports.
    public func sendData(_ data: [UInt8]) throws {
        precondition(data.count % 64 == 0)
        for off in stride(from: 0, to: data.count, by: 64) {
            let chunk = Array(data[off..<off + 64])
            var tries = 0
            while true {
                do { try self.data(chunk); break } catch {
                    tries += 1
                    if tries >= 10 { throw error }
                }
            }
        }
    }

    public func begin() throws { try command(0x18) }
    /// End the transaction and check the keyboard's checksum of the data it received.
    public func end() throws {
        let expected = dataSum & 0xffff
        guard let r = try exchange([0x04, 0x02], ack: true), r.count > 5, r[3] == 0x01 else {
            throw HIDError("The keyboard didn't acknowledge command 0x02")
        }
        dataSum = 0
        guard !dryRun, expected != 0 else { return }
        let got = Int(r[4]) | Int(r[5]) << 8
        // Some commands (e.g. the clock) don't report a checksum: bytes 4-5 stay 0.
        if got == 0 { log("no checksum reported"); return }
        if got != expected {
            log(String(format: "checksum MISMATCH: keyboard 0x%04X, expected 0x%04X", got, expected))
            throw HIDError(String(format: "Transfer checksum mismatch: the keyboard received data summing to 0x%04X, expected 0x%04X. Run the command again.", got, expected))
        }
        log(String(format: "checksum ok (0x%04X)", got))
    }
    public func commit() throws { try send([0x04, 0xF0], ack: false) }

    // MARK: lighting (§3)

    public func setLighting(mode: UInt8, r: UInt8, g: UInt8, b: UInt8, rainbow: Bool,
                     brightness: UInt8, speed: UInt8, direction: UInt8) throws {
        try begin()
        try command(0x13, pages: 1)
        var d = [UInt8](repeating: 0, count: 64)
        d[0] = mode
        if mode != 0 { d[1] = r; d[2] = g; d[3] = b }
        d[8] = rainbow ? 1 : 0
        d[9] = brightness; d[10] = speed; d[11] = direction
        d[14] = 0xAA; d[15] = 0x55
        try data(d)
        try end()
        try commit()
    }

    // MARK: per-key colours (§5, §6)

    /// Read the 576-byte per-key colour block (command 0xF5). Read-only.
    public func readKeyColors() throws -> [UInt8] {
        guard let cmdIF = cmdIF else { throw HIDError("read-colors needs a connected keyboard") }
        var p = [UInt8](repeating: 0, count: 64)
        p[0] = 0x04; p[1] = 0xF5; p[8] = 9
        Thread.sleep(forTimeInterval: 0.003)
        trace(">", p)
        try cmdIF.setFeature(p)
        Thread.sleep(forTimeInterval: 0.005)
        var r: [UInt8] = []
        for _ in 0..<10 {
            if let x = try? cmdIF.getFeature(length: 64) { r = x; break }
            Thread.sleep(forTimeInterval: 0.005)
        }
        trace("<", r)
        guard r.count > 3, r[3] == 1 else {
            log("no ack for read 0xF5")
            throw HIDError("The keyboard didn't acknowledge the read (0xF5)")
        }
        var out: [UInt8] = []
        for _ in 0..<9 {
            Thread.sleep(forTimeInterval: 0.003)
            let page = try cmdIF.getFeature(length: 64)
            trace("<", page)
            out += Keyboard.pad(page)
        }
        try end()
        return out
    }

    /// Store per-key colours (user lighting, mode 0x80). colors: light_index -> (r,g,b)
    public func setUserLighting(_ colors: [Int: (UInt8, UInt8, UInt8)], brightness: UInt8) throws {
        // 1. select mode 0x80
        try begin()
        try command(0x13, pages: 1)
        var m = [UInt8](repeating: 0, count: 64)
        m[0] = 0x80; m[9] = brightness; m[14] = 0xAA; m[15] = 0x55
        try data(m)
        try end()
        try commit()
        // 2. upload colours
        try begin()
        try command(0x23, pages: 9)
        var d = [UInt8](repeating: 0, count: 576)
        for (idx, c) in colors where idx > 0 && idx < 143 {
            d[idx * 4] = UInt8(idx); d[idx * 4 + 1] = c.0; d[idx * 4 + 2] = c.1; d[idx * 4 + 3] = c.2
        }
        d[0x23e] = 0xAA; d[0x23f] = 0x55
        try sendData(d)
        try end()
        try commit()
    }

    // MARK: key map (§7)

    public func setKeyMap(fnLayer: Bool, actions: [Int: [UInt8]]) throws {
        try begin()
        try command(fnLayer ? 0x27 : 0x11, pages: 9)
        var d = [UInt8](repeating: 0, count: 576)
        for (idx, a) in actions where idx > 0 && idx < 143 {
            for i in 0..<4 { d[idx * 4 + i] = a[i] }
        }
        d[0x23e] = 0xAA; d[0x23f] = 0x55
        try sendData(d)
        try end()
        try commit()
    }

    // MARK: macros (§8)

    /// Each macro is a list of 4-byte events.
    public func setMacros(_ macros: [[[UInt8]]]) throws {
        precondition(macros.count <= 100)
        var buf = [UInt8](repeating: 0, count: 0xE00)
        var off = 0x190
        for i in 0..<100 {
            guard i < macros.count, !macros[i].isEmpty else {
                buf[i * 4] = 0xff; buf[i * 4 + 1] = 0xff; buf[i * 4 + 2] = 0xff; buf[i * 4 + 3] = 0xff
                continue
            }
            let ev = macros[i]
            guard off + 8 + ev.count * 4 <= 0xE00 - 2 else { throw HIDError("Macros are too long for the keyboard's memory (max 3584 bytes)") }
            buf[i * 4] = UInt8(off & 0xff); buf[i * 4 + 1] = UInt8(off >> 8)
            buf[off] = UInt8(ev.count & 0xff); buf[off + 1] = UInt8(ev.count >> 8)
            for (j, e) in ev.enumerated() { for k in 0..<4 { buf[off + 8 + j * 4 + k] = e[k] } }
            off += 8 + ev.count * 4
        }
        let pages = off % 64 == 0 ? off / 64 + 1 : off / 64 + 2
        let len = pages * 64
        guard len <= 0xE00 else { throw HIDError("Macros are too long for the keyboard's memory") }
        var data = Array(buf.prefix(len))
        data[len - 2] = 0xAA; data[len - 1] = 0x55
        try command(0x19)
        try command(0x15, pages: pages)
        Thread.sleep(forTimeInterval: 0.03)
        try sendData(data)
        try end()
    }

    // MARK: settings (§9)

    public func setSettings(disableAltTab: Bool, disableAltF4: Bool, disableWin: Bool,
                     fnSwitch: UInt8, sleepTime: UInt8, responseLevel: UInt8) throws {
        try begin()
        try command(0x17, pages: 1, extra: [2: 1])
        var d = [UInt8](repeating: 0, count: 64)
        d[0] = 0x00; d[1] = 0x01
        d[2] = disableAltTab ? 1 : 0; d[3] = disableAltF4 ? 1 : 0; d[4] = disableWin ? 1 : 0
        d[5] = fnSwitch; d[6] = sleepTime; d[8] = responseLevel
        d[62] = 0xAA; d[63] = 0x55
        try data(d)
        try end()
    }

    // MARK: screen (§10)

    public func syncClock(slot: UInt8 = 1, date: Date = Date()) throws {
        let c = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day, .hour, .minute, .second, .weekday], from: date)
        try begin()
        try command(0x28, pages: 1)
        var d = [UInt8](repeating: 0, count: 64)
        d[0] = 0; d[1] = slot; d[2] = 0x5A
        d[3] = UInt8(c.year! % 2000); d[4] = UInt8(c.month!); d[5] = UInt8(c.day!)
        d[6] = UInt8(c.hour!); d[7] = UInt8(c.minute!); d[8] = UInt8(c.second!)
        d[10] = UInt8(c.weekday! - 1)   // SYSTEMTIME: 0 = Sunday
        d[62] = 0xAA; d[63] = 0x55
        try data(d, ack: true)
        try end()
    }

    /// frames: RGB565 little-endian 128x128 (32768 bytes each), delays in ms.
    public func uploadScreen(frames: [[UInt8]], delaysMs: [Int], slot: UInt8 = 1,
                      progress: (Int, Int) -> Void = { _, _ in }) throws {
        guard !frames.isEmpty, frames.count <= 140 else { throw HIDError("1 to 140 frames are allowed") }
        guard dryRun || bulk != nil else { throw HIDError("The keyboard's screen-data interface (4096-byte output reports) wasn't found") }
        var buf = [UInt8](repeating: 0xff, count: 256)
        buf[0] = UInt8(frames.count)
        for (i, ms) in delaysMs.enumerated() { buf[1 + i] = UInt8(max(1, min(255, ms / 2))) }
        for f in frames { precondition(f.count == 128 * 128 * 2); buf += f }
        let pages = (buf.count + 4095) / 4096
        buf += [UInt8](repeating: 0xff, count: pages * 4096 - buf.count)

        log("screen upload: \(frames.count) frame(s), \(pages) page(s) of 4096 bytes, slot \(slot)")
        bulk?.listen()
        try begin()
        try command(0x72, pages: pages & 0xff, extra: [2: slot, 9: UInt8(pages >> 8)])
        for p in 0..<pages {
            let page = Array(buf[p * 4096..<(p + 1) * 4096])
            dataSum += page.reduce(0) { $0 + Int($1) }
            if let bulk = bulk {
                do { try bulk.setOutput(page) } catch { log("screen page \(p + 1)/\(pages) failed: \(error)"); throw error }
                let reply = bulk.waitInput(timeout: 0.3)
                // One line per page: first bytes sent, and the keyboard's reply (or a timeout).
                log("bulk page \(p + 1)/\(pages) > " + hex(Array(page.prefix(8))) + " … | < "
                    + (reply.map { hex(Array($0.prefix(8))) } ?? "no reply (300 ms)"))
            } else if p == 0 {
                print("output  page 1/\(pages) header: " + hex(Array(page.prefix(16))) + " ...")
            }
            progress(p + 1, pages)
        }
        try end()
    }
}
