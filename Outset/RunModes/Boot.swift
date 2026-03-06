//
//  Boot.swift
//  Outset
//
//  Created by Bart Reardon on 6/8/2025.
//

import Foundation

/// Processes all scheduled tasks that run at system boot.
///
/// This function handles the complete boot-time workflow:
/// - Rotates the log files to maintain the maximum number of boot logs.
/// - Ensures required working folders exist.
/// - Writes the current `OutsetPreferences` to disk.
/// - Optionally waits for network connectivity before running scripts.
/// - Runs `.bootOnce` and `.bootEvery` payload scripts as configured.
/// - Restores login window state if it was modified during execution.
///
/// The function will skip running boot scripts if:
/// - Network connectivity is required (`prefs.waitForNetwork == true`) but
///   cannot be established within `prefs.networkTimeout` seconds.
///
/// - Parameter prefs: The `OutsetPreferences` object containing runtime
///   configuration, including network wait settings and timeouts.
///
/// - Note: This function writes informational and error logs throughout the
///   process, and may update the login window state temporarily during execution.
///
/// - SeeAlso: `processItems(_:)`, `scriptPayloads.processPayloadScripts(ofType:)`
func processBootTasks(prefs: OutsetPreferences) {
    // perform log file rotation
    performLogRotation(logFolderPath: logDirectory, logFileBaseName: logFileName, maxLogFiles: logFileMaxCount)

    writeLog("Processing scheduled runs for boot", logLevel: .info)
    ensureWorkingFolders()

    writeOutsetPreferences(prefs: prefs)
    
    let bootOnceDir = PayloadType.bootOnce
    let bootEveryDir = PayloadType.bootEvery

    var loginWindowDisabled = false
    var continueFirstBoot = true

    if prefs.waitForNetwork {
        loginWindowUpdateState(.disable)
        loginWindowDisabled = true
        continueFirstBoot = waitForNetworkUp(timeout: Double(prefs.networkTimeout))
    }
    
    if continueFirstBoot {
        let ranBootOnce = scriptPayloads.processPayloadScripts(ofType: .bootOnce, consoleUser: "")
        let ranBootEvery = scriptPayloads.processPayloadScripts(ofType: .bootEvery, consoleUser: "")
        
        if !(ranBootOnce || bootOnceDir.isEmpty) {
            processItems(.bootOnce, consoleUser: "", deleteItems: true)
        }
        
        if !(ranBootEvery || bootEveryDir.isEmpty) {
            processItems(.bootEvery, consoleUser: "")
        }
        
        if loginWindowDisabled {
            loginWindowUpdateState(.enable)
        }
        
    } else {
        writeLog("Unable to connect to network. Skipping boot scripts...", logLevel: .error)
    }

    writeLog("Boot processing complete")
}
