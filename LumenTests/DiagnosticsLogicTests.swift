import AVFAudio
import Foundation
import Testing
@testable import Lumen

@Suite struct MicSourceTestTests {
    private func base(seconds: Double, amplitude: Int) -> [Int16] {
        var state: UInt64 = 7
        return (0..<Int(seconds * 16_000)).map { _ in
            state = state &* 6364136223846793005 &+ 1442695040888963407
            let unit = Double(state >> 11) / Double(1 << 53)
            return Int16((unit * 2 - 1) * Double(amplitude))
        }
    }

    private func addImpulse(_ samples: inout [Int16], at second: Double) {
        let start = Int(second * 16_000)
        for i in 0..<480 where start + i < samples.count { // 30 ms burst
            samples[start + i] = i % 2 == 0 ? 20_000 : -20_000
        }
    }

    @Test func threeTapsMeanBuiltInMic() {
        var samples = base(seconds: 5, amplitude: 60)
        addImpulse(&samples, at: 1.0)
        addImpulse(&samples, at: 2.2)
        addImpulse(&samples, at: 3.7)
        let result = MicSourceTest.analyze(samples)
        #expect(result.impulses == 3)
        #expect(result.verdict == .builtInMicLikely)
        #expect(result.maxImpulseDBFS > -5)
        #expect(result.baselineDBFS < -50)
    }

    @Test func noTapsMeanExternalMic() {
        let result = MicSourceTest.analyze(base(seconds: 5, amplitude: 60))
        #expect(result.impulses == 0)
        #expect(result.verdict == .externalMicLikely)
    }

    @Test func oneTapIsInconclusive() {
        var samples = base(seconds: 5, amplitude: 60)
        addImpulse(&samples, at: 2.0)
        let result = MicSourceTest.analyze(samples)
        #expect(result.impulses == 1)
        #expect(result.verdict == .inconclusive)
    }

    @Test func tooShortIsInconclusive() {
        #expect(MicSourceTest.analyze([Int16](repeating: 0, count: 100)).verdict == .inconclusive)
    }
}

@Suite struct SessionSnapshotTests {
    private func snapshot(inputType: String, inputName: String, mode: String, sampleRate: Double, hq: HQCapability) -> SessionSnapshot {
        SessionSnapshot(timestamp: Date(timeIntervalSince1970: 0), config: .cHFPMeasurement,
                        category: "AVAudioSessionCategoryPlayAndRecord", mode: mode, options: ["allowBluetoothHFP"],
                        inputs: [PortInfo(portType: inputType, portName: inputName, uid: "u", channelCount: 1, dataSource: nil)],
                        outputs: [PortInfo(portType: "BluetoothHFP", portName: inputName, uid: "u", channelCount: 1, dataSource: nil)],
                        sampleRate: sampleRate, ioBufferDuration: 0.02, inputChannels: 1, outputChannels: 1,
                        inputLatency: 0.01, outputLatency: 0.02, hq: hq, preferredInputSucceeded: true,
                        engineInputFormat: "16000 Hz · 1 ch · Float32", region: "SE", osVersion: "Version 26.1")
    }

    @Test func bannerFormat() {
        let s = snapshot(inputType: "BluetoothHFP", inputName: "AirPods Pro 2", mode: "AVAudioSessionModeMeasurement",
                         sampleRate: 16_000, hq: HQCapability(extensionPresent: true, isSupported: false, isEnabled: false))
        #expect(s.banner == "AirPods Pro 2 · HFP · mode=measurement · 16 kHz · HQ supported=false enabled=false")
        #expect(s.modeShort == "measurement")
        #expect(s.categoryShort == "playAndRecord")
    }

    @Test func transportMapping() {
        let hqOn = snapshot(inputType: "BluetoothHFP", inputName: "AirPods 4", mode: "AVAudioSessionModeDefault",
                            sampleRate: 48_000, hq: HQCapability(extensionPresent: true, isSupported: true, isEnabled: true))
        #expect(hqOn.transport == "BT-HQ")
        #expect(hqOn.sampleRateKHz == "48")
        let builtIn = snapshot(inputType: "MicrophoneBuiltIn", inputName: "iPhone Microphone", mode: "AVAudioSessionModeDefault",
                               sampleRate: 44_100, hq: .unavailable)
        #expect(builtIn.transport == "iPhone mic")
        #expect(builtIn.sampleRateKHz == "44.1")
        #expect(builtIn.banner.contains("iPhone mic · mode=default · 44.1 kHz"))
    }

    @Test func markdownContainsHQFields() {
        let s = snapshot(inputType: "BluetoothHFP", inputName: "AirPods Pro 2", mode: "AVAudioSessionModeDefault",
                         sampleRate: 16_000, hq: HQCapability(extensionPresent: true, isSupported: true, isEnabled: false))
        #expect(s.markdown.contains("| HQ isSupported / isEnabled | true / false |"))
        #expect(s.markdown.contains("| device region | SE |"))
        #expect(s.markdown.contains("| setPreferredInput | succeeded |"))
    }

    @Test func optionNames() {
        #expect(SessionSnapshot.optionNames([.allowBluetoothHFP, .bluetoothHighQualityRecording]) == ["allowBluetoothHFP", "bluetoothHighQualityRecording"])
        #expect(SessionSnapshot.optionNames([.allowBluetoothA2DP]) == ["allowBluetoothA2DP"])
        #expect(SessionSnapshot.optionNames([]).isEmpty)
    }

    @Test func externalOutputDetection() {
        #expect(PortInfo(portType: "BluetoothA2DPOutput", portName: "x", uid: "u", channelCount: 2, dataSource: nil).isExternalOutput)
        #expect(PortInfo(portType: "Headphones", portName: "x", uid: "u", channelCount: 2, dataSource: nil).isExternalOutput)
        #expect(!PortInfo(portType: "Speaker", portName: "x", uid: "u", channelCount: 2, dataSource: nil).isExternalOutput)
    }
}

@Suite struct CaptureConfigTests {
    @Test func hqIsOnlyRequestedInDefaultMode() {
        for config in CaptureConfig.allCases where config.options.contains(.bluetoothHighQualityRecording) {
            #expect(config.mode == .default, "\(config.rawValue)")
            #expect(config.options.contains(.allowBluetoothHFP), "HQ needs the HFP fallback")
        }
        #expect(CaptureConfig.bHQ.options == [.bluetoothHighQualityRecording, .allowBluetoothHFP])
    }

    @Test func hfpVariantsCoverThreeModes() {
        #expect(CaptureConfig.cHFPDefault.mode == .default)
        #expect(CaptureConfig.cHFPMeasurement.mode == .measurement)
        #expect(CaptureConfig.cHFPVoiceChat.mode == .voiceChat)
        for config in [CaptureConfig.cHFPDefault, .cHFPMeasurement, .cHFPVoiceChat] {
            #expect(config.options == [.allowBluetoothHFP])
            #expect(config.inputPreference == .bluetooth)
            #expect(config.strategy == "C")
        }
    }

    @Test func referenceUsesBuiltInMicAndA2DPOnly() {
        for config in [CaptureConfig.aRefDefault, .aRefMeasurement] {
            #expect(config.options == [.allowBluetoothA2DP])
            #expect(config.inputPreference == .builtInMic)
            #expect(config.strategy == "A")
        }
        #expect(CaptureConfig.allCases.count == 6)
        #expect(CaptureConfig.allCases.allSatisfy { $0.category == .playAndRecord })
    }

    @Test func modeNamesMatchModes() {
        #expect(CaptureConfig.cHFPMeasurement.modeName == "measurement")
        #expect(CaptureConfig.cHFPVoiceChat.modeName == "voiceChat")
        #expect(CaptureConfig.bHQ.modeName == "default")
    }
}
