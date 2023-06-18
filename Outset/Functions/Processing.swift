//
//  Processing.swift
//  outset
//
//  Created by Bart Reardon on 3/12/2022.
//
// swiftlint:disable function_body_length cyclomatic_complexity

import Foundation

func processItems(_ path: String, deleteItems: Bool=false, once: Bool=false, override: [String: Date] = [:]) {
    // Main processing logic

    if !checkFileExists(path: path) {
        writeLog("\(path) does not exist. Exiting")
        exit(1)
    }

    // Profile support has been removed in Outset v4
    var itemsToProcess: [String] = []    // raw list of files
    var packages: [String] = []            // array of packages once they have passed checks
    var scripts: [String] = []             // array of scripts once they have passed checks
    var runOnceDict: [String: Date] = [:]

    let shasumFileList = shasumLoadApprovedFileHashList()
    let shasumsAvailable = !shasumFileList.isEmpty

    // See if there's any old stuff to migrate
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

    // load runonce data
    runOnceDict = loadRunOnce()

    // loop through the packages list and process installs.
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
                    writeLog("override for \(package) dated \(override[package]!)", logLevel: .debug)
                    if override[package]! > runOnceDict[package]! {
                        writeLog("Actioning package override", logLevel: .debug)
                        if installPackage(pkg: package) {
                            runOnceDict.updateValue(Date(), forKey: package)
                        }
                    }
                }
            }
        } else {
            _ = installPackage(pkg: package)
        }
        if deleteItems {
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
                let (output, error, status) = runShellCommand(script, args: [consoleUser], verbose: true)
                if status != 0 {
                    writeLog(error, logLevel: .error)
                } else {
                    runOnceDict.updateValue(Date(), forKey: script)
                    writeLog(output)
                }
            } else {
                // there's a run-once plist entry for this script. Check to see if there's an override
                if override.contains(where: {$0.key == script}) {
                    writeLog("override for \(script) dated \(override[script]!)", logLevel: .debug)
                    if override[script]! > runOnceDict[script]! {
                        writeLog("Actioning script override", logLevel: .debug)
                        let (output, error, status) = runShellCommand(script, args: [consoleUser], verbose: true)
                        if status != 0 {
                            writeLog(error, logLevel: .error)
                        } else {
                            runOnceDict.updateValue(Date(), forKey: script)
                            if !output.isEmpty {
                                writeLog(output, logLevel: .debug)
                            }
                        }
                    }
                }
            }
        } else {
            let (_, error, status) = runShellCommand(script, args: [consoleUser], verbose: true)
            if status != 0 {
                writeLog(error, logLevel: .error)
            }
        }
        if deleteItems {
            pathCleanup(pathname: script)
        }
    }

    if !runOnceDict.isEmpty {
        writeRunOnce(runOnceData: runOnceDict)
    }

}

// swiftlint:enable function_body_length cyclomatic_complexity
