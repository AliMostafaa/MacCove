// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacCove",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "MacCove",
            path: "Sources",
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("QuickLookThumbnailing"),
                .linkedFramework("IOKit"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("Carbon"),
                .linkedFramework("LinkPresentation"),
                .linkedFramework("CoreWLAN"),
                .linkedFramework("Network")
            ]
        )
    ]
)
