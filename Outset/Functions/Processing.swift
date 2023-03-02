//
//  Processing.swift
//  outset
//
//  Created by Bart Reardon on 3/12/2022.
//

import Foundation

func processItems(_ path: String, delete_items : Bool=false, once : Bool=false, override : [String:Date] = [:]) {
    // Main processing logic
    // TODO: should be able to break this into seperate functions if it helps readability or if seperate components are needed elsewhere individually
    if !checkFileExists(path: path) {
        writeLog("\(path) does not exist. Exiting")
        exit(1)
    }

    // TODO: There's been some discussion that in modern macOS, supporting package installs. 
    // Profile support has been removed in Outset v4
    var items_to_process : [String] = []    // raw list of files
    var packages : [String] = []            // array of packages once they have passed checks
    var scripts : [String] = []             // array of scripts once they have passed checks
    var runOnceDict : [String:Date] = [:]
    
    let shasumFileList = shasumLoadApprovedFileHashList()
    let shasumsAvailable = !shasumFileList.isEmpty
    
    // See if there's any old stuff to migrate
    migrateLegacyPreferences()
    
    // Get a list of all the files to process
    items_to_process = folderContents(path: path)
    
    // iterate over the list and check the
    for pathname in items_to_process {
        if verifyPermissions(pathname: pathname) {
            switch pathname.split(separator: ".").last {
            case "pkg", "mpkg", "dmg":
                packages.append(pathname)
            default:
                scripts.append(pathname)
            }
        } else {
            writeLog("Bad permissions: \(pathname)", status: .error)
        }
    }
    
    // load runonce data
    runOnceDict = loadRunOnce()
    
    // loop through the packages list and process installs.
    // TODO: add in hash comparison for processing packages presuming package installs as a feature is maintained.
    for package in packages {
        if shasumsAvailable && !verifySHASUMForFile(filename: package, shasumArray: shasumFileList) {
            continue
        }
            
        if once {
            if !runOnceDict.contains(where: {$0.key == package}) {
                if installPackage(pkg: package) {
                    runOnceDict.updateValue(Date(), forKey: package)
                }
            } else {
                if override.contains(where: {$0.key == package}) {
                    writeLog("override for \(package) dated \(override[package]!)", status: .debug)
                    if override[package]! > runOnceDict[package]! {
                        writeLog("Actioning package override", status: .debug)
                        if installPackage(pkg: package) {
                            runOnceDict.updateValue(Date(), forKey: package)
                        }
                    }
                }
            }
        } else {
            _ = installPackage(pkg: package)
        }
        if delete_items {
            pathCleanup(pathname: package)
        }
    }
        
    // loop through the scripts list and process.
    for script in scripts {
        if shasumsAvailable && !verifySHASUMForFile(filename: script, shasumArray: shasumFileList) {
            continue
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
            pathCleanup(pathname: script)
        }
    }
    
    if !runOnceDict.isEmpty {
        writeRunOnce(runOnceData: runOnceDict)
    }
    
}


func installPackage(pkg : String) -> Bool {
    // Installs pkg onto boot drive
    if isRoot() {
        var pkg_to_install : String = ""
        var dmg_mount : String = ""
        
        if pkg.lowercased().hasSuffix("dmg") {
            dmg_mount = mountDmg(dmg: pkg)
            for files in folderContents(path: dmg_mount) {
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
                writeLog(detachDmg(dmgMount: dmg_mount))
            }
        }
        return true
    } else {
        writeLog("Unable to process \(pkg)", status: .error)
        writeLog("Must be root to install packages", status: .error)
    }
    return false
}

