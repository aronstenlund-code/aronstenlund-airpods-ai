// swift-tools-version: 6.2
// LumenVAD (D78 / OSS-2): Silero VAD through FluidAudio, with every optional FluidAudio subsystem switched off.
// FluidAudio's default traits link TTS resources whose data is GPL-3.0 (espeak-ng) and CC-BY-SA-4.0, and a prebuilt
// text-normalisation engine. `traits: []` keeps only the ASR/VAD core: FluidAudio (Apache-2.0) and fastcluster (BSD).
// Licences: THIRD_PARTY_NOTICES.md. Pinned to the reviewed commit; re-check every LICENSE before a bump.
import PackageDescription

let package = Package(
    name: "LumenVAD",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "LumenVAD", targets: ["LumenVAD"]),
    ],
    dependencies: [
        .package(url: "https://github.com/FluidInference/FluidAudio", revision: "ee78635d23d52379117554ba72358b65a0612447",
                 traits: []),
    ],
    targets: [
        .target(
            name: "LumenVAD",
            dependencies: [.product(name: "FluidAudio", package: "FluidAudio")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
