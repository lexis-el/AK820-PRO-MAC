import Foundation
import IOKit
import IOKit.hid

public struct HIDError: Error, CustomStringConvertible {
    public let description: String
    public init(_ d: String) { description = d }
}

/// One HID interface (IOHIDDevice) of the keyboard.
public final class HIDInterface {
    public let device: IOHIDDevice
    private var inputBuffer: UnsafeMutablePointer<UInt8>?
    private var inputSize = 0
    private(set) var lastInput: [UInt8]?
    private var isOpen = false

    public init(_ device: IOHIDDevice) { self.device = device }

    private func intProp(_ key: String) -> Int {
        (IOHIDDeviceGetProperty(device, key as CFString) as? NSNumber)?.intValue ?? 0
    }
    private func strProp(_ key: String) -> String {
        (IOHIDDeviceGetProperty(device, key as CFString) as? String) ?? ""
    }

    public var vendorID: Int { intProp(kIOHIDVendorIDKey) }
    public var productID: Int { intProp(kIOHIDProductIDKey) }
    public var usagePage: Int { intProp(kIOHIDPrimaryUsagePageKey) }
    public var usage: Int { intProp(kIOHIDPrimaryUsageKey) }
    public var maxFeature: Int { intProp(kIOHIDMaxFeatureReportSizeKey) }
    public var maxOutput: Int { intProp(kIOHIDMaxOutputReportSizeKey) }
    public var maxInput: Int { intProp(kIOHIDMaxInputReportSizeKey) }
    public var product: String { strProp(kIOHIDProductKey) }
    public var transport: String { strProp(kIOHIDTransportKey) }
    public var locationID: Int { intProp(kIOHIDLocationIDKey) }

    public var summary: String {
        String(format: "%04X:%04X  usage %04X:%04X  in %4d  out %4d  feature %3d  %@ (%@)",
               vendorID, productID, usagePage, usage, maxInput, maxOutput, maxFeature,
               product, transport)
    }

    public func open() throws {
        if isOpen { return }
        // Non-exclusive open: typing keeps working while the tool runs.
        let r = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
        guard r == kIOReturnSuccess else {
            if r == kIOReturnNotPermitted {
                throw HIDError("Opening the HID interface was refused (kIOReturnNotPermitted). Give your terminal app Input Monitoring permission in System Settings > Privacy & Security, then try again.")
            }
            throw HIDError(String(format: "IOHIDDeviceOpen failed: 0x%08X", r))
        }
        isOpen = true
    }

    public func close() {
        if isOpen {
            if inputBuffer != nil {
                IOHIDDeviceUnscheduleFromRunLoop(device, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
            }
            IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
            isOpen = false
        }
        inputBuffer?.deallocate()
        inputBuffer = nil
    }

    deinit { close() }

    public func setFeature(_ data: [UInt8]) throws {
        let r = data.withUnsafeBufferPointer {
            IOHIDDeviceSetReport(device, kIOHIDReportTypeFeature, 0, $0.baseAddress!, $0.count)
        }
        guard r == kIOReturnSuccess else { throw HIDError(String(format: "SetReport(feature) failed: 0x%08X", r)) }
    }

    public func getFeature(length: Int) throws -> [UInt8] {
        var buf = [UInt8](repeating: 0, count: length)
        var len = CFIndex(length)
        let r = buf.withUnsafeMutableBufferPointer {
            IOHIDDeviceGetReport(device, kIOHIDReportTypeFeature, 0, $0.baseAddress!, &len)
        }
        guard r == kIOReturnSuccess else { throw HIDError(String(format: "GetReport(feature) failed: 0x%08X", r)) }
        return Array(buf.prefix(Int(len)))
    }

    public func setOutput(_ data: [UInt8]) throws {
        let r = data.withUnsafeBufferPointer {
            IOHIDDeviceSetReport(device, kIOHIDReportTypeOutput, 0, $0.baseAddress!, $0.count)
        }
        guard r == kIOReturnSuccess else { throw HIDError(String(format: "SetReport(output) failed: 0x%08X", r)) }
    }

    /// Start listening for input reports (needed before waitInput).
    public func listen() {
        guard inputBuffer == nil else { return }
        inputSize = max(maxInput, 64)
        inputBuffer = .allocate(capacity: inputSize)
        let ctx = Unmanaged.passUnretained(self).toOpaque()
        IOHIDDeviceRegisterInputReportCallback(device, inputBuffer!, inputSize, { ctx, _, _, _, _, report, len in
            let me = Unmanaged<HIDInterface>.fromOpaque(ctx!).takeUnretainedValue()
            me.lastInput = Array(UnsafeBufferPointer(start: report, count: len))
        }, ctx)
        IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
    }

    /// Run the run loop until an input report arrives or the timeout passes.
    @discardableResult
    public func waitInput(timeout: TimeInterval) -> [UInt8]? {
        lastInput = nil
        let end = Date().addingTimeInterval(timeout)
        while lastInput == nil && Date() < end {
            CFRunLoopRunInMode(.defaultMode, 0.01, true)
        }
        return lastInput
    }
}

public enum HIDEnumerator {
    /// All HID interfaces with the given vendor ID (and optional product IDs).
    public static func interfaces(vendorID: Int, productIDs: [Int]? = nil) -> [HIDInterface] {
        let mgr = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerSetDeviceMatching(mgr, [kIOHIDVendorIDKey: vendorID] as CFDictionary)
        guard let set = IOHIDManagerCopyDevices(mgr) as? Set<IOHIDDevice> else { return [] }
        return set.map(HIDInterface.init)
            .filter { productIDs == nil || productIDs!.contains($0.productID) }
            .sorted { ($0.productID, $0.usagePage, $0.usage) < ($1.productID, $1.usagePage, $1.usage) }
    }
}
