// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HisobCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "HisobCore", targets: ["HisobCore"])
    ],
    targets: [
        .target(name: "HisobCore"),
        .testTarget(name: "HisobCoreTests", dependencies: ["HisobCore"])
    ]
)
