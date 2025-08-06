//
//  Boot.swift
//  Outset
//
//  Created by Reardon, Bart (IM&T, Black Mountain) on 6/8/2025.
//

import Foundation

func processBootTasks() {
    // perform log file rotation
    performLogRotation(logFolderPath: logDirectory, logFileBaseName: logFileName, maxLogFiles: logFileMaxCount)

    writeLog("Processing scheduled runs for boot", logLevel: .info)
    ensureWorkingFolders()

    writeOutsetPreferences(prefs: prefs)
    
    if prefs.waitForNetwork {
        loginwindowState = false
        loginWindowUpdateState(.disable)
        continueFirstBoot = waitForNetworkUp(timeout: floor(Double(prefs.networkTimeout) / 10))
    }
    
    if continueFirstBoot {
        if !scriptPayloads.processPayloadScripts(ofType: .bootOnce) && folderContents(type: .bootOnce).isEmpty {
            processItems(.bootOnce, deleteItems: true)
        }
        
        if !scriptPayloads.processPayloadScripts(ofType: .bootEvery) && !folderContents(type: .bootEvery).isEmpty {
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
