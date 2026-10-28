import Foundation

/// Version shown in logs and the app.
public let ak820Version = "1.1.0"

/// Diagnostic log shared by the app and the CLI: ~/Library/Logs/AK820/ak820.log.
/// Records operations, every packet exchanged with the keyboard, checksums and errors, so a bug report
/// can include exactly what happened. When the file passes 2 MB it moves to ak820.log.1 (one old file is kept).
public enum DiagLog {
    public static let directory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/AK820", isDirectory: true)
    public static let fileURL = directory.appendingPathComponent("ak820.log")
    private static let maxSize = 2 * 1024 * 1024
    private static let lock = NSLock()
    private static var started = false
    /// Who is writing: "app" or "cli". Set once at startup.
    public static var source = "?"

    private static let stamp: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return f
    }()

    /// Write the session header (version, macOS, arguments). Called once per process.
    public static func start(source: String, version: String) {
        self.source = source
        let os = ProcessInfo.processInfo.operatingSystemVersionString
        write("=== \(source) \(version) started (pid \(getpid()), macOS \(os)) args: \(CommandLine.arguments.dropFirst().joined(separator: " "))")
    }

    public static func info(_ s: String) { write(s) }
    public static func error(_ s: String) { write("ERROR " + s) }

    /// Log a packet: "> " sent, "< " received. Trailing zero bytes are trimmed.
    public static func packet(_ dir: String, _ b: [UInt8], channel: String = "feature") {
        var n = b.count
        while n > 4 && b[n - 1] == 0 { n -= 1 }
        let h = b.prefix(n).map { String(format: "%02x", $0) }.joined(separator: " ")
        write("\(dir) \(channel)[\(b.count)] \(h)\(n < b.count ? " …" : "")")
    }

    private static func write(_ line: String) {
        lock.lock(); defer { lock.unlock() }
        let fm = FileManager.default
        if !started {
            try? fm.createDirectory(at: directory, withIntermediateDirectories: true)
            started = true
        }
        if let size = (try? fm.attributesOfItem(atPath: fileURL.path))?[.size] as? Int, size > maxSize {
            let old = directory.appendingPathComponent("ak820.log.1")
            try? fm.removeItem(at: old)
            try? fm.moveItem(at: fileURL, to: old)
        }
        let text = "\(stamp.string(from: Date())) [\(source)] \(line)\n"
        guard let data = text.data(using: .utf8) else { return }
        if let h = try? FileHandle(forWritingTo: fileURL) {
            h.seekToEndOfFile(); h.write(data); try? h.close()
        } else {
            try? data.write(to: fileURL)
        }
    }
}
