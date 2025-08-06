//
//  OnDemand.swift
//  Outset
//
//  Created by Reardon, Bart (IM&T, Black Mountain) on 6/8/2025.
//

import Foundation

func processOnDemandTasks() {
    writeLog("Processing on-demand", logLevel: .info)
    if !folderContents(type: .onDemand).isEmpty {
        if !["root", "loginwindow"].contains(consoleUser) {
            let currentUser = NSUserName()
            if consoleUser == currentUser {
                processItems(.onDemand)
                createTrigger(Trigger.cleanup.path)
            } else {
                writeLog("User \(currentUser) is not the current console user. Skipping on-demand run.")
            }
        } else {
            writeLog("No current user session. Skipping on-demand run.")
        }
    }
}

func processOnDemandPrivilegedTasks() {
    ensureRoot("execute on-demand-privileged")
    writeLog("Processing on-demand-privileged", logLevel: .debug)
    if !["loginwindow"].contains(consoleUser) {
        if !folderContents(type: .onDemandPrivileged).isEmpty {
            processItems(.onDemandPrivileged)
            pathCleanup(Trigger.onDemandPrivileged.path)
            pathCleanup(PayloadType.onDemandPrivileged.directoryPath)
        }
    } else {
        writeLog("No current user session. Skipping on-demand-privileged run.")
    }
}
