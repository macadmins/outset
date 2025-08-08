//
//  Boot.swift
//  Outset
//
//  Created by Reardon, Bart (IM&T, Black Mountain) on 6/8/2025.
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
    
    if prefs.waitForNetwork {
        loginwindowState = false
        loginWindowUpdateState(.disable)
        continueFirstBoot = waitForNetworkUp(timeout: floor(Double(prefs.networkTimeout) / 10))
    }
    
    if continueFirstBoot {
        let ranBootOnce = scriptPayloads.processPayloadScripts(ofType: .bootOnce)
        let ranBootEvery = scriptPayloads.processPayloadScripts(ofType: .bootEvery)
        
        if !(ranBootOnce || bootOnceDir.isEmpty) {
            processItems(.bootOnce, deleteItems: true)
        }
        
        if !(ranBootEvery || bootEveryDir.isEmpty) {
            processItems(.bootEvery)
        }
        
        if !loginwindowState {
            loginWindowUpdateState(.enable)
        }
        
    } else {
        writeLog("Unable to connect to network. Skipping boot scripts...", logLevel: .error)
    }

    writeLog("Boot processing complete")
}
