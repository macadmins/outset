//
//  main.swift
//  outset
//
//  Created by Bart Reardon on 1/12/2022.
//
// swift implementation of outset by Joseph Chilcote https://github.com/chilcote/outset
//

import Foundation
import ArgumentParser
import OSLog

// Logic insertion point
@main
struct Outset: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "outset",
        abstract: "Outset is a utility that automatically processes scripts and/or packages at boot, on demand, or login.")

    @Flag(help: .hidden)
    var debug = false

    @Flag(help: "Used by launchd for scheduled runs at boot")
    var boot = false

    @Flag(help: "Used by launchd for scheduled runs at login")
    var login = false

    @Flag(help: "Used by launchd for scheduled runs at the login window")
    var loginWindow = false

    @Flag(help: "Used by launchd for scheduled privileged runs at login")
    var loginPrivileged = false

    @Flag(help: "Process scripts on demand")
    var onDemand = false

    @Flag(help: "Process scripts on demand with elevated privileges")
    var onDemandPrivileged = false

    @Flag(help: "Manually process scripts in login-every")
    var loginEvery = false

    @Flag(help: "Manually process scripts in login-once")
    var loginOnce = false

    @Flag(help: "Used by launchd to clean up on-demand dir")
    var cleanup = false

    @Option(help: ArgumentHelp("Add one or more users to ignored list", valueName: "username"))
    var addIgnoredUser: [String] = []

    @Option(help: ArgumentHelp("Remove one or more users from ignored list", valueName: "username"))
    var removeIgnoredUser: [String] = []

    @Option(help: ArgumentHelp("Add one or more scripts to override list", valueName: "script"), completion: .file())
    var addOverride: [String] = []

    // maintaining misspelt option as hidden
    @Option(help: .hidden, completion: .file())
    var addOveride: [String] = []

    @Option(help: ArgumentHelp("Remove one or more scripts from override list", valueName: "script"), completion: .file())
    var removeOverride: [String] = []

    // maintaining misspelt option as hidden
    @Option(help: .hidden, completion: .file())
    var removeOveride: [String] = []

    // removed from view in favour for checksum. retained to support backward compatability
    @Option(help: .hidden, completion: .file())
    var computeSHA: [String] = []

    @Option(help: ArgumentHelp("Compute the checksum (SHA256) hash of the given file. Use the keyword 'all' to compute all values and generate a formatted configuration plist", valueName: "file"), completion: .file())
    var checksum: [String] = []

    @Flag(help: .hidden)
    var shasumReport = false

    @Flag(help: .hidden)
    var checksumReport = false

    @Flag(help: .hidden)
    var enableServices = false

    @Flag(help: .hidden)
    var disableServices = false

    @Flag(help: .hidden)
    var serviceStatus = false

    /// DEBUG CODE - remove me
    @Flag(help: .hidden)
    var payloads = false

    @Flag(help: "Show version number")
    var version = false

    mutating func run() throws {

        if debug || UserDefaults.standard.bool(forKey: "verbose_logging") {
            debugMode = true
        }

        if version {
            printStdOut("\(outsetVersion)")
            if debugMode {
                writeSysReport()
            }
        }

        /// DEBUG CODE - remove me
        if payloads {
            processPayloadScripts()
        }

        if enableServices, #available(macOS 13.0, *) {
            let manager = ServiceManager()
            manager.registerDaemons()
        }

        if disableServices, #available(macOS 13.0, *) {
            let manager = ServiceManager()
            manager.removeDaemons()
        }

        if serviceStatus, #available(macOS 13.0, *) {
            let manager = ServiceManager()
            manager.getStatus()
        }

        if boot {
            // perform log file rotation
            performLogRotation(logFolderPath: logDirectory, logFileBaseName: logFileName, maxLogFiles: logFileMaxCount)

            writeLog("Processing scheduled runs for boot", logLevel: .info)
            ensureWorkingFolders()

            writeOutsetPreferences(prefs: prefs)

            if !folderContents(path: bootOnceDir).isEmpty {
                if prefs.waitForNetwork {
                    loginwindowState = false
                    loginWindowUpdateState(.disable)
                    continueFirstBoot = waitForNetworkUp(timeout: floor(Double(prefs.networkTimeout) / 10))
                }
                if continueFirstBoot {
                    processItems(bootOnceDir, deleteItems: true)
                } else {
                    writeLog("Unable to connect to network. Skipping boot-once scripts...", logLevel: .error)
                }
                if !loginwindowState {
                    loginWindowUpdateState(.enable)
                }
            }

            if !folderContents(path: bootEveryDir).isEmpty {
                processItems(bootEveryDir)
            }

            writeLog("Boot processing complete")
        }

        if loginWindow {
            writeLog("Processing scheduled runs for login window", logLevel: .info)

            if !folderContents(path: loginWindowDir).isEmpty {
                processItems(loginWindowDir)
            }
        }

        if login {
            writeLog("Processing scheduled runs for login", logLevel: .info)
            if !prefs.ignoredUsers.contains(consoleUser) {
                if !folderContents(path: loginOnceDir).isEmpty {
                    processItems(loginOnceDir, once: true, override: prefs.overrideLoginOnce)
                }
                if !folderContents(path: loginEveryDir).isEmpty {
                    processItems(loginEveryDir)
                }
                if !folderContents(path: loginOncePrivilegedDir).isEmpty || !folderContents(path: loginEveryPrivilegedDir).isEmpty {
                    createTrigger(loginPrivilegedTrigger)
                }
            }

        }

        if loginPrivileged {
            writeLog("Processing scheduled runs for privileged login", logLevel: .info)
            if checkFileExists(path: loginPrivilegedTrigger) {
                pathCleanup(pathname: loginPrivilegedTrigger)
            }
            if !prefs.ignoredUsers.contains(consoleUser) {
                if !folderContents(path: loginOncePrivilegedDir).isEmpty {
                    processItems(loginOncePrivilegedDir, once: true, override: prefs.overrideLoginOnce)
                }
                if !folderContents(path: loginEveryPrivilegedDir).isEmpty {
                    processItems(loginEveryPrivilegedDir)
                }
            } else {
                writeLog("Skipping login scripts for user \(consoleUser)")
            }
        }

        if onDemand {
            writeLog("Processing on-demand", logLevel: .info)
            if !folderContents(path: onDemandDir).isEmpty {
                if !["root", "loginwindow"].contains(consoleUser) {
                    let currentUser = NSUserName()
                    if consoleUser == currentUser {
                        processItems(onDemandDir)
                        createTrigger(cleanupTrigger)
                    } else {
                        writeLog("User \(currentUser) is not the current console user. Skipping on-demand run.")
                    }
                } else {
                    writeLog("No current user session. Skipping on-demand run.")
                }
            }
        }

        if onDemandPrivileged {
            writeLog("Processing on-demand-privileged", logLevel: .debug)
            if !folderContents(path: onDemandPrivilegedDir).isEmpty {
                if !["root", "loginwindow"].contains(consoleUser) {
                    let currentUser = NSUserName()
                    if consoleUser == currentUser {
                        processItems(onDemandPrivilegedDir)
                    } else {
                        writeLog("User \(currentUser) is not the current console user. Skipping on-demand-privileged run.")
                    }
                } else {
                    writeLog("No current user session. Skipping on-demand run.")
                }
                FileManager.default.createFile(atPath: cleanupTrigger, contents: nil)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if checkFileExists(path: cleanupTrigger) {
                        pathCleanup(pathname: cleanupTrigger)
                    }
                }
            }
        }

        if loginEvery {
            writeLog("Processing scripts in login-every", logLevel: .info)
            if !prefs.ignoredUsers.contains(consoleUser) {
                if !folderContents(path: loginEveryDir).isEmpty {
                    processItems(loginEveryDir)
                }
            }
        }

        if loginOnce {
            writeLog("Processing scripts in login-once", logLevel: .info)
            if !prefs.ignoredUsers.contains(consoleUser) {
                if !folderContents(path: loginOnceDir).isEmpty {
                    processItems(loginOnceDir, once: true, override: prefs.overrideLoginOnce)
                }
            } else {
                writeLog("user \(consoleUser) is in the ignored list. skipping", logLevel: .debug)
            }
        }

        if cleanup {
            writeLog("Cleaning up on-demand directory.", logLevel: .info)
            if checkFileExists(path: onDemandTrigger) { pathCleanup(pathname: onDemandTrigger) }
            if checkFileExists(path: cleanupTrigger) { pathCleanup(pathname: cleanupTrigger) }
            if !folderContents(path: onDemandDir).isEmpty { pathCleanup(pathname: onDemandDir) }
        }

        if !addIgnoredUser.isEmpty {
            ensureRoot("add to ignored users")
            for username in addIgnoredUser {
                if prefs.ignoredUsers.contains(username) {
                    writeLog("User \"\(username)\" is already in the ignored users list", logLevel: .info)
                } else {
                    writeLog("Adding \(username) to ignored users list", logLevel: .info)
                    prefs.ignoredUsers.append(username)
                }
            }
            writeOutsetPreferences(prefs: prefs)
        }

        if !removeIgnoredUser.isEmpty {
            ensureRoot("remove ignored users")
            for username in removeIgnoredUser {
                if let index = prefs.ignoredUsers.firstIndex(of: username) {
                    prefs.ignoredUsers.remove(at: index)
                }
            }
            writeOutsetPreferences(prefs: prefs)
        }

        if !addOverride.isEmpty || !addOveride.isEmpty {
            if !addOveride.isEmpty {
                addOverride = addOveride
            }
            ensureRoot("add scripts to override list")

            for var override in addOverride {
                if !override.contains(loginOnceDir) && !override.contains(loginOncePrivilegedDir) {
                    override = "\(loginOnceDir)/\(override)"
                }
                writeLog("Adding \(override) to override list", logLevel: .debug)
                prefs.overrideLoginOnce[override] = Date()
            }
            writeOutsetPreferences(prefs: prefs)
        }

        if !removeOverride.isEmpty || !removeOveride.isEmpty {
            if !removeOveride.isEmpty {
                removeOverride = removeOveride
            }
            ensureRoot("remove scripts to override list")
            for var override in removeOverride {
                if !override.contains(loginOnceDir) {
                    override = "\(loginOnceDir)/\(override)"
                }
                writeLog("Removing \(override) from override list", logLevel: .debug)
                prefs.overrideLoginOnce.removeValue(forKey: override)
            }
            writeOutsetPreferences(prefs: prefs)
        }

        if !checksum.isEmpty || !computeSHA.isEmpty {
            if checksum.isEmpty {
                checksum = computeSHA
            }
            if checksum[0].lowercased() == "all" {
                checksumAllFiles()
            } else {
                for fileToHash in checksum {
                    let url = URL(fileURLWithPath: fileToHash)
                    if let hash = sha256(for: url) {
                        printStdOut("Checksum for file \(fileToHash): \(hash)")
                    }
                }
            }
        }

        if shasumReport || checksumReport {
            writeLog("Checksum report", logLevel: .info)
            for (filename, checksum) in checksumLoadApprovedFiles() {
                writeLog("\(filename) : \(checksum)", logLevel: .info)
            }
        }
    }
}
