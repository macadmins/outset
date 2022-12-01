//
//  main.swift
//  outset
//
//  Created by Bart Reardon on 1/12/2022.
//
// swift implementation of outset by Joseph Chilcote https://github.com/chilcote/outset

import Foundation
import ArgumentParser

let outsetVersion = "0.1"

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
let outset_preferences = share_dir+"com.chilcote.outset.plist"
let on_demand_trigger = "/private/tmp/.com.github.outset.ondemand.launchd"
let login_privileged_trigger = "/private/tmp/.com.github.outset.login-privileged.launchd"
let cleanup_trigger = "/private/tmp/.com.github.outset.cleanup.launchd"

// Set some variables
var loginwindow : Bool = true
var console_user : String = "" //pwd.getpwuid(os.getuid())[0]
var network_wait : Bool = true
var network_timeout : Int = 180
var ignored_users : [String] = []
var override_login_once : Dictionary = [String: Date]()
var continue_firstboot : Bool = true
var prefs : OutsetPreferences = OutsetPreferences(wait_for_network: network_wait, network_timeout: network_timeout, ignored_users: ignored_users, override_login_once: override_login_once)


struct Outset: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "outset",
        abstract: "This script automatically processes packages, profiles, and/or scripts at boot, on demand, and/or login.")
    
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
    
    @Flag(help: "Show version number")
    var version = false
    
    func run() {
        
        prefs = load_outset_preferences()
        print("network timeout is \(prefs.network_timeout)")
        
        if boot {
            ensure_working_folders()
            ensure_outset_preferences()
        }
        
        if login {
            
        }
        
        if loginPrivileged {
            
        }
        
        if onDemand {
            
        }
        
        if loginEvery {
            
        }
        
        if loginOnce {
            
        }
        
        if cleanup {
            
        }
        
        if !addIgnoredUser.isEmpty {
            
        }
        
        if !removeIgnoredUser.isEmpty {
            
        }
        
        if !addOveride.isEmpty {
            
        }
        
        if !removeOveride.isEmpty {
            
        }
        
        if version {
            print(outsetVersion)
        }
    }
}



Outset.main()
