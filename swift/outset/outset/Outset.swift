//
//  main.swift
//  outset
//
//  Created by Bart Reardon on 1/12/2022.
//
// swift implementation of outset by Joseph Chilcote https://github.com/chilcote/outset

import Foundation
import ArgumentParser

let author = "Bart Reardon - Adapted from outset by Joseph Chilcote (chilcote@gmail.com) https://github.com/chilcote/outset"
let outsetVersion = "4.0 alpha"

// Set some Constants TODO: leave these as defaults but maybe make them configurable from a plist
let outset_dir = "/usr/local/outset/"
let boot_every_dir = outset_dir+"boot-every"
let boot_once_dir = outset_dir+"boot-once"
let login_every_dir = outset_dir+"login-every"
let login_once_dir = outset_dir+"login-once"
let login_privileged_every_dir = outset_dir+"login-privileged-every"
let login_privileged_once_dir = outset_dir+"login-privileged-once"
let on_demand_dir = outset_dir+"on-demand"
let share_dir = outset_dir+"share/"
let managed_preferences_dir = "/Library/Managed Preferences"
let managed_preference_plist = managed_preferences_dir+"/com.github.outset.plist"
let outset_preferences = share_dir+"com.chilcote.outset.plist"
let on_demand_trigger = "/private/tmp/.com.github.outset.ondemand.launchd"
let login_privileged_trigger = "/private/tmp/.com.github.outset.login-privileged.launchd"
let cleanup_trigger = "/private/tmp/.com.github.outset.cleanup.launchd"
let filePermissions: NSNumber = 0o644
let executablePermissions: NSNumber = 0o755

// Set some variables
var debugMode : Bool = false
var loginwindow : Bool = true
var console_user : String = getConsoleUserInfo().username
var network_wait : Bool = true
var network_timeout : Int = 180
var ignored_users : [String] = []
var override_login_once : [String: Date] = [String: Date]()
var continue_firstboot : Bool = true
var (log_file, run_once_plist) = set_run_once_params()
var prefs = load_outset_preferences()
var file_hashes = load_hashes(plist: managed_preference_plist)
var hashes_available = !file_hashes.isEmpty

@main
struct Outset: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "outset",
        abstract: "This script automatically processes packages, profiles, and/or scripts at boot, on demand, and/or login.")
    
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
    
    @Option(help: ArgumentHelp("Compute the SHA1 hash of the given file", valueName: "file"), completion: .file())
    var computeSHA : [String] = []
    
    @Flag(help: "Output managed SHA")
    var readSHAPrefrences = false
    
    @Flag(help: "Show version number")
    var version = false
    
    mutating func run() throws {
                
        if debug {
            debugMode = true
            writeLog("Outset version \(outsetVersion)", status: .debug)
            sys_report()
        }
        
        if readSHAPrefrences {
            print(load_hashes(plist: managed_preference_plist))
        }
        
        if boot {
            writeLog("Processing scheduled runs for boot", status: .debug)
            ensure_working_folders()
            ensure_shared_folder()
            if !check_file_exists(path: outset_preferences) {
                dump_outset_preferences(prefs: prefs)
            }
            
            if !list_folder(path: boot_once_dir).isEmpty {
                if network_wait {
                    loginwindow = false
                    disable_loginwindow()
                    continue_firstboot = wait_for_network(timeout: floor(Double(network_timeout) / 10))
                }
                if continue_firstboot {
                    sys_report()
                    process_items(boot_once_dir, delete_items: true)
                } else {
                    writeLog("Unable to connect to network. Skipping boot-once scripts...", status: .error)
                }
                if !loginwindow {
                    enable_loginwindow()
                }
            }
            
            if !list_folder(path: boot_every_dir).isEmpty {
                process_items(boot_every_dir)
            }
            
            writeLog("Boot processing complete")
        }
        
        if login {
            writeLog("Processing scheduled runs for login", status: .debug)
            if !ignored_users.contains(console_user) {
                if !list_folder(path: login_once_dir).isEmpty {
                    process_items(login_once_dir, once: true, override: prefs.override_login_once)
                }
                if !list_folder(path: login_every_dir).isEmpty {
                    process_items(login_every_dir)
                }
                if !list_folder(path: login_privileged_once_dir).isEmpty || !list_folder(path: login_privileged_every_dir).isEmpty {
                    FileManager.default.createFile(atPath: login_privileged_trigger, contents: nil)
                }
            }
            
        }
        
        if loginPrivileged {
            writeLog("Processing scheduled runs for privileged login", status: .debug)
            if check_file_exists(path: login_privileged_trigger) {
                path_cleanup(pathname: login_privileged_trigger)
            }
            if !ignored_users.contains(console_user) {
                if !list_folder(path: login_privileged_once_dir).isEmpty {
                    process_items(login_privileged_once_dir, once: true, override: prefs.override_login_once)
                }
                if !list_folder(path: login_privileged_every_dir).isEmpty {
                    process_items(login_privileged_every_dir)
                }
            } else {
                writeLog("Skipping login scripts for user \(console_user)")
            }
        }
        
        if onDemand {
            writeLog("Processing on-demand", status: .debug)
            if !list_folder(path: on_demand_dir).isEmpty {
                if !["root", "loginwindow"].contains(console_user) {
                    let current_user = NSUserName()
                    if console_user == current_user {
                        process_items(on_demand_dir)
                    } else {
                        writeLog("User \(current_user) is not the current console user. Skipping on-demand run.")
                    }
                } else {
                    writeLog("No current user session. Skipping on-demand run.")
                }
                FileManager.default.createFile(atPath: cleanup_trigger, contents: nil)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if check_file_exists(path: cleanup_trigger) {
                        path_cleanup(pathname: cleanup_trigger)
                    }
                }
            }
        }
        
        if loginEvery {
            writeLog("Processing scripts in login-every", status: .debug)
            if !ignored_users.contains(console_user) {
                if !list_folder(path: login_every_dir).isEmpty {
                    process_items(login_every_dir)
                }
            }
        }
        
        if loginOnce {
            writeLog("Processing scripts in login-once", status: .debug)
            if !ignored_users.contains(console_user) {
                if !list_folder(path: login_once_dir).isEmpty {
                    process_items(login_once_dir, once: true)
                }
            }
        }
        
        if cleanup {
            writeLog("Cleaning up on-demand directory.", status: .debug)
            if check_file_exists(path: on_demand_trigger) {
                    path_cleanup(pathname: on_demand_trigger)
            }
            if !list_folder(path: on_demand_dir).isEmpty {
                path_cleanup(pathname: on_demand_dir)
            }
        }
        
        if !addIgnoredUser.isEmpty {
            ensure_root("add to ignored users")
            ensure_shared_folder()
            for username in addIgnoredUser {
                if prefs.ignored_users.contains(username) {
                    writeLog("User \"\(username)\" is already in the ignored users list", status: .info)
                } else {
                    writeLog("Adding \(username) to ignored users list", status: .info)
                    prefs.ignored_users.append(username)
                }
            }
            dump_outset_preferences(prefs: prefs)
        }
        
        if !removeIgnoredUser.isEmpty {
            ensure_root("remove ignored users")
            for username in removeIgnoredUser {
                if let index = prefs.ignored_users.firstIndex(of: username) {
                    prefs.ignored_users.remove(at: index)
                }
            }
            dump_outset_preferences(prefs: prefs)
        }
        
        if !addOveride.isEmpty {
            ensure_root("add scripts to override list")
            ensure_shared_folder()
            
            for var overide in addOveride {
                if !overide.contains(login_once_dir) {
                    overide = "\(login_once_dir)/\(overide)"
                }
                writeLog("Adding \(overide) to overide list", status: .debug)
                prefs.override_login_once[overide] = Date()
            }
            dump_outset_preferences(prefs: prefs)
        }
        
        if !removeOveride.isEmpty {
            ensure_root("remove scripts to override list")
            for var overide in removeOveride {
                if !overide.contains(login_once_dir) {
                    overide = "\(login_once_dir)/\(overide)"
                }
                writeLog("Removing \(overide) from overide list", status: .debug)
                prefs.override_login_once.removeValue(forKey: overide)
            }
            dump_outset_preferences(prefs: prefs)
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
        
        if version {
            print(outsetVersion)
        }
    }
}

