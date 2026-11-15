// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PatrimoineCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "PatrimoineCore", targets: ["PatrimoineCore"])],
    targets: [
        .target(name: "PatrimoineCore"),
        .testTarget(name: "PatrimoineCoreTests", dependencies: ["PatrimoineCore"])
    ]
)
