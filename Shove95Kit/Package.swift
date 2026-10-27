// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Shove95Kit",
    platforms: [
        .iOS(.v18),
        .macOS(.v26),   // future Mac app shares this package
    ],
    products: [
        .library(name: "Shove95Kit", targets: ["Shove95Kit"]),
    ],
    targets: [
        .target(name: "Shove95Kit"),
        .testTarget(name: "Shove95KitTests", dependencies: ["Shove95Kit"]),
    ]
)
