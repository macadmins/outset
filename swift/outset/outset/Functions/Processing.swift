//
//  Processing.swift
//  outset
//
//  Created by Bart Reardon on 3/12/2022.
//

import Foundation

func process_items(_ path: String, delete_items : Bool=false, once : Bool=false, override : [String:Date] = [:]) {
    // Main processing logic
    // TODO: should be able to break this into seperate functions if it helps readability or if seperate components are needed elsewhere individually
    if !check_file_exists(path: path) {
        writeLog("\(path) does not exist. Exiting")
        exit(1)
    }

    // TODO: There's been some discussion that in modern macOS, supporting package installs should not be required as well as profiles
    var items_to_process : [String] = []    // raw list of files
    var packages : [String] = []            // array of packages once they have passed checks
    var scripts : [String] = []             // array of scripts once they have passed checks
    var profiles : [String] = []            // profiles aren't supported anyway so we could delete this
    var runOnceDict : [String:Date] = [:]
    
    // Get a list of all the files to process
    items_to_process = list_folder(path: path)
    
    // iterate over the list and check the
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
    
    // load the runonce plist if needed
    // TODO: could load this anyway and perform runonce logic based on the bool. this dict is only used if once is true
    if once {
        runOnceDict = load_runonce(plist: run_once_plist)
    }
    
    // loop through the packages list and process installs.
    // TODO: add in hash comparison for processing packages presuming package installs as a feature is maintained.
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
    
    // loop through the scripts list and process.
    for script in scripts {
        if hashes_available {
            // check user defaults for a list of sha256 hashes.
            // This block will run if there are _any_ hashes available so it's all or nothing (by design)
            // If there is no hash or it doesn't match then we skip to the next file
            
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
            // If this is supposed to be a runonce item then we want to check to see if has an existing runonce entry
            // looks for a key with the full script path. Writes the full path and run date when done
            if !runOnceDict.contains(where: {$0.key == script}) {
                let (output, error, status) = runShellCommand(script, verbose: true)
                if status != 0 {
                    writeLog(error, status: .error)
                } else {
                    runOnceDict.updateValue(Date(), forKey: script)
                    writeLog(output)
                }
            } else {
                // there's a run-once plist entry for this script. Check to see if there's an override
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
        // write the results of runonce processing
        // if running as root, will write to /usr/local/outset/share/com.github.outset.once.<user_id>.plist
        // if running as the user, will write to ~/Library/Preferences/com.github.outset.once.plist
        // TODO: Move this logic to use UserDefaults
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

