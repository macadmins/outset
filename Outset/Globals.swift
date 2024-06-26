//
//  Globals.swift
//  Outset
//
//  Created by Bart Reardon on 22/6/2024.
//
// swiftlint:disable line_length

import Foundation
import OSLog

// Clean this bit up and make it less C-ish and more Swifty

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
let onDemandPrivilegedDir = outsetDirectory+"on-demand-privileged"
let shareDirectory = outsetDirectory+"share/"
let payloadDirectory = outsetDirectory+"payload/"

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
var prefs = loadOutsetPreferences()

// Log Stuff
let bundleID = Bundle.main.bundleIdentifier ?? "io.macadmins.Outset"
let osLog = OSLog(subsystem: bundleID, category: "main")
// We could make these availab as preferences perhaps
let logFileName = "outset.log"
let logFileMaxCount: Int = 30
let logDirectory = outsetDirectory+"logs"
let logFilePath = logDirectory+"/"+logFileName

// swiftlint:enable line_length
