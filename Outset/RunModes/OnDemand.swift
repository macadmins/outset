//
//  OnDemand.swift
//  Outset
//
//  Created by Bart Reardon on 6/8/2025.
//

import Foundation

/// Processes all `.onDemand` tasks for the current console user session.
///
/// This function runs user-triggered tasks that have been placed in the
/// `.onDemand` payload directory.
/// - Skips execution if the `.onDemand` folder is empty.
/// - Skips execution if there is no current user session (i.e., `consoleUser`
///   is `"root"` or `"loginwindow"`).
/// - Skips execution if the current process user is not the active console
///   user.
///
/// If conditions are met:
/// - Executes `.onDemand` payload items via `processItems(_:)`.
/// - Creates a `.cleanup` trigger after completion.
///
/// - Note: All decisions and actions are logged at `.info` level.
/// - SeeAlso: `processOnDemandPrivilegedTasks()`
func processOnDemandTasks() {
    writeLog("Processing on-demand", logLevel: .info)
    if !folderContents(type: .onDemand).isEmpty {
        if !["root", "loginwindow"].contains(consoleUser) {
            let currentUser = NSUserName()
            if consoleUser == currentUser {
                processItems(.onDemand)
                createTrigger(Trigger.cleanup.path)
            } else {
                writeLog("User \(currentUser) is not the current console user. Skipping on-demand run.", logLevel: .info)
            }
        } else {
            writeLog("No current user session. Skipping on-demand run.", logLevel: .info)
        }
    }
}

/// Processes all `.onDemandPrivileged` tasks for the system.
///
/// This function runs privileged on-demand tasks that have been placed in the
/// `.onDemandPrivileged` payload directory.
/// - Requires root privileges.
/// - Skips execution if there is no current user session (`consoleUser`
///   equals `"loginwindow"`).
/// - Skips execution if the `.onDemandPrivileged` folder is empty.
///
/// If conditions are met:
/// - Executes `.onDemandPrivileged` payload items via `processItems(_:)`.
/// - Cleans up both the `.onDemandPrivileged` trigger path and its directory.
///
/// - Note: All decisions are logged at `.info` level for visibility.
/// - SeeAlso: `processOnDemandTasks()`
func processOnDemandPrivilegedTasks() {
    ensureRoot("execute on-demand-privileged")
    writeLog("Processing on-demand-privileged", logLevel: .info)
    if !["loginwindow"].contains(consoleUser) {
        if !folderContents(type: .onDemandPrivileged).isEmpty {
            processItems(.onDemandPrivileged)
            pathCleanup(Trigger.onDemandPrivileged.path)
            pathCleanup(PayloadType.onDemandPrivileged.directoryPath)
        }
    } else {
        writeLog("No current user session. Skipping on-demand-privileged run.", logLevel: .info)
    }
}
