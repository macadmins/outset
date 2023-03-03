//
//  main.swift
//  outset
//
//  Created by Bart Reardon on 1/12/2022.
//
// swift implementation of outset by Joseph Chilcote https://github.com/chilcote/outset

import Foundation
import ArgumentParser
import OSLog

let author = "Bart Reardon - Adapted from outset by Joseph Chilcote (chilcote@gmail.com) https://github.com/chilcote/outset"
let outsetVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as! String

// Set some Constants TODO: leave these as defaults but maybe make them configurable from a plist

// Outset specific directories
let outsetDirectory = "/usr/local/outset/"
let bootEveryDir = outsetDirectory+"boot-every"
let bootOnceDir = outsetDirectory+"boot-once"
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
var debugMode : Bool = false
var loginwindow : Bool = true
var consoleUser : String = getConsoleUserInfo().username
var networkWait : Bool = true
var networkTimeout : Int = 180
var ignoredUsers : [String] = []
var loginOnceOverride : [String: Date] = [String: Date]()
var continueFirstBoot : Bool = true
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
    var addIgnoredUser : [String] = []
    
    @Option(help: ArgumentHelp("Remove one or more users from ignored list", valueName: "username"))
    var removeIgnoredUser : [String] = []
    
    @Option(help: ArgumentHelp("Add one or more scripts to override list", valueName: "script"), completion: .file())
    var addOveride : [String] = []
        
    @Option(help: ArgumentHelp("Remove one or more scripts from override list", valueName: "script"), completion: .file())
    var removeOveride : [String] = []
    
    @Option(help: ArgumentHelp("Compute the SHA256 hash of the given file. Use the keyword 'all' to compute all SHA values and generate a formatted configuration plist", valueName: "file"), completion: .file())
    var computeSHA : [String] = []
    
    @Flag(help: .hidden)
    var shasumReport = false
    
    @Flag(help: "Show version number")
    var version = false
    
    mutating func run() throws {
        
        if debug || UserDefaults.standard.bool(forKey: "verbose_logging") {
            debugMode = true
        }
        
        if boot {
            writeLog("Processing scheduled runs for boot", logLevel: .debug)
            ensureWorkingFolders()
            writePreferences(prefs: prefs)
            
            if !folderContents(path: bootOnceDir).isEmpty {
                if networkWait {
                    loginwindow = false
                    loginWindowDisable()
                    continueFirstBoot = waitForNetworkUp(timeout: floor(Double(networkTimeout) / 10))
                }
                if continueFirstBoot {
                    writeSysReport()
                    processItems(bootOnceDir, delete_items: true)
                } else {
                    writeLog("Unable to connect to network. Skipping boot-once scripts...", logLevel: .error)
                }
                if !loginwindow {
                    loginWindowEnable()
                }
            }
            
            if !folderContents(path: bootEveryDir).isEmpty {
                processItems(bootEveryDir)
            }
            
            writeLog("Boot processing complete")
        }
        
        if login {
            writeLog("Processing scheduled runs for login", logLevel: .debug)
            if !ignoredUsers.contains(consoleUser) {
                if !folderContents(path: loginOnceDir).isEmpty {
                    processItems(loginOnceDir, once: true, override: prefs.override_login_once)
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
            if !ignoredUsers.contains(consoleUser) {
                if !folderContents(path: loginOncePrivilegedDir).isEmpty {
                    processItems(loginOncePrivilegedDir, once: true, override: prefs.override_login_once)
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
                    let current_user = NSUserName()
                    if consoleUser == current_user {
                        processItems(onDemandDir)
                    } else {
                        writeLog("User \(current_user) is not the current console user. Skipping on-demand run.")
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
            if !ignoredUsers.contains(consoleUser) {
                if !folderContents(path: loginEveryDir).isEmpty {
                    processItems(loginEveryDir)
                }
            }
        }
        
        if loginOnce {
            writeLog("Processing scripts in login-once", logLevel: .debug)
            if !ignoredUsers.contains(consoleUser) {
                if !folderContents(path: loginOnceDir).isEmpty {
                    processItems(loginOnceDir, once: true)
                }
            }
        }
        
        if cleanup {
            writeLog("Cleaning up on-demand directory.", logLevel: .debug)
            if checkFileExists(path: onDemandTrigger) {
                    pathCleanup(pathname: onDemandTrigger)
            }
            if !folderContents(path: onDemandDir).isEmpty {
                pathCleanup(pathname: onDemandDir)
            }
        }
        
        if !addIgnoredUser.isEmpty {
            ensure_root("add to ignored users")
            for username in addIgnoredUser {
                if prefs.ignored_users.contains(username) {
                    writeLog("User \"\(username)\" is already in the ignored users list", logLevel: .info)
                } else {
                    writeLog("Adding \(username) to ignored users list", logLevel: .info)
                    prefs.ignored_users.append(username)
                }
            }
            writePreferences(prefs: prefs)
        }
        
        if !removeIgnoredUser.isEmpty {
            ensure_root("remove ignored users")
            for username in removeIgnoredUser {
                if let index = prefs.ignored_users.firstIndex(of: username) {
                    prefs.ignored_users.remove(at: index)
                }
            }
            writePreferences(prefs: prefs)
        }
        
        if !addOveride.isEmpty {
            ensure_root("add scripts to override list")
            
            for var overide in addOveride {
                if !overide.contains(loginOnceDir) {
                    overide = "\(loginOnceDir)/\(overide)"
                }
                writeLog("Adding \(overide) to overide list", logLevel: .debug)
                prefs.override_login_once[overide] = Date()
            }
            writePreferences(prefs: prefs)
        }
        
        if !removeOveride.isEmpty {
            ensure_root("remove scripts to override list")
            for var overide in removeOveride {
                if !overide.contains(loginOnceDir) {
                    overide = "\(loginOnceDir)/\(overide)"
                }
                writeLog("Removing \(overide) from overide list", logLevel: .debug)
                prefs.override_login_once.removeValue(forKey: overide)
            }
            writePreferences(prefs: prefs)
        }
        
        if !computeSHA.isEmpty {
            if computeSHA[0].lowercased() == "all" {
                shaAllFiles()
            } else {
                for fileToHash in computeSHA {
                    let url = URL(fileURLWithPath: fileToHash)
                    if let hash = sha256(for: url) {
                        print("SHA256 for file \(fileToHash): \(hash)")
                    }
                }
            }
        }
        
        if shasumReport {
            writeLog("sha256sum report", logLevel: .info)
            for (filename, shasum) in shasumLoadApprovedFileHashList() {
                writeLog("\(filename) : \(shasum)", logLevel: .info)
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

