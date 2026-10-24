// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NotchDesk",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "NotchDesk", targets: ["NotchDesk"])],
    targets: [
        .executableTarget(name: "NotchDesk"),
        .testTarget(name: "NotchDeskTests", dependencies: ["NotchDesk"])
    ]
)
