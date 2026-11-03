// swift-tools-version: 6.0
// LumenScoring: WER / CER / exact-match scoring with Swedish text normalisation.
// One module shared by the app (Diagnostics -> STT benchmark) and the later Mac CLI (tools/stt-bench).
// Pure Swift, Foundation only, no platform frameworks.
import PackageDescription

let package = Package(
    name: "LumenScoring",
    products: [
        .library(name: "LumenScoring", targets: ["LumenScoring"]),
    ],
    targets: [
        .target(
            name: "LumenScoring",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "LumenScoringTests",
            dependencies: ["LumenScoring"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
