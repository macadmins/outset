//
//  Processing.swift
//  outset
//
//  Created by Bart Reardon on 3/12/2022.
//

import Foundation

func process_items(_ path: String, delete_items : Bool=false, once : Bool=false, override : [String:Date] = [:]) {
    // Processes scripts/packages to run
    if !check_file_exists(path: path) {
        writeLog("\(path) does not exist. Exiting")
        exit(1)
    }
    
    var items_to_process : [String] = []
    var packages : [String] = []
    var scripts : [String] = []
    var profiles : [String] = []
    var runOnceDict : [String:Date] = [:]
    
    items_to_process = list_folder(path: path)
    
    for pathname in items_to_process {
        if check_permissions(pathname: pathname) {
            switch pathname.split(separator: ".").last {
            case "pkg", "mpkg", "dmg":
                packages.append(pathname)
            case "mobileconfig":
                profiles.append(pathname)
            default:
                scripts.append(pathname)
            }
        } else {
            writeLog("Bad permissions: \(pathname)", status: .error)
        }
    }
    
    if once {
        runOnceDict = load_runonce(plist: run_once_plist)
    }
    
    for package in packages {
        if once {
            if !runOnceDict.contains(where: {$0.key == package}) {
                if install_package(pkg: package) {
                    runOnceDict.updateValue(Date(), forKey: package)
                }
            } else {
                if override.contains(where: {$0.key == package}) {
                    writeLog("override for \(package) dated \(override[package]!)", status: .debug)
                    if override[package]! > runOnceDict[package]! {
                        writeLog("Actioning package override", status: .debug)
                        if install_package(pkg: package) {
                            runOnceDict.updateValue(Date(), forKey: package)
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
        if hashes_available {
            var proceed = false
            writeLog("checking hash for \(script)", status: .debug)
            if let storedHash = getValueForKey(script, inArray: file_hashes) {
                writeLog("stored hash : \(storedHash)", status: .debug)
                let url = URL(fileURLWithPath: script)
                if let fileHash = sha256(for: url) {
                    writeLog("file hash : \(fileHash)", status: .debug)
                    if storedHash == fileHash {
                        proceed = true
                    }
                }
            }
            if !proceed {
                writeLog("file hash mismatch for: \(script). Skipping", status: .error)
                continue
            }
        }
        if once {
            if !runOnceDict.contains(where: {$0.key == script}) {
                let (output, error, status) = runShellCommand(script, verbose: true)
                if status != 0 {
                    writeLog(error, status: .error)
                } else {
                    runOnceDict.updateValue(Date(), forKey: script)
                    writeLog(output)
                }
            } else {
                if override.contains(where: {$0.key == script}) {
                    writeLog("override for \(script) dated \(override[script]!)", status: .debug)
                    if override[script]! > runOnceDict[script]! {
                        writeLog("Actioning script override", status: .debug)
                        let (output, error, status) = runShellCommand(script, verbose: true)
                        if status != 0 {
                            writeLog(error, status: .error)
                        } else {
                            runOnceDict.updateValue(Date(), forKey: script)
                            if !output.isEmpty {
                                writeLog(output, status: .debug)
                            }
                        }
                    }
                }
            }
        } else {
            let (_, error, status) = runShellCommand(script, verbose: true)
            if status != 0 {
                writeLog(error, status: .error)
            }
        }
        if delete_items {
            path_cleanup(pathname: script)
        }
    }
    
    if !runOnceDict.isEmpty {
        writeLog("Writing login-once preference file: \(run_once_plist)", status: .debug)
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        do {
            let data = try encoder.encode(runOnceDict)
            try data.write(to: URL(fileURLWithPath: run_once_plist))
        } catch {
            writeLog("Writing to \(run_once_plist) failed", status: .error)
        }
    }
    
}


func install_package(pkg : String) -> Bool {
    // Installs pkg onto boot drive
    if is_root() {
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
        writeLog("Installing \(pkg_to_install)")
        let cmd = "/usr/sbin/installer -pkg \(pkg_to_install) -target /"
        let (output, error, status) = runShellCommand(cmd, verbose: true)
        if status != 0 {
            writeLog(error, status: .error)
        } else {
            writeLog(output)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(5)) {
            if !dmg_mount.isEmpty {
                writeLog(detach_dmg(dmgMount: dmg_mount))
            }
        }
        return true
    } else {
        writeLog("Unable to process \(pkg)", status: .error)
        writeLog("Must be root to install packages", status: .error)
    }
    return false
}

func install_profile(pathname : String) -> Bool {
    return false
}

