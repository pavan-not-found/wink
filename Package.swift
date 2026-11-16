// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Wink",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Wink",
            path: "Sources/Wink",
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("ServiceManagement"),
            ]
        )
    ]
)
