// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RookKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "RookKit", targets: ["RookKit"])],
    targets: [
        .systemLibrary(name: "RookFFI", path: "Sources/RookFFI"),
        .target(
            name: "RookKit",
            dependencies: ["RookFFI"],
            exclude: ["Generated/RookFFI.h", "Generated/RookFFI.modulemap"],
            linkerSettings: [.linkedLibrary("rook_ffi")]
        ),
        .testTarget(name: "RookKitTests", dependencies: ["RookKit"])
    ]
)
