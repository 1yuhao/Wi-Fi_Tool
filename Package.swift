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
        .target(
            name: "AuthorizationShim",
            linkerSettings: [
                .linkedFramework("Security")
            ]
        ),
        .executableTarget(
            name: "WiFiConfigTool",
            dependencies: [
                "AuthorizationShim"
            ],
            path: "Sources/WiFiConfigTool",
            linkerSettings: [
                .linkedFramework("CoreLocation"),
                .linkedFramework("CoreWLAN"),
                .linkedFramework("Security")
            ]
        )
    ]
)
