//
//  Boot.swift
//  Outset
//
//  Created by Reardon, Bart (IM&T, Black Mountain) on 6/8/2025.
//

import Foundation

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
