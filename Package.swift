// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LidRunPersonal",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "LidRunCore", targets: ["LidRunCore"]),
        .executable(name: "lidrun-personal", targets: ["LidRunPersonal"]),
        .executable(name: "apprun", targets: ["AppRun"]),
    ],
    targets: [
        .target(
            name: "LidRunCore",
            linkerSettings: [.linkedFramework("IOKit"), .linkedFramework("CoreGraphics")]
        ),
        .executableTarget(
            name: "LidRunPersonal",
            dependencies: ["LidRunCore"],
            linkerSettings: [.linkedFramework("AppKit"), .linkedFramework("Carbon")]
        ),
        .executableTarget(
            name: "AppRun",
            dependencies: ["LidRunCore"]
        ),
        .testTarget(
            name: "LidRunCoreTests",
            dependencies: ["LidRunCore"]
        ),
    ]
)
