//
//  Functions.swift
//  outset
//
//  Created by Bart Reardon on 1/12/2022.
//

import Foundation
import SystemConfiguration

struct OutsetPreferences: Codable {
    var wait_for_network : Bool = false
    var network_timeout : Int = 180
    var ignored_users : [String] = []
    var override_login_once : [String:Date] = [String:Date]()
}

struct RunOncePlist: Codable {
    var override_login_once : [String:Date] = [String:Date]()
}

func ensure_root(_ reason : String) {
    if !is_root() {
        logger("Must be root to \(reason)", status: "error")
        exit(1)
    }
}

func is_root() -> Bool {
    return NSUserName() == "root"
}

func logger(_ log: String, status : String = "info") {
    if status.lowercased() == "debug" {
        if debugMode {
            print("DEBUG: \(log)")
        }
    } else {
        print("\(status.uppercased()): \(log)")
    }
}

func set_run_once_params() ->(logFile: String, runOncePlist: String) {
    var logFile: String = ""
    var runOncePlist: String = ""
    if  is_root() {
        logFile = "/var/log/outset.log"
        var (console_uid, _, _) = shell("id -u $(who | grep 'console' | awk '{print $1}')")
        console_uid = console_uid.trimmingCharacters(in: .whitespacesAndNewlines)
        runOncePlist = "\(share_dir)com.github.outset.once.\(console_uid).plist"
    } else {
        let userHomePath = FileManager.default.homeDirectoryForCurrentUser.relativeString.replacingOccurrences(of: "file://", with: "")
        let userLogsPath = userHomePath+"Library/Logs"
        if !check_file_exists(path: userLogsPath, isDir: true) {
            do {
                try FileManager.default.createDirectory(atPath: userLogsPath, withIntermediateDirectories: true)
            } catch {
                logger("Could not create \(userLogsPath)", status: "error")
                exit(1)
            }
        }
        logFile = userLogsPath+"/outset.log"
        runOncePlist = userHomePath+"Library/Preferences/com.github.outset.once.plist"
    }
    return (logFile, runOncePlist)
}

func dump_outset_preferences(prefs: OutsetPreferences) {
    logger("Writing preference file: \(outset_preferences)", status: "debug")
    let encoder = PropertyListEncoder()
    encoder.outputFormat = .xml
    do {
        let data = try encoder.encode(prefs)
        try data.write(to: URL(fileURLWithPath: outset_preferences))
    } catch {
        logger("encoding plist failed", status: "error")
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
        logger("plist import failed", status: "error")
    }
    
    return outsetPrefs
}

func load_runonce(plist: String) -> RunOncePlist {
    var runOncePlist = RunOncePlist()
    if check_file_exists(path: plist) {
        let url = URL(fileURLWithPath: plist)
        do {
            let data = try Data(contentsOf: url)
            runOncePlist = try PropertyListDecoder().decode(RunOncePlist.self, from: data)
        } catch {
            logger("plist import failed", status: "error")
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

func wait_for_network(timeout : Double) -> Bool {
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

func disable_loginwindow() {
    // Disables the loginwindow process
    logger("Disabling loginwindow process")
    let cmd = "/bin/launchctl unload /System/Library/LaunchDaemons/com.apple.loginwindow.plist"
    _ = shell(cmd)
}

func enable_loginwindow() {
    // Enables the loginwindow process
    logger("Disabling loginwindow process")
    let cmd = "/bin/launchctl load /System/Library/LaunchDaemons/com.apple.loginwindow.plist"
    _ = shell(cmd)
}

func get_hardwaremodel() -> String {
    // Returns the hardware model of the Mac
    let cmd = "/usr/sbin/sysctl -n hw.model"
    let (output, error, status) = shell(cmd)
    if status != 0 {
        return error
    }
    return output.trimmingCharacters(in: .whitespacesAndNewlines)
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
    let cmd = "/usr/sbin/sysctl -n kern.osversion"
    let (output, error, status) = shell(cmd)
    if status != 0 {
        return error
    }
    return output.trimmingCharacters(in: .whitespacesAndNewlines)
}

func get_osversion() -> String {
    let version = [String(ProcessInfo().operatingSystemVersion.majorVersion),
                   String(ProcessInfo().operatingSystemVersion.minorVersion),
                   String(ProcessInfo().operatingSystemVersion.patchVersion)]
    return version.joined(separator: ".")
}

func sys_report() {
    // Logs system information to log file
    logger("Model: \(get_hardwaremodel())", status: "debug")
    logger("Serial: \(get_serialnumber())", status: "debug")
    logger("OS: \(get_osversion())", status: "debug")
    logger("Build: \(get_buildversion())", status: "debug")
}
