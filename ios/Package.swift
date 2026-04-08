// swift-tools-version:5.9
import PackageDescription

// NOTE: This Package.swift serves as documentation for SPM dependencies.
// The actual Xcode project uses .xcodeproj for build configuration.
// When setting up in Xcode, add these packages via File > Add Package Dependencies.

let package = Package(
    name: "CodePilot",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "CodePilot", targets: ["CodePilot"]),
    ],
    dependencies: [
        // RevenueCat for subscription management
        .package(url: "https://github.com/RevenueCat/purchases-ios-spm.git", from: "5.0.0"),
    ],
    targets: [
        .target(
            name: "CodePilot",
            dependencies: [
                .product(name: "RevenueCat", package: "purchases-ios-spm"),
            ],
            path: "CodePilot"
        ),
    ]
)
