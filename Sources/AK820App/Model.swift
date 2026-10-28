import Foundation
import SwiftUI
import AK820Core

enum Connection: Equatable {
    case wired, bluetoothOnly, dongleOnly, none

    var label: String {
        switch self {
        case .wired: return "Connected (USB)"
        case .bluetoothOnly: return "Bluetooth only: connect the USB cable to configure"
        case .dongleOnly: return "2.4 GHz dongle only: connect the USB cable to configure"
        case .none: return "Not connected"
        }
    }
    var color: Color { self == .wired ? .green : (self == .none ? .secondary : .orange) }
}

struct RGB: Codable, Equatable {
    var r: UInt8, g: UInt8, b: UInt8
    init(r: UInt8, g: UInt8, b: UInt8) { self.r = r; self.g = g; self.b = b }
    init(_ c: Color) {
        let ns = NSColor(c).usingColorSpace(.sRGB) ?? .black
        r = UInt8(max(0, min(255, (ns.redComponent * 255).rounded())))
        g = UInt8(max(0, min(255, (ns.greenComponent * 255).rounded())))
        b = UInt8(max(0, min(255, (ns.blueComponent * 255).rounded())))
    }
    var color: Color { Color(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255) }
    static let black = RGB(r: 0, g: 0, b: 0)
}

struct Macro: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var steps: String   // one step per line: tap:K, down:K, up:K, mousedown:left, mouseup:left, or a delay in ms
}

/// App state. Keyboard I/O runs on a serial background queue; results come back on the main thread.
final class KeyboardModel: ObservableObject {
    @Published var connection: Connection = .none
    @Published var busy = false
    @Published var progress: Double?
    @Published var status = ""
    @Published var statusIsError = false

    // Persisted editor state (the keyboard can't report its key map, so the app remembers what it sent).
    @Published var keyColors: [Int: RGB] = [:] { didSet { save(keyColors, "keyColors") } }
    @Published var baseMap: [String: String] = [:] { didSet { save(baseMap, "baseMap") } }
    @Published var fnMap: [String: String] = [:] { didSet { save(fnMap, "fnMap") } }
    @Published var macros: [Macro] = [] { didSet { save(macros, "macros") } }

    private let queue = DispatchQueue(label: "ak820.hid")
    private var timer: Timer?

    init() {
        keyColors = load("keyColors") ?? [:]
        baseMap = load("baseMap") ?? [:]
        fnMap = load("fnMap") ?? [:]
        macros = load("macros") ?? []
        refreshConnection()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.refreshConnection() }
    }

    func refreshConnection() {
        guard !busy else { return }
        queue.async {
            let all = HIDEnumerator.interfaces(vendorID: vendorID)
            let c: Connection
            if all.contains(where: { wiredPIDs.contains($0.productID) && ($0.maxFeature == 64 || $0.maxFeature == 65) }) { c = .wired }
            else if all.contains(where: { $0.productID == bluetoothPID }) { c = .bluetoothOnly }
            else if all.contains(where: { $0.productID == donglePID }) { c = .dongleOnly }
            else { c = .none }
            DispatchQueue.main.async { if self.connection != c { self.connection = c } }
        }
    }

    /// Run a keyboard operation in the background. `work` receives the opened keyboard and a progress callback.
    func run(_ title: String, done: String, _ work: @escaping (Keyboard, @escaping (Double) -> Void) throws -> Void,
             completion: (() -> Void)? = nil) {
        guard !busy else { return }
        busy = true; progress = nil; status = title + "…"; statusIsError = false
        DiagLog.info("app: \(title)")
        queue.async {
            var err: Error?
            do {
                let kb = try Keyboard.find()
                try work(kb) { p in DispatchQueue.main.async { self.progress = p } }
            } catch { err = error; DiagLog.error("\(title): \(error)") }
            if err == nil { DiagLog.info("app: done: \(done)") }
            DispatchQueue.main.async {
                self.busy = false; self.progress = nil
                if let err = err { self.status = "\(err)"; self.statusIsError = true }
                else { self.status = done; completion?() }
                self.refreshConnection()
            }
        }
    }

    func fail(_ message: String) { status = message; statusIsError = true; DiagLog.error(message) }

    func revealLog() {
        if !FileManager.default.fileExists(atPath: DiagLog.fileURL.path) { DiagLog.info("log opened from the app") }
        NSWorkspace.shared.activateFileViewerSelecting([DiagLog.fileURL])
    }

    // MARK: persistence

    private func save<T: Encodable>(_ v: T, _ key: String) {
        if let d = try? JSONEncoder().encode(v) { UserDefaults.standard.set(d, forKey: key) }
    }
    private func load<T: Decodable>(_ key: String) -> T? {
        guard let d = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: d)
    }
}
