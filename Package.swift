// swift-tools-version:5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SSignalKit",
    platforms: [
        .macOS(.v10_12), .iOS(.v10), .tvOS(.v10)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "SSignalKit",
            targets: [ "SSignalKit" ]),
        .library(
            name: "SwiftSignalKit",
            targets: [ "SwiftSignalKit" ])
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "SSignalKit",
            path: ".",
            sources: [ "SSignalKit" ],
            cSettings: [
                .headerSearchPath(".")
            ]),
        .target(
            name: "SwiftSignalKit",
            path: ".",
            sources: [ "SwiftSignalKit" ]),
        .testTarget(name: "SSignalKitTests",
                    dependencies: [ "SSignalKit" ],
                    path: ".",
                    sources: [ "SSignalKitTests" ],
                    cSettings: [
                        .headerSearchPath(".")
                    ]),
        .testTarget(name: "SwiftSignalKitTests",
                    dependencies: [ "SwiftSignalKit" ],
                    path: ".",
                    sources: [ "SwiftSignalKitTests" ])
    ],
    swiftLanguageVersions: [.v5],
    cLanguageStandard: .gnu11,
    cxxLanguageStandard: .gnucxx14
)
