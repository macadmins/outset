//
//  Processing.swift
//  outset
//
//  Created by Bart Reardon on 3/12/2022.
//
// swiftlint:disable cyclomatic_complexity

import Foundation

func processItems(_ payloadType: PayloadType, deleteItems: Bool=false, once: Bool=false, override: RunOnce = [:]) {
    // Main processing logic
    let path = payloadType.directoryPath

    if !checkFileExists(path: path) {
        writeLog("\(path) does not exist. Exiting")
        exit(1)
    }

    // Profile support has been removed in Outset v4
    var itemsToProcess: [String] = []    // raw list of files
    var packages: [String] = []            // array of packages once they have passed checks
    var scripts: [String] = []             // array of scripts once they have passed checks

    // See if there's any old stuff to migrate
    // Perform this each processing run to pick up individual user preferences as well
    migrateLegacyPreferences()

    // Get a list of all the files to process
    itemsToProcess = folderContents(path: path)

    // iterate over the list and check the
    for pathname in itemsToProcess {
        if verifyPermissions(pathname: pathname) {
            switch pathname.split(separator: ".").last {
            case "pkg", "mpkg", "dmg":
                packages.append(pathname)
            default:
                scripts.append(pathname)
            }
        } else {
            writeLog("Bad permissions: \(pathname)", logLevel: .error)
        }
    }

    // Process Packages
    processPackages(packages: packages, once: once, override: override, deleteItems: deleteItems)

    // Process Scripts
    processScripts(scripts: scripts, once: once, override: override, deleteItems: deleteItems)

}

func processPackages(packages: [String], once: Bool=false, override: RunOnce = [:], deleteItems: Bool=false) {
    // load validation checks
    let checksumList = checksumLoadApprovedFiles()
    let checksumsAvailable = !checksumList.isEmpty

    // load runonce data
    var runOnce = loadRunOncePlist()

    // loop through the packages list and process installs.
    for package in packages {
        if checksumsAvailable && !verifySHASUMForFile(filename: package, shasumArray: checksumList) {
            continue
        }

        if once {
            if !runOnce.contains(where: {$0.key == package}) {
                if installPackage(pkg: package) {
                    runOnce.updateValue(Date(), forKey: package)
                }
            } else {
                if override.contains(where: {$0.key == package}) {
                    writeLog("override for \(package) dated \(override[package]!)", logLevel: .debug)
                    if override[package]! > runOnce[package]! {
                        writeLog("Actioning package override", logLevel: .debug)
                        if installPackage(pkg: package) {
                            runOnce.updateValue(Date(), forKey: package)
                        }
                    }
                }
            }
        } else {
            _ = installPackage(pkg: package)
        }
        if deleteItems {
            pathCleanup(package)
        }
    }

    if !runOnce.isEmpty {
        writeRunOncePlist(runOnceData: runOnce)
    }

}

func processScripts(scripts: [String], altName: String = "", once: Bool=false, override: RunOnce = [:], deleteItems: Bool=false) {
    // load validation checks
    let checksumList = checksumLoadApprovedFiles()
    let checksumsAvailable = !checksumList.isEmpty

    // load runonce data
    var runOnce = loadRunOncePlist(bootOnce: isRoot ? true : once)
    writeLog("runOnce = \(runOnce)", logLevel: .debug)

    // loop through the scripts list and process.
    for script in scripts {
        if checksumsAvailable && !verifySHASUMForFile(filename: script, shasumArray: checksumList) {
            continue
        }

        let scriptName = altName.isEmpty ? script : altName

        if once {
            writeLog("Processing run-once \(scriptName)", logLevel: .info)
            // If this is supposed to be a runonce item then we want to check to see if has an existing runonce entry
            // looks for a key with the full script path. Writes the full path and run date when done
            if !runOnce.contains(where: {$0.key == scriptName}) {
                writeLog("run-once not yet processed. proceeding", logLevel: .debug)
                let (output, error, status) = runShellCommand(script, args: [consoleUser], verbose: true)
                if status != 0 {
                    writeLog(error, logLevel: .error)
                } else {
                    runOnce.updateValue(Date(), forKey: scriptName)
                    writeLog(output)
                }
            } else {
                // there's a run-once plist entry for this script. Check to see if there's an override
                writeLog("checking for override", logLevel: .debug)
                if override.contains(where: {$0.key == scriptName}) {
                    writeLog("override for \(scriptName) dated \(override[scriptName]!)", logLevel: .debug)
                    if override[scriptName]! > runOnce[scriptName]! {
                        writeLog("Actioning script override", logLevel: .debug)
                        let (output, error, status) = runShellCommand(script, args: [consoleUser], verbose: true)
                        if status != 0 {
                            writeLog(error, logLevel: .error)
                        } else {
                            runOnce.updateValue(Date(), forKey: scriptName)
                            if !output.isEmpty {
                                writeLog(output, logLevel: .debug)
                            }
                        }
                    }
                } else {
                    writeLog("no override for \(scriptName)", logLevel: .debug)
                }
            }
        } else {
            writeLog("Processing script \(scriptName)", logLevel: .info)
            let (_, error, status) = runShellCommand(script, args: [consoleUser], verbose: true)
            if status != 0 {
                writeLog(error, logLevel: .error)
            }
        }
        if deleteItems {
            pathCleanup(script)
        }
    }

    if !runOnce.isEmpty {
        writeRunOncePlist(runOnceData: runOnce, bootOnce: isRoot)
    }
}

// swiftlint:enable cyclomatic_complexity
