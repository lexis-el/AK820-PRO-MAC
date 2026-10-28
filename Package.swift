// swift-tools-version:5.9
import PackageDescription

let frameworks: [LinkerSetting] = [
    .linkedFramework("IOKit"),
    .linkedFramework("CoreFoundation"),
    .linkedFramework("ImageIO"),
    .linkedFramework("CoreGraphics"),
]

let package = Package(
    name: "ak820",
    platforms: [.macOS(.v13)],
    targets: [
        // Keyboard protocol, HID access, key tables and image conversion, shared by the CLI and the app.
        .target(name: "AK820Core", path: "Sources/AK820Core", linkerSettings: frameworks),
        .executableTarget(name: "ak820", dependencies: ["AK820Core"], path: "Sources/ak820"),
        .executableTarget(name: "AK820App", dependencies: ["AK820Core"], path: "Sources/AK820App"),
    ]
)
