import UIKit

class DeviceInfo {
    
    static func getDeviceName() -> String {
        return UIDevice.current.name
    }
    
    static func getOSVersion() -> String {
        return UIDevice.current.systemVersion
    }
    
    static func getDeviceInfo() -> (deviceName: String, osVersion: String) {
        let deviceName = getDeviceName()
        let osVersion = getOSVersion()
        return (deviceName, osVersion)
    }
}


