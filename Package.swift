// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "WiFiConfigTool",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "WiFiConfigTool", targets: ["WiFiConfigTool"])
    ],
    targets: [
        .executableTarget(
            name: "WiFiConfigTool",
            path: "Sources/WiFiConfigTool",
            linkerSettings: [
                .linkedFramework("CoreLocation"),
                .linkedFramework("CoreWLAN")
            ]
        )
    ]
)
