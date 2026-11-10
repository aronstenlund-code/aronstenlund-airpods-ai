import Foundation
import Testing
@testable import Lumen

/// A47 (D121): battery per hour over a whole listening session, from iOS's 5 % steps.
@MainActor
@Suite struct D121Tests {
    @Test func batteryPerHourOverTheSession() {
        let start = ResourceSample(at: Date(timeIntervalSinceReferenceDate: 0), cpuSeconds: 0, battery: 0.90)
        let twoHours = ResourceSample(at: Date(timeIntervalSinceReferenceDate: 7200), cpuSeconds: 300, battery: 0.78)
        #expect(ResourceSample.sessionLine(from: start, to: twoHours) == "Battery since start -12 % in 2.0 h (6.0 %/h)")
        let early = ResourceSample(at: Date(timeIntervalSinceReferenceDate: 600), cpuSeconds: 10, battery: 0.90)
        #expect(ResourceSample.sessionLine(from: start, to: early) == nil, "under half an hour says nothing")
        let simulator = ResourceSample(at: Date(timeIntervalSinceReferenceDate: 7200), cpuSeconds: 300, battery: nil)
        #expect(ResourceSample.sessionLine(from: start, to: simulator) == nil)
    }
}
