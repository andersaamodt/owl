// Generated from app-blueprint/app.ir.yaml. Regenerate with scripts/render-native-desktop.sh.
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "stellar",
  platforms: [
    .macOS(.v13)
  ],
  products: [
    .executable(name: "stellar", targets: ["App"])
  ],
  targets: [
    .executableTarget(
      name: "App",
      path: "Sources/App",
      linkerSettings: [
        .linkedFramework("AVKit")
      ]
    )
  ]
)
