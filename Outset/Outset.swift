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

let author = "Bart Reardon - Adapted from outset by Joseph Chilcote (chilcote@gmail.com) https://github.com/chilcote/outset"
let outsetVersion: AnyObject = Bundle.main.infoDictionary!["CFBundleShortVersionString"] as AnyObject

// Outset specific directories
let outsetDirectory = "/usr/local/outset/"
let bootEveryDir = outsetDirectory+"boot-every"
let bootOnceDir = outsetDirectory+"boot-once"
let loginWindowDir = outsetDirectory+"login-window"
let loginEveryDir = outsetDirectory+"login-every"
let loginOnceDir = outsetDirectory+"login-once"
let loginEveryPrivilegedDir = outsetDirectory+"login-privileged-every"
let loginOncePrivilegedDir = outsetDirectory+"login-privileged-once"
let onDemandDir = outsetDirectory+"on-demand"
let shareDirectory = outsetDirectory+"share/"
let logDirectory = outsetDirectory+"logs"
let logFile = logDirectory+"/outset.log"

let onDemandTrigger = "/private/tmp/.io.macadmins.outset.ondemand.launchd"
let loginPrivilegedTrigger = "/private/tmp/.io.macadmins.outset.login-privileged.launchd"
let cleanupTrigger = "/private/tmp/.io.macadmins.outset.cleanup.launchd"

// File permission defaults
let requiredFilePermissions: NSNumber = 0o644
let requiredExecutablePermissions: NSNumber = 0o755

// Set some variables
var debugMode: Bool = false
var loginwindowState: Bool = true
var consoleUser: String = getConsoleUserInfo().username
var continueFirstBoot: Bool = true
var prefs = loadPreferences()

// Log Stuff
let bundleID = Bundle.main.bundleIdentifier ?? "io.macadmins.Outset"
let osLog = OSLog(subsystem: bundleID, category: "main")

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

    @Flag(help: "Show version number")
    var version = false

    mutating func run() throws {

        if debug || UserDefaults.standard.bool(forKey: "verbose_logging") {
            debugMode = true
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
            writeLog("Processing scheduled runs for boot", logLevel: .debug)
            ensureWorkingFolders()

            writePreferences(prefs: prefs)

            if !folderContents(path: bootOnceDir).isEmpty {
                if prefs.waitForNetwork {
                    loginwindowState = false
                    loginWindowUpdateState(.disable)
                    continueFirstBoot = waitForNetworkUp(timeout: floor(Double(prefs.networkTimeout) / 10))
                }
                if continueFirstBoot {
                    writeSysReport()
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
            writeLog("Processing scheduled runs for login window", logLevel: .debug)

            if !folderContents(path: loginWindowDir).isEmpty {
                processItems(loginWindowDir)
            }
        }

        if login {
            writeLog("Processing scheduled runs for login", logLevel: .debug)
            if !prefs.ignoredUsers.contains(consoleUser) {
                if !folderContents(path: loginOnceDir).isEmpty {
                    processItems(loginOnceDir, once: true, override: prefs.overrideLoginOnce)
                }
                if !folderContents(path: loginEveryDir).isEmpty {
                    processItems(loginEveryDir)
                }
                if !folderContents(path: loginOncePrivilegedDir).isEmpty || !folderContents(path: loginEveryPrivilegedDir).isEmpty {
                    FileManager.default.createFile(atPath: loginPrivilegedTrigger, contents: nil)
                }
            }

        }

        if loginPrivileged {
            writeLog("Processing scheduled runs for privileged login", logLevel: .debug)
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
            writeLog("Processing on-demand", logLevel: .debug)
            if !folderContents(path: onDemandDir).isEmpty {
                if !["root", "loginwindow"].contains(consoleUser) {
                    let currentUser = NSUserName()
                    if consoleUser == currentUser {
                        processItems(onDemandDir)
                    } else {
                        writeLog("User \(currentUser) is not the current console user. Skipping on-demand run.")
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
            writeLog("Processing scripts in login-every", logLevel: .debug)
            if !prefs.ignoredUsers.contains(consoleUser) {
                if !folderContents(path: loginEveryDir).isEmpty {
                    processItems(loginEveryDir)
                }
            }
        }

        if loginOnce {
            writeLog("Processing scripts in login-once", logLevel: .debug)
            if !prefs.ignoredUsers.contains(consoleUser) {
                if !folderContents(path: loginOnceDir).isEmpty {
                    processItems(loginOnceDir, once: true, override: prefs.overrideLoginOnce)
                }
            } else {
                writeLog("user \(consoleUser) is in the ignored list. skipping", logLevel: .debug)
            }
        }

        if cleanup {
            writeLog("Cleaning up on-demand directory.", logLevel: .debug)
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
            writePreferences(prefs: prefs)
        }

        if !removeIgnoredUser.isEmpty {
            ensureRoot("remove ignored users")
            for username in removeIgnoredUser {
                if let index = prefs.ignoredUsers.firstIndex(of: username) {
                    prefs.ignoredUsers.remove(at: index)
                }
            }
            writePreferences(prefs: prefs)
        }

        if !addOveride.isEmpty {
            ensureRoot("add scripts to override list")

            for var overide in addOveride {
                if !overide.contains(loginOnceDir) {
                    overide = "\(loginOnceDir)/\(overide)"
                }
                writeLog("Adding \(overide) to overide list", logLevel: .debug)
                prefs.overrideLoginOnce[overide] = Date()
            }
            writePreferences(prefs: prefs)
        }

        if !removeOveride.isEmpty {
            ensureRoot("remove scripts to override list")
            for var overide in removeOveride {
                if !overide.contains(loginOnceDir) {
                    overide = "\(loginOnceDir)/\(overide)"
                }
                writeLog("Removing \(overide) from overide list", logLevel: .debug)
                prefs.overrideLoginOnce.removeValue(forKey: overide)
            }
            writePreferences(prefs: prefs)
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
                        print("Checksum for file \(fileToHash): \(hash)")
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

        if version {
            print(outsetVersion)
            if debugMode {
                writeSysReport()
            }
        }
    }
}

// swiftlint:enable line_length function_body_length cyclomatic_complexity
