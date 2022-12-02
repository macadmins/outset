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

func shell(_ command: String) -> (output: String, error: String, exitCode: Int32) {
    let task = Process()
    let pipe = Pipe()
    let errorpipe = Pipe()
    
    var output : String = ""
    var error : String = ""
    
    task.standardOutput = pipe
    task.standardError = errorpipe
    task.arguments = ["-c", command]
    task.launchPath = "/bin/zsh"
    task.launch()
    
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let errordata = errorpipe.fileHandleForReading.readDataToEndOfFile()
    
    output.append(String(data: data, encoding: .utf8)!)
    error.append(String(data: errordata, encoding: .utf8)!)
    
    task.waitUntilExit()
    let status = task.terminationStatus
    
    return (output, error, status)
}


func ensure_working_folders() {
    let working_directories = [
        boot_every_dir,
        boot_once_dir,
        login_every_dir,
        login_once_dir,
        login_privileged_every_dir,
        login_privileged_once_dir,
        on_demand_dir,
        share_dir,
    ]
    
    for directory in working_directories {
        if !check_file_exists(path: directory, isDir: true) {
            //logging.info("%s does not exist, creating now.", directory)
            do {
                try FileManager.default.createDirectory(at: URL(filePath: directory), withIntermediateDirectories: true)
            } catch {
                print("could not create path at \(directory)")
            }
        }
    }
}

func ensure_shared_folder() {
    if !check_file_exists(path: share_dir) {
        logger("\(share_dir) does not exist, creating now.")
        do {
            try FileManager.default.createDirectory(atPath: share_dir, withIntermediateDirectories: true)
        } catch {
            logger("Something went wrong. \(share_dir) could not be created.")
        }
    }
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

func check_file_exists(path: String, isDir : ObjCBool = false) -> Bool {
    var checkIsDir : ObjCBool = isDir
    return FileManager.default.fileExists(atPath: path, isDirectory: &checkIsDir)
}

func list_folder(path: String) -> [String] {
    var filelist : [String] = []
    do {
        let files = try FileManager.default.contentsOfDirectory(atPath: path)
        for file in files {
            filelist.append("\(path)/\(file)")
        }
    } catch {
        return []
    }
    return filelist
}

func logger(_ log: String, status : String = "info") {
    print(log)
}

func dump_outset_preferences(prefs: OutsetPreferences) {
    logger("Initiating preference file: \(outset_preferences)")
    let encoder = PropertyListEncoder()
    encoder.outputFormat = .xml
    do {
        let data = try encoder.encode(prefs)
        try data.write(to: URL(filePath: outset_preferences))
    } catch {
        print("encoding plist failed")
    }
}

func load_outset_preferences() -> OutsetPreferences {
    var outsetPrefs = OutsetPreferences()
    if !check_file_exists(path: outset_preferences) {
        dump_outset_preferences(prefs: OutsetPreferences())
    }
    
    let url = URL(filePath: outset_preferences)
    do {
        let data = try Data(contentsOf: url)
        outsetPrefs = try PropertyListDecoder().decode(OutsetPreferences.self, from: data)
    } catch {
        print("plist import failed")
    }
    
    return outsetPrefs
}

func load_runonce(plist: String) -> RunOncePlist {
    var runOncePlist = RunOncePlist()
    if check_file_exists(path: plist) {
        let url = URL(filePath: plist)
        do {
            let data = try Data(contentsOf: url)
            runOncePlist = try PropertyListDecoder().decode(RunOncePlist.self, from: data)
        } catch {
            print("plist import failed")
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
    let platformExpert = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice") )
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

func path_cleanup(pathname : String) {
    // check if folder and clean all files in that folder
    // Deletes given script or cleans folder
    if check_file_exists(path: pathname, isDir: true) {
        for fileItem in list_folder(path: pathname) {
            delete_file(fileItem)
        }
    } else if check_file_exists(path: pathname) {
        delete_file(pathname)
    } else {
        logger("\(pathname) doesn't seem to exist", status: "error")
    }
}

func delete_file(_ path : String) {
    do {
        try FileManager.default.removeItem(atPath: path)
    } catch {
        logger("\(path) could not be removed", status: "error")
    }
}

func mount_dmg(dmg : String) -> String {
    // Attaches dmg
    let cmd = "/usr/bin/hdiutil attach -nobrowse -noverify -noautoopen \(dmg)"
    logger("Attaching \(dmg)")
    let (output, error, status) = shell(cmd)
    if status != 0 {
        return error
    }
    return output.trimmingCharacters(in: .whitespacesAndNewlines)
}

func detach_dmg(dmg_mount : String) -> String {
    // Detaches dmg
    logger("Detaching \(dmg_mount)")
    let cmd = "/usr/bin/hdiutil detach -force \(dmg_mount)"
    let (output, error, status) = shell(cmd)
    if status != 0 {
        return error
    }
    return output.trimmingCharacters(in: .whitespacesAndNewlines)
}

func check_perms(pathname : String) -> Bool {
    return true
}

func install_package(pkg : String) -> Bool {
    // Installs pkg onto boot drive
    var pkg_to_install : String = ""
    var dmg_mount : String = ""
    
    if pkg.lowercased().hasSuffix("dmg") {
        dmg_mount = mount_dmg(dmg: pkg)
        for files in list_folder(path: dmg_mount) {
            if ["pkg", "mpkg"].contains(files.lowercased().suffix(3)) {
                pkg_to_install = dmg_mount
            }
        }
    } else if ["pkg", "mpkg"].contains(pkg.lowercased().suffix(3)) {
        pkg_to_install = pkg
    }
    logger("Installing \(pkg_to_install)")
    let cmd = "/usr/sbin/installer -pkg \(pkg_to_install) -target /"
    let (output, error, status) = shell(cmd)
    if status != 0 {
        logger(error, status: "error")
    } else {
        logger(output)
    }
    
    
    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(5)) {
        if !dmg_mount.isEmpty {
            logger(detach_dmg(dmg_mount: dmg_mount))
        }
    }
    return true
}

func install_profile(pathname : String) -> Bool {
    return true
}


func process_items(_ path: String, delete_items : Bool=false, once : Bool=false, override : [String:Date] = [:]) {
    // Processes scripts/packages to run
    if !check_file_exists(path: path) {
        logger("\(path) does not exist. Exiting")
        exit(1)
    }
    
    var items_to_process : [String] = []
    var packages : [String] = []
    var scripts : [String] = []
    var profiles : [String] = []
    var runOnceDict : RunOncePlist = RunOncePlist()
    
    items_to_process = list_folder(path: path)
    print(items_to_process)
    
    for pathname in items_to_process {
        if check_perms(pathname: pathname) {
            if ["pkg", "mpkg", "dmg"].contains(pathname.lowercased().suffix(3)) {
                packages.append(pathname)
            } else if pathname.lowercased().hasSuffix("mobileconfig") {
                profiles.append(pathname)
            } else {
                scripts.append(pathname)
            }
        } else {
            logger("Bad permissions: \(pathname)", status: "error")
        }
    }
    
    if once {
        runOnceDict = load_runonce(plist: run_once_plist)
    }
    
    for package in packages {
        if once {
            if !runOnceDict.override_login_once.contains(where: {$0.key == package}) {
                if install_package(pkg: package) {
                    runOnceDict.override_login_once.updateValue(.now, forKey: package)
                }
            } else {
                if override.contains(where: {$0.key == package}) {
                    if override[package]! > runOnceDict.override_login_once[package]! {
                        if install_package(pkg: package) {
                            runOnceDict.override_login_once.updateValue(.now, forKey: package)
                        }
                    }
                }
            }
        } else {
            _ = install_package(pkg: package)
        }
        if delete_items {
            path_cleanup(pathname: package)
        }
    }
    
    /*
    for profile in profiles {
        // NO PROFILE SUPPORT
    }
     */
    
    for script in scripts {
        if once {
            if !runOnceDict.override_login_once.contains(where: {$0.key == script}) {
                let (output, error, status) = shell(script)
                if status != 0 {
                    logger(error, status: "error")
                } else {
                    runOnceDict.override_login_once.updateValue(.now, forKey: script)
                    logger(output)
                }
            } else {
                if override.contains(where: {$0.key == script}) {
                    if override[script]! > runOnceDict.override_login_once[script]! {
                        let (output, error, status) = shell(script)
                        if status != 0 {
                            logger(error, status: "error")
                        } else {
                            runOnceDict.override_login_once.updateValue(.now, forKey: script)
                            logger(output)
                        }
                    }
                }
            }
        } else {
            let (_, error, status) = shell(script)
            if status != 0 {
                logger(error, status: "error")
            }
        }
        if delete_items {
            path_cleanup(pathname: script)
        }
    }
}
