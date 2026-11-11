// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "TomorrowMac",
    platforms: [.macOS(.v26)],
    dependencies: [.package(path: "../Shove95Kit")],
    targets: [
        .executableTarget(name: "TomorrowMac", dependencies: ["Shove95Kit"]),
        .testTarget(name: "TomorrowMacTests", dependencies: ["TomorrowMac", "Shove95Kit"])
    ]
)
