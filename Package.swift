// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VectorCore",
    platforms: [.iOS("26.0"), .watchOS("26.0"), .macOS(.v15)],
    products: [.library(name: "VectorCore", targets: ["VectorCore"])],
    targets: [.target(name: "VectorCore"), .testTarget(name: "VectorCoreTests", dependencies: ["VectorCore"])]
)
