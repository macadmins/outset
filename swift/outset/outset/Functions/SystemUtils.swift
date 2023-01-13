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


func ensure_root(_ reason : String) {
    if !is_root() {
        writeLog("Must be root to \(reason)", status: .error)
        exit(1)
    }
}

func is_root() -> Bool {
    return NSUserName() == "root"
}

func writeLog(_ message: String, status: OSLogType = .info) {
    let logMessage = "\(message)"
    let log = OSLog(subsystem: "com.github.outset", category: "main")
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
    let consoleUserName = runShellCommand("who | grep 'console' | awk '{print $1}'").output
    let consoleUserID = runShellCommand("id -u \(consoleUserName)").output
    return (consoleUserName.trimmingCharacters(in: .whitespacesAndNewlines), consoleUserID.trimmingCharacters(in: .whitespacesAndNewlines))
}


func set_run_once_params() ->(logFile: String, runOncePlist: String) {
    var logFile: String = ""
    var runOncePlist: String = ""
    if  is_root() {
        logFile = "/var/log/outset.log"
        let console_uid = getConsoleUserInfo().userID
        runOncePlist = "\(share_dir)com.github.outset.once.\(console_uid).plist"
    } else {
        let userHomePath = FileManager.default.homeDirectoryForCurrentUser.relativeString.replacingOccurrences(of: "file://", with: "")
        let userLogsPath = userHomePath+"Library/Logs"
        if !check_file_exists(path: userLogsPath, isDir: true) {
            do {
                try FileManager.default.createDirectory(atPath: userLogsPath, withIntermediateDirectories: true)
            } catch {
                writeLog("Could not create \(userLogsPath)", status: .error)
                exit(1)
            }
        }
        logFile = userLogsPath+"/outset.log"
        runOncePlist = userHomePath+"Library/Preferences/com.github.outset.once.plist"
    }
    return (logFile, runOncePlist)
}

func dump_outset_preferences(prefs: OutsetPreferences) {
    writeLog("Writing preference file: \(outset_preferences)", status: .debug)
    let encoder = PropertyListEncoder()
    encoder.outputFormat = .xml
    do {
        let data = try encoder.encode(prefs)
        try data.write(to: URL(fileURLWithPath: outset_preferences))
    } catch {
        writeLog("encoding plist failed", status: .error)
    }
}

func load_outset_preferences() -> OutsetPreferences {
    var outsetPrefs = OutsetPreferences()
    if !check_file_exists(path: outset_preferences) {
        dump_outset_preferences(prefs: OutsetPreferences())
    }
    
    let url = URL(fileURLWithPath: outset_preferences)
    do {
        let data = try Data(contentsOf: url)
        outsetPrefs = try PropertyListDecoder().decode(OutsetPreferences.self, from: data)
    } catch {
        writeLog("outset preferences plist import failed", status: .error)
    }
    
    return outsetPrefs
}

func load_runonce(plist: String) -> [String:Date] {
    var runOncePlist = [String:Date]()
    if check_file_exists(path: plist) {
        let url = URL(fileURLWithPath: plist)
        do {
            let data = try Data(contentsOf: url)
            runOncePlist = try PropertyListDecoder().decode([String:Date].self, from: data)
        } catch {
            writeLog("runonce plist import failed", status: .error)
        }
    }
    return runOncePlist
}

func network_up() -> Bool {
    // https://stackoverflow.com/a/39782859/17584669
    
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
    var size = 0
    sysctlbyname("hw.model", nil, &size, nil, 0)
    var model = [CChar](repeating: 0, count: size)
    sysctlbyname("hw.model", &model, &size, nil, 0)
    return String(cString: model)
}

func get_serialnumber() -> String {
    // Returns the serial number of the Mac
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
    var size = 0
    sysctlbyname("kern.osversion", nil, &size, nil, 0)
    var osversion = [CChar](repeating: 0, count: size)
    sysctlbyname("kern.osversion", &osversion, &size, nil, 0)
    return String(cString: osversion)

}

func get_osversion() -> String {
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
