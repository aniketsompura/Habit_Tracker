// swift-tools-version:5.9
// Builds the app's Foundation-only core so its logic can be unit tested with `swift test`.
import PackageDescription

let package = Package(
    name: "HexisCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "HexisCore", targets: ["HexisCore"])],
    targets: [
        .target(name: "HexisCore", path: "Core", resources: [.process("Resources")]),
        .testTarget(name: "HexisCoreTests", dependencies: ["HexisCore"], path: "CoreTests"),
    ]
)
