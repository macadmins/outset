//
//  Processing.swift
//  outset
//
//  Created by Bart Reardon on 3/12/2022.
//
// swiftlint:disable cyclomatic_complexity

import Foundation

func processItems(_ payloadType: PayloadType, consoleUser: String, deleteItems: Bool=false, once: Bool=false, override: RunOnce = [:]) {
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
    processScripts(scripts: scripts, consoleUser: consoleUser, once: once, override: override, deleteItems: deleteItems)

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

func processScripts(scripts: [String], consoleUser: String, altName: String = "", once: Bool=false, override: RunOnce = [:], deleteItems: Bool=false) {
    // load validation checks
    let checksumList = checksumLoadApprovedFiles()
    let checksumsAvailable = !checksumList.isEmpty

    // load runonce data
    var runOnce = loadRunOncePlist(bootOnce: isRoot ? true : once)
    writeLog("runOnce = \(runOnce)", logLevel: .debug)

    // Separate scripts into foreground (normal) and background (_-prefixed) lists.
    // Checksums and permissions have already been verified before we get here, so
    // we split purely on filename prefix.
    var foregroundScripts: [String] = []
    var backgroundScripts: [String] = []

    for script in scripts {
        if checksumsAvailable && !verifySHASUMForFile(filename: script, shasumArray: checksumList) {
            continue
        }
        if URL(fileURLWithPath: script).lastPathComponent.hasPrefix("_") {
            backgroundScripts.append(script)
        } else {
            foregroundScripts.append(script)
        }
    }

    // ── Background execution ───────────────────────────────────────────────────
    // Background scripts are dispatched first so they begin running immediately,
    // in parallel with the foreground scripts that follow on the current thread.
    if !backgroundScripts.isEmpty {
        let group = DispatchGroup()
        let timeout = prefs.backgroundScriptTimeout   // nil = no limit
        // Serialise run-once writes from background tasks to avoid data races
        let runOnceLock = DispatchQueue(label: "io.macadmins.outset.runonce")

        for script in backgroundScripts {
            let scriptName = altName.isEmpty ? script : altName

            group.enter()
            DispatchQueue.global().async {
                var taskProcess: Process?

                // Log launch with a temporary tag; we'll get the real PID below
                writeLog("[BG] Launching background script: \(scriptName)", logLevel: .info)

                // Check run-once before launching (read under lock for safety)
                var shouldRun = true
                var isOverride = false
                if once {
                    runOnceLock.sync {
                        if runOnce.contains(where: { $0.key == scriptName }) {
                            if override.contains(where: { $0.key == scriptName }),
                               let overrideDate = override[scriptName],
                               let ranDate = runOnce[scriptName],
                               overrideDate > ranDate {
                                isOverride = true
                            } else {
                                shouldRun = false
                            }
                        }
                    }
                }

                guard shouldRun else {
                    writeLog("[BG] Skipping \(scriptName) — already processed (run-once)", logLevel: .debug)
                    group.leave()
                    return
                }

                if isOverride {
                    writeLog("[BG] Actioning script override for \(scriptName)", logLevel: .debug)
                }

                // Set up timeout watchdog before launching
                var timeoutItem: DispatchWorkItem?
                if let seconds = timeout {
                    let item = DispatchWorkItem {
                        if let p = taskProcess, p.isRunning {
                            writeLog("[BG:pid=\(p.processIdentifier)] Background script \(scriptName) timed out after \(seconds)s — terminating", logLevel: .error)
                            p.terminate()
                        }
                    }
                    timeoutItem = item
                    DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(seconds), execute: item)
                }

                // bgTag is set once the process launches and we have its PID.
                // We use a placeholder until runShellCommandTracked populates processRef.
                // The tag is captured by the streaming callbacks via the computed property below.
                var resolvedTag: String { taskProcess.map { "[BG:pid=\($0.processIdentifier)]" } ?? "[BG]" }

                let status = runShellCommandTracked(
                    script,
                    args: [consoleUser],
                    logTag: resolvedTag,
                    onOutput: { line in writeLog("\(resolvedTag) \(line)", logLevel: .debug) },
                    onError:  { line in writeLog("\(resolvedTag) \(line)", logLevel: .error) },
                    processRef: &taskProcess)

                // Cancel timeout watchdog now that the process has exited
                timeoutItem?.cancel()

                let bgTag = resolvedTag
                if status != 0 {
                    writeLog("\(bgTag) \(scriptName) exited with status \(status)", logLevel: .error)
                } else {
                    writeLog("\(bgTag) \(scriptName) completed successfully", logLevel: .info)
                    if once {
                        _ = runOnceLock.sync {
                            runOnce.updateValue(Date(), forKey: scriptName)
                        }
                    }
                }

                if deleteItems {
                    pathCleanup(script)
                }

                group.leave()
            }
        }

        // ── Foreground execution ───────────────────────────────────────────────
        // Runs sequentially on the current thread while background tasks run concurrently.
        for script in foregroundScripts {
            let scriptName = altName.isEmpty ? script : altName
            runScript(script, scriptName: scriptName, consoleUser: consoleUser,
                      once: once, override: override, deleteItems: deleteItems,
                      runOnce: &runOnce)
        }

        // Wait for all background tasks before returning so outset can exit cleanly.
        // With no timeout configured we wait indefinitely — the scripts themselves
        // are responsible for their own termination.
        if let seconds = timeout {
            let result = group.wait(timeout: .now() + .seconds(seconds + 5))
            if result == .timedOut {
                writeLog("Background script group wait timed out — some tasks may still be running", logLevel: .error)
            }
        } else {
            group.wait()
        }
    } else {
        // No background scripts — run foreground scripts sequentially as normal.
        for script in foregroundScripts {
            let scriptName = altName.isEmpty ? script : altName
            runScript(script, scriptName: scriptName, consoleUser: consoleUser,
                      once: once, override: override, deleteItems: deleteItems,
                      runOnce: &runOnce)
        }
    }

    // ── Persist run-once records (includes any written by background tasks) ────
    if !runOnce.isEmpty {
        writeRunOncePlist(runOnceData: runOnce, bootOnce: isRoot)
    }
}

/// Executes a single script synchronously, applying run-once and override logic.
/// Shared by both the foreground and (via closure) background execution paths.
private func runScript(_ script: String, scriptName: String, consoleUser: String,
                       once: Bool, override: RunOnce, deleteItems: Bool,
                       runOnce: inout RunOnce) {
    if once {
        writeLog("Processing run-once \(scriptName)", logLevel: .info)
        if !runOnce.contains(where: { $0.key == scriptName }) {
            writeLog("run-once not yet processed. proceeding", logLevel: .debug)
            let (output, error, status) = runShellCommand(script, args: [consoleUser], verbose: true)
            if status != 0 {
                writeLog(error, logLevel: .error)
            } else {
                runOnce.updateValue(Date(), forKey: scriptName)
                writeLog(output)
            }
        } else {
            writeLog("checking for override", logLevel: .debug)
            if override.contains(where: { $0.key == scriptName }) {
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

// swiftlint:enable cyclomatic_complexity
