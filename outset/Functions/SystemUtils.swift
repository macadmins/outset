//
//  Functions.swift
//  outset
//
//  Created by Bart Reardon on 1/12/2022.
//

import Foundation
import SystemConfiguration
import OSLog

struct OutsetPreferences: Codable {
    var wait_for_network : Bool = false
    var network_timeout : Int = 180
    var ignored_users : [String] = []
    var override_login_once : [String:Date] = [String:Date]()
}

struct FileHashes: Codable {
    var sha256sum : [String:String] = [String:String]()
}

func ensure_root(_ reason : String) {
    if !is_root() {
        writeLog("Must be root to \(reason)", status: .error)
        exit(1)
    }
}

func is_root() -> Bool {
    return NSUserName() == "root"
}

func getValueForKey(_ key: String, inArray array: [String: String]) -> String? {
    // short function that treats a [String: String] as a key value pair.
    return array[key]
}

func writeLog(_ message: String, status: OSLogType = .info) {
    let logMessage = "\(message)"
    let bundleID = Bundle.main.bundleIdentifier ?? "io.macadmins.Outset"
    let log = OSLog(subsystem: bundleID, category: "main")
    os_log("%{public}@", log: log, type: status, logMessage)
    if status == .error || status == .info || (debugMode && status == .debug) {
        // print info, errors and debug to stdout
        print("\(oslogTypeToString(status).uppercased()): \(message)")
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
    let consoleUserName = runShellCommand("who | grep 'console' | awk '{print $1}'").output
    let consoleUserID = runShellCommand("id -u \(consoleUserName)").output
    return (consoleUserName.trimmingCharacters(in: .whitespacesAndNewlines), consoleUserID.trimmingCharacters(in: .whitespacesAndNewlines))
}

func write_outset_preferences(prefs: OutsetPreferences) {
    let defaults = UserDefaults.standard
    
    let path = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true)
    let prefsPath = path[0].appending("/Preferences").appending("/\(Bundle.main.bundleIdentifier!).plist")

    writeLog("Writing preference file: \(prefsPath)", status: .debug)
    
    // Take the OutsetPreferences object and write it to UserDefaults
    let mirror = Mirror(reflecting: prefs)
    for child in mirror.children {
        // Use the name of each property as the key, and save its value to UserDefaults
        if let propertyName = child.label {
            defaults.set(child.value, forKey: propertyName)
        }
    }
}

func load_outset_preferences() -> OutsetPreferences {
    let defaults = UserDefaults.standard
    var outsetPrefs = OutsetPreferences()
    
    outsetPrefs.network_timeout = defaults.integer(forKey: "network_timeout")
    outsetPrefs.ignored_users = defaults.array(forKey: "ignored_users") as? [String] ?? []
    outsetPrefs.override_login_once = defaults.object(forKey: "override_login_once") as? [String:Date] ?? [:]
    outsetPrefs.wait_for_network = defaults.bool(forKey: "wait_for_network")
    
    return outsetPrefs
}

func load_runonce() -> [String:Date] {
    let defaults = UserDefaults.standard
    var runOnceKey = "run_once"
    
    if is_root() {
        runOnceKey = runOnceKey+"-"+getConsoleUserInfo().username
    }
    return defaults.object(forKey: runOnceKey) as? [String:Date] ?? [:]
}

func write_runonce(runOnceData: [String:Date]) {
    let defaults = UserDefaults.standard
    var runOnceKey = "run_once"
    
    if is_root() {
        runOnceKey = runOnceKey+"-"+getConsoleUserInfo().username
    }
    defaults.set(runOnceData, forKey: runOnceKey)
}

func load_hashes() -> [String:String] {
    // imports the list of file hashes that are approved to run
    var outset_file_hash_list = FileHashes()
    
    let defaults = UserDefaults.standard
    let hashes = defaults.object(forKey: "sha256sum")

    if let data = hashes as? [String: String] {
        for (key, value) in data {
            outset_file_hash_list.sha256sum[key] = value
        }
    }

    return outset_file_hash_list.sha256sum
}

func network_up() -> Bool {
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

func wait_for_network_old(timeout : Double) -> Bool {
    var networkUp : Bool = false
    var networkCheck : DispatchWorkItem?
    for _ in 0..<Int(timeout) {
        networkCheck = DispatchWorkItem {}
        if network_up() {
            networkUp = true
            networkCheck?.cancel()
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(10), execute: networkCheck!)
        }
    }
    return networkUp
}

func wait_for_network(timeout: Double) -> Bool {
    // used during --boot if "wait_for_network" prefrence is true
    var networkUp = false
    let deadline = DispatchTime.now() + timeout
    while !networkUp && DispatchTime.now() < deadline {
        writeLog("Waiting for network: \(timeout) seconds", status: .debug)
        networkUp = network_up()
        if !networkUp {
            writeLog("Waiting...", status: .debug)
            Thread.sleep(forTimeInterval: 1)
        }
    }
    if !networkUp && DispatchTime.now() > deadline {
        writeLog("No network connectivity detected after \(timeout) seconds", status: .error)
    }
    return networkUp
}

func disable_loginwindow() {
    // Disables the loginwindow process
    writeLog("Disabling loginwindow process", status: .debug)
    let cmd = "/bin/launchctl unload /System/Library/LaunchDaemons/com.apple.loginwindow.plist"
    _ = runShellCommand(cmd)
}

func enable_loginwindow() {
    // Enables the loginwindow process
    writeLog("Enabling loginwindow process", status: .debug)
    let cmd = "/bin/launchctl load /System/Library/LaunchDaemons/com.apple.loginwindow.plist"
    _ = runShellCommand(cmd)
}

func get_hardwaremodel() -> String {
    // Returns the current devices hardware model from sysctl
    var size = 0
    sysctlbyname("hw.model", nil, &size, nil, 0)
    var model = [CChar](repeating: 0, count: size)
    sysctlbyname("hw.model", &model, &size, nil, 0)
    return String(cString: model)
}

func get_serialnumber() -> String {
    // Returns the current devices serial number
    // TODO: fix warning 'kIOMasterPortDefault' was deprecated in macOS 12.0: renamed to 'kIOMainPortDefault'
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

func get_buildversion() -> String {
    // Returns the current OS build from sysctl
    var size = 0
    sysctlbyname("kern.osversion", nil, &size, nil, 0)
    var osversion = [CChar](repeating: 0, count: size)
    sysctlbyname("kern.osversion", &osversion, &size, nil, 0)
    return String(cString: osversion)

}

func get_osversion() -> String {
    // Returns the OS version
    let osVersion = ProcessInfo().operatingSystemVersion
    let version = "\(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)"
    return version
}

func sys_report() {
    // Logs system information to log file
    writeLog("User: \(getConsoleUserInfo())", status: .debug)
    writeLog("Model: \(get_hardwaremodel())", status: .debug)
    writeLog("Serial: \(get_serialnumber())", status: .debug)
    writeLog("OS: \(get_osversion())", status: .debug)
    writeLog("Build: \(get_buildversion())", status: .debug)
}
