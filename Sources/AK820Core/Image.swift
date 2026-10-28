import Foundation
import ImageIO
import CoreGraphics

/// Load a still image or animated GIF and convert each frame to 128x128 RGB565 (little-endian).
public func loadScreenFrames(path: String, fill: Bool, defaultDelayMs: Int, maxFrames: Int = 140) throws -> (frames: [[UInt8]], delays: [Int]) {
    let url = URL(fileURLWithPath: path)
    guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { throw HIDError("Can't open image: \(path)") }
    let count = CGImageSourceGetCount(src)
    guard count > 0 else { throw HIDError("No image frames in \(path)") }
    if count > maxFrames {
        FileHandle.standardError.write("Note: the image has \(count) frames; only the first \(maxFrames) are uploaded.\n".data(using: .utf8)!)
    }
    var frames: [[UInt8]] = []
    var delays: [Int] = []
    for i in 0..<min(count, maxFrames) {
        guard let img = CGImageSourceCreateImageAtIndex(src, i, nil) else { continue }
        frames.append(try rgb565(img, size: 128, fill: fill))
        var ms = defaultDelayMs
        if let props = CGImageSourceCopyPropertiesAtIndex(src, i, nil) as? [CFString: Any],
           let gif = props[kCGImagePropertyGIFDictionary] as? [CFString: Any] {
            let d = (gif[kCGImagePropertyGIFUnclampedDelayTime] as? Double) ?? (gif[kCGImagePropertyGIFDelayTime] as? Double) ?? 0
            if d > 0 { ms = Int(d * 1000) }
        }
        delays.append(min(500, max(30, ms)))   // vendor UI range: 30-500 ms
    }
    return (frames, delays)
}

/// Decode one RGB565 frame back into an image (what the keyboard screen will show).
public func previewImage(frame: [UInt8], size: Int = 128) -> CGImage? {
    var rgba = [UInt8](repeating: 255, count: size * size * 4)
    for p in 0..<(size * size) {
        let v = UInt16(frame[p * 2]) | UInt16(frame[p * 2 + 1]) << 8
        rgba[p * 4] = UInt8((v >> 11) << 3); rgba[p * 4 + 1] = UInt8(((v >> 5) & 0x3f) << 2); rgba[p * 4 + 2] = UInt8((v & 0x1f) << 3)
    }
    guard let provider = CGDataProvider(data: Data(rgba) as CFData) else { return nil }
    return CGImage(width: size, height: size, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: size * 4,
                   space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                   provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
}

/// Write the first frame back out as a PNG (decoded from RGB565), to check the conversion without a keyboard.
public func writePreview(frame: [UInt8], size: Int = 128, to path: String) throws {
    guard let img = previewImage(frame: frame, size: size),
          let dst = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, "public.png" as CFString, 1, nil)
    else { throw HIDError("Can't write \(path)") }
    CGImageDestinationAddImage(dst, img, nil)
    guard CGImageDestinationFinalize(dst) else { throw HIDError("Can't write \(path)") }
}

private func rgb565(_ img: CGImage, size: Int, fill: Bool) throws -> [UInt8] {
    var rgba = [UInt8](repeating: 0, count: size * size * 4)
    let cs = CGColorSpaceCreateDeviceRGB()
    try rgba.withUnsafeMutableBytes { raw in
        guard let ctx = CGContext(data: raw.baseAddress, width: size, height: size, bitsPerComponent: 8,
                                  bytesPerRow: size * 4, space: cs,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw HIDError("Can't create a bitmap context")
        }
        ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
        ctx.interpolationQuality = .high
        let w = CGFloat(img.width), h = CGFloat(img.height)
        let s = fill ? max(CGFloat(size) / w, CGFloat(size) / h) : min(CGFloat(size) / w, CGFloat(size) / h)
        let dw = w * s, dh = h * s
        ctx.draw(img, in: CGRect(x: (CGFloat(size) - dw) / 2, y: (CGFloat(size) - dh) / 2, width: dw, height: dh))
    }
    // CGContext memory is top row first.
    var out = [UInt8](repeating: 0, count: size * size * 2)
    for p in 0..<(size * size) {
        let r = UInt16(rgba[p * 4]), g = UInt16(rgba[p * 4 + 1]), b = UInt16(rgba[p * 4 + 2])
        let v = (r & 0xF8) << 8 | (g & 0xFC) << 3 | b >> 3
        out[p * 2] = UInt8(v & 0xff)
        out[p * 2 + 1] = UInt8(v >> 8)
    }
    return out
}
