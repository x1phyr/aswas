// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "aswas",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "AswasCore", targets: ["AswasCore"]),
        .executable(name: "aswas", targets: ["AswasApp"]),
        .executable(name: "AswasFinderPoC", targets: ["AswasFinderPoC"])
    ],
    targets: [
        .target(
            name: "AswasCore",
            resources: [
                .process("Resources")
            ]
        ),
        .target(
            name: "AswasFinderPoCCore"
        ),
        .executableTarget(
            name: "AswasApp",
            dependencies: ["AswasCore"]
        ),
        .executableTarget(
            name: "AswasFinderPoC",
            dependencies: ["AswasCore", "AswasFinderPoCCore"],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "AswasFinderPoCCoreTests",
            dependencies: ["AswasFinderPoCCore"]
        ),
        .testTarget(
            name: "AswasCoreTests",
            dependencies: ["AswasCore"]
        )
    ]
)
