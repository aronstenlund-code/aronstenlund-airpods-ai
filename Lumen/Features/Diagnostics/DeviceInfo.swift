import Foundation
import UIKit

@MainActor
enum DeviceInfo {
    /// Hardware identifier such as "iPhone17,1".
    static var modelIdentifier: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let size = MemoryLayout.size(ofValue: systemInfo.machine)
        return withUnsafePointer(to: &systemInfo.machine) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: size) { String(cString: $0) }
        }
    }

    static var summary: String {
        let device = UIDevice.current
        let region = Locale.current.region?.identifier ?? "?"
        return "\(device.model) \(modelIdentifier) · \(device.systemName) \(device.systemVersion) · region \(region) · locale \(Locale.current.identifier)"
    }
}
