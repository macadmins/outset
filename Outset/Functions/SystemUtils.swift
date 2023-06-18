//
//  Functions.swift
//  outset
//
//  Created by Bart Reardon on 1/12/2022.
//
// swiftlint:disable line_length

import Foundation
import SystemConfiguration
import OSLog
import IOKit
import CoreFoundation

struct OutsetPreferences: Codable {
    var waitForNetwork: Bool = false
    var networkTimeout: Int = 180
    var ignoredUsers: [String] = []
    var overrideLoginOnce: [String: Date] = [String: Date]()

    enum CodingKeys: String, CodingKey {
        case waitForNetwork = "wait_for_network"
        case networkTimeout = "network_timeout"
        case ignoredUsers = "ignored_users"
        case overrideLoginOnce = "override_login_once"
    }
}

struct FileHashes: Codable {
    var sha256sum: [String: String] = [String: String]()
}

extension String {
    func camelCaseToUnderscored() -> String {
        let regex = try? NSRegularExpression(pattern: "([a-z])([A-Z])", options: [])
        let range = NSRange(location: 0, length: utf16.count)
        return regex?.stringByReplacingMatches(in: self, options: [], range: range, withTemplate: "$1_$2").lowercased() ?? self
    }
}

enum Action {
    case enable
    case disable
}

func ensureRoot(_ reason: String) {
    if !isRoot() {
        writeLog("Must be root to \(reason)", logLevel: .error)
        exit(1)
    }
}

func isRoot() -> Bool {
    return NSUserName() == "root"
}

func getValueForKey(_ key: String, inArray array: [String: String]) -> String? {
    // short function that treats a [String: String] as a key value pair.
    return array[key]
}

func writeLog(_ message: String, logLevel: OSLogType = .info, log: OSLog = osLog) {
    // write to the system logs
    os_log("%{public}@", log: log, type: logLevel, message)
    if logLevel == .error || logLevel == .info || (debugMode && logLevel == .debug) {
        // print info, errors and debug to stdout
        print("\(oslogTypeToString(logLevel).uppercased()): \(message)")
    }
    // also write to a log file for accessability of those that don't want to manage the system log
    writeFileLog(message: message, logLevel: logLevel)
}

func writeFileLog(message: String, logLevel: OSLogType) {
    if logLevel == .debug && !debugMode {
        return
    }
    let logFileURL = URL(fileURLWithPath: logFile)
    if !checkFileExists(path: logFile) {
        FileManager.default.createFile(atPath: logFileURL.path, contents: nil, attributes: nil)
        let attributes = [FileAttributeKey.posixPermissions: 0o666]
        do {
            try FileManager.default.setAttributes(attributes, ofItemAtPath: logFileURL.path)
        } catch {
            print("\(oslogTypeToString(.error).uppercased()): Unable to create log file at \(logFile)")
            return
        }
    }
    do {
        let fileHandle = try FileHandle(forWritingTo: logFileURL)
        defer { fileHandle.closeFile() }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        let date = dateFormatter.string(from: Date())
        let logEntry = "\(date) \(oslogTypeToString(logLevel).uppercased()): \(message)\n"

        fileHandle.seekToEndOfFile()
        fileHandle.write(logEntry.data(using: .utf8)!)
    } catch {
        print("\(oslogTypeToString(.error).uppercased()): Unable to read log file at \(logFile)")
        return
    }
}

func oslogTypeToString(_ type: OSLogType) -> String {
    switch type {
    case OSLogType.default: return "default"
    case OSLogType.info: return "info"
    case OSLogType.debug: return "debug"
    case OSLogType.error: return "error"
    case OSLogType.fault: return "fault"
    default: return "unknown"
    }
}

func getConsoleUserInfo() -> (username: String, userID: String) {
    // We need the console user, not the process owner so NSUserName() won't work for our needs when outset runs as root
    var uid: uid_t = 0
    if let consoleUser = SCDynamicStoreCopyConsoleUser(nil, &uid, nil) as? String {
        return (consoleUser, "\(uid)")
    } else {
        return ("", "")
    }
}

func writePreferences(prefs: OutsetPreferences) {

    if debugMode {
        showPrefrencePath("Stor")
    }

    let defaults = UserDefaults.standard

    // Take the OutsetPreferences object and write it to UserDefaults
    let mirror = Mirror(reflecting: prefs)
    for child in mirror.children {
        // Use the name of each property as the key, and save its value to UserDefaults
        if let propertyName = child.label {
            let key = propertyName.camelCaseToUnderscored()
            if isRoot() {
                // write the preference to /Library/Preferences/
                CFPreferencesSetValue(key as CFString,
                                      child.value as CFPropertyList,
                                      Bundle.main.bundleIdentifier! as CFString,
                                      kCFPreferencesAnyUser,
                                      kCFPreferencesAnyHost)
            } else {
                // write the preference to ~/Library/Preferences/
                defaults.set(child.value, forKey: key)
            }
        }
    }
}

func loadPreferences() -> OutsetPreferences {

    if debugMode {
        showPrefrencePath("Load")
    }

    let defaults = UserDefaults.standard
    var outsetPrefs = OutsetPreferences()

    if isRoot() {
        // force preferences to be read from /Library/Preferences instead of root's preferences
        outsetPrefs.networkTimeout = CFPreferencesCopyValue("network_timeout" as CFString, Bundle.main.bundleIdentifier! as CFString, kCFPreferencesAnyUser, kCFPreferencesAnyHost) as? Int ?? 180
        outsetPrefs.ignoredUsers = CFPreferencesCopyValue("ignored_users" as CFString, Bundle.main.bundleIdentifier! as CFString, kCFPreferencesAnyUser, kCFPreferencesAnyHost) as? [String] ?? []
        outsetPrefs.overrideLoginOnce = CFPreferencesCopyValue("override_login_once" as CFString, Bundle.main.bundleIdentifier! as CFString, kCFPreferencesAnyUser, kCFPreferencesAnyHost) as? [String: Date] ?? [:]
        outsetPrefs.waitForNetwork = (CFPreferencesCopyValue("wait_for_network" as CFString, Bundle.main.bundleIdentifier! as CFString, kCFPreferencesAnyUser, kCFPreferencesAnyHost) != nil)
    } else {
        // load preferences for the current user, which includes /Library/Preferences
        outsetPrefs.networkTimeout = defaults.integer(forKey: "network_timeout")
        outsetPrefs.ignoredUsers = defaults.array(forKey: "ignored_users") as? [String] ?? []
        outsetPrefs.overrideLoginOnce = defaults.object(forKey: "override_login_once") as? [String: Date] ?? [:]
        outsetPrefs.waitForNetwork = defaults.bool(forKey: "wait_for_network")
    }
    return outsetPrefs
}

func loadRunOnce() -> [String: Date] {

    if debugMode {
        showPrefrencePath("Load")
    }

    let defaults = UserDefaults.standard
    var runOnceKey = "run_once"

    if isRoot() {
        runOnceKey += "-"+getConsoleUserInfo().username
    }
    return defaults.object(forKey: runOnceKey) as? [String: Date] ?? [:]
}

func writeRunOnce(runOnceData: [String: Date]) {

    if debugMode {
        showPrefrencePath("Stor")
    }

    let defaults = UserDefaults.standard
    var runOnceKey = "run_once"

    if isRoot() {
        runOnceKey += "-"+getConsoleUserInfo().username
    }
    defaults.set(runOnceData, forKey: runOnceKey)
}

func showPrefrencePath(_ action: String) {
    var prefsPath: String
    if isRoot() {
        prefsPath = "/Library/Preferences".appending("/\(Bundle.main.bundleIdentifier!).plist")
    } else {
        let path = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true)
        prefsPath = path[0].appending("/Preferences").appending("/\(Bundle.main.bundleIdentifier!).plist")
    }
    writeLog("\(action)ing preference file: \(prefsPath)", logLevel: .debug)
}

func checksumLoadApprovedFiles() -> [String: String] {
    // imports the list of file hashes that are approved to run
    var outsetFileHashList = FileHashes()

    let defaults = UserDefaults.standard
    let hashes = defaults.object(forKey: "sha256sum")

    if let data = hashes as? [String: String] {
        for (key, value) in data {
            outsetFileHashList.sha256sum[key] = value
        }
    }

    return outsetFileHashList.sha256sum
}

func isNetworkUp() -> Bool {
    // https://stackoverflow.com/a/39782859/17584669
    // perform a check to see if the network is available.

    var zeroAddress = sockaddr_in(sin_len: 0, sin_family: 0, sin_port: 0, sin_addr: in_addr(s_addr: 0), sin_zero: (0, 0, 0, 0, 0, 0, 0, 0))
    zeroAddress.sin_len = UInt8(MemoryLayout.size(ofValue: zeroAddress))
    zeroAddress.sin_family = sa_family_t(AF_INET)

    let defaultRouteReachability = withUnsafePointer(to: &zeroAddress) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {zeroSockAddress in
            SCNetworkReachabilityCreateWithAddress(nil, zeroSockAddress)
        }
    }

    var flags: SCNetworkReachabilityFlags = SCNetworkReachabilityFlags(rawValue: 0)
    if SCNetworkReachabilityGetFlags(defaultRouteReachability!, &flags) == false {
        return false
    }

    let isReachable = (flags.rawValue & UInt32(kSCNetworkFlagsReachable)) != 0
    let needsConnection = (flags.rawValue & UInt32(kSCNetworkFlagsConnectionRequired)) != 0
    let ret = (isReachable && !needsConnection)

    return ret
}

func waitForNetworkUp(timeout: Double) -> Bool {
    // used during --boot if "wait_for_network" prefrence is true
    var networkUp = false
    let deadline = DispatchTime.now() + timeout
    while !networkUp && DispatchTime.now() < deadline {
        writeLog("Waiting for network: \(timeout) seconds", logLevel: .debug)
        networkUp = isNetworkUp()
        if !networkUp {
            writeLog("Waiting...", logLevel: .debug)
            Thread.sleep(forTimeInterval: 1)
        }
    }
    if !networkUp && DispatchTime.now() > deadline {
        writeLog("No network connectivity detected after \(timeout) seconds", logLevel: .error)
    }
    return networkUp
}

func loginWindowUpdateState(_ action: Action) {
    var cmd: String
    let loginWindowPlist: String = "/System/Library/LaunchDaemons/com.apple.loginwindow.plist"
    switch action {
    case .enable:
        writeLog("Enabling loginwindow process", logLevel: .debug)
        cmd = "/bin/launchctl load \(loginWindowPlist)"
    case .disable:
        writeLog("Disabling loginwindow process", logLevel: .debug)
        cmd = "/bin/launchctl unload \(loginWindowPlist)"
    }
        _ = runShellCommand(cmd)
}

func getDeviceHardwareModel() -> String {
    // Returns the current devices hardware model from sysctl
    var size = 0
    sysctlbyname("hw.model", nil, &size, nil, 0)
    var model = [CChar](repeating: 0, count: size)
    sysctlbyname("hw.model", &model, &size, nil, 0)
    return String(cString: model)
}

func getMarketingModel() -> String {
    let appleSiliconProduct = IORegistryEntryFromPath(kIOMasterPortDefault, "IOService:/AppleARMPE/product")
        let cfKeyValue = IORegistryEntryCreateCFProperty(appleSiliconProduct, "product-description" as CFString, kCFAllocatorDefault, 0)
        IOObjectRelease(appleSiliconProduct)
        let keyValue: AnyObject? = cfKeyValue?.takeUnretainedValue()
        if keyValue != nil, let data = keyValue as? Data {
            return String(data: data, encoding: String.Encoding.utf8)?.trimmingCharacters(in: CharacterSet(["\0"])) ?? ""
        }
        return ""
}

func getDeviceSerialNumber() -> String {
    // Returns the current devices serial number
    let platformExpert = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IOPlatformExpertDevice") )
      guard platformExpert > 0 else {
        return "Serial Unknown"
      }
      guard let serialNumber = (IORegistryEntryCreateCFProperty(platformExpert, kIOPlatformSerialNumberKey as CFString, kCFAllocatorDefault, 0).takeUnretainedValue() as? String)?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) else {
        return "Serial Unknown"
      }
      IOObjectRelease(platformExpert)
      return serialNumber
}

func getOSBuildVersion() -> String {
    // Returns the current OS build from sysctl
    var size = 0
    sysctlbyname("kern.osversion", nil, &size, nil, 0)
    var osversion = [CChar](repeating: 0, count: size)
    sysctlbyname("kern.osversion", &osversion, &size, nil, 0)
    return String(cString: osversion)

}

func getOSVersion() -> String {
    // Returns the OS version
    let osVersion = ProcessInfo().operatingSystemVersion
    let version = "\(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)"
    return version
}

func writeSysReport() {
    // Logs system information to log file
    writeLog("User: \(getConsoleUserInfo())", logLevel: .debug)
    writeLog("Model: \(getDeviceHardwareModel())", logLevel: .debug)
    writeLog("Marketing Model: \(getMarketingModel())", logLevel: .debug)
    writeLog("Serial: \(getDeviceSerialNumber())", logLevel: .debug)
    writeLog("OS: \(getOSVersion())", logLevel: .debug)
    writeLog("Build: \(getOSBuildVersion())", logLevel: .debug)
}

// swiftlint:enable line_length
