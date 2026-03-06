//
//  LoginWindow.swift
//  Outset
//
//  Created by Bart Reardon on 6/8/2025.
//

import Foundation

/// Runs the given action only if the current console user is not in the ignored list.
///
/// - Parameters:
///   - prefs: The current `OutsetPreferences` object containing the ignored users list.
///   - action: The closure to execute if the user is **not** ignored.
/// - Returns: `true` if the action was run, `false` if skipped.
@discardableResult
func runIfNotIgnoredUser(consoleUser: String, prefs: OutsetPreferences, action: () -> Void) -> Bool {
    if prefs.ignoredUsers.contains(consoleUser) {
        writeLog("User \(consoleUser) is in the ignored list. Skipping.", logLevel: .debug)
        return false
    }
    action()
    return true
}

/// Processes all `.loginWindow` tasks.
///
/// This function runs scripts intended to execute while the login window
/// is displayed and before a user logs in.
/// - Runs `.loginWindow` payload scripts via `processPayloadScripts(ofType:)`.
/// - If no payload scripts were processed and the `.loginWindow` directory
///   is not empty, executes all scripts in the directory with `processItems(_:)`.
///
/// - Parameter payload: The `ScriptPayloads` instance containing available scripts.
///
/// - Note: All actions are logged at `.info` level.
func processLoginWindowTasks(payload: ScriptPayloads) {
    writeLog("Processing scheduled runs for login window", logLevel: .info)
    let processedLoginWindowPayloads = payload.processPayloadScripts(ofType: .loginWindow, consoleUser: "")
    let loginWindowDir = PayloadType.loginWindow

    if !(processedLoginWindowPayloads || loginWindowDir.isEmpty) {
        processItems(.loginWindow, consoleUser: "")
    }
}

/// Processes all `.loginOnce` and `.loginEvery` tasks for the current user login.
///
/// This function runs login-time scripts for the active console user, skipping
/// execution if the user is in the ignored users list.
/// - `.loginOnce` scripts are executed once per user, with run-once tracking
///   stored in `prefs.overrideLoginOnce`.
/// - `.loginEvery` scripts run at every login.
/// - If privileged login scripts are present, creates the `.loginPrivileged`
///   trigger for subsequent processing.
///
/// - Parameters:
///   - payload: The `ScriptPayloads` instance containing available scripts.
///   - prefs: The `OutsetPreferences` object containing ignored user lists,
///     override data, and other configuration.
///
/// - Note: All actions are logged at `.info` level.
func processLoginTasks(consoleUser: String, payload: ScriptPayloads, prefs: OutsetPreferences) {
    writeLog("Processing scheduled runs for login", logLevel: .info)
    let onceDir = PayloadType.loginOnce
    let everyDir = PayloadType.loginEvery
    let onceDirPrivileged = PayloadType.loginPrivilegedOnce
    let everyDirPrivileged = PayloadType.loginPrivilegedEvery
    let ignoreUser = prefs.ignoredUsers.contains(consoleUser)
    
    if ignoreUser {
        writeLog("\(consoleUser) is in the ignore list. Skipping.", logLevel: .debug)
    } else {
        let processedLoginOncePayloads = payload.processPayloadScripts(ofType: .loginOnce, consoleUser: consoleUser, runOnceData: prefs.overrideLoginOnce)
        let processedLoginPayloads = payload.processPayloadScripts(ofType: .loginEvery, consoleUser: consoleUser)
        
        if !(processedLoginOncePayloads || onceDir.isEmpty) {
            processItems(.loginOnce, consoleUser: consoleUser, once: true, override: prefs.overrideLoginOnce)
        }
        
        if !(processedLoginPayloads || everyDir.isEmpty) {
            processItems(.loginEvery, consoleUser: consoleUser)
        }
        
        let hasPrivilegedPayloads = payload.loginPrivilegedOnceScripts != nil || payload.loginPrivilegedEveryScripts != nil
        if !(onceDirPrivileged.isEmpty && everyDirPrivileged.isEmpty) || hasPrivilegedPayloads {
            createTrigger(Trigger.loginPrivileged.path)
        }
    }
}

/// Processes all `.loginPrivilegedOnce` and `.loginPrivilegedEvery` tasks.
///
/// This function runs privileged login-time scripts, typically requiring root
/// privileges, for the active console user.
/// - Skips execution if the user is in the ignored users list.
/// - Removes the `.loginPrivileged` trigger file if it exists.
/// - `.loginPrivilegedOnce` scripts are executed once per user, with run-once
///   tracking stored in `prefs.overrideLoginOnce`.
/// - `.loginPrivilegedEvery` scripts run at every login.
///
/// - Parameters:
///   - payload: The `ScriptPayloads` instance containing available scripts.
///   - prefs: The `OutsetPreferences` object containing ignored user lists,
///     override data, and other configuration.
///
/// - Note: All actions are logged at `.info` level.
func processLoginPrivilegedTasks(consoleUser: String, payload: ScriptPayloads, prefs: OutsetPreferences) {
    writeLog("Processing scheduled runs for privileged login", logLevel: .info)
    let onceDir = PayloadType.loginPrivilegedOnce
    let everyDir = PayloadType.loginPrivilegedEvery
    
    if checkFileExists(path: Trigger.loginPrivileged.path) {
        pathCleanup(Trigger.loginPrivileged.path)
    }
    
    runIfNotIgnoredUser(consoleUser: consoleUser, prefs: prefs) {
        let processedLoginPrivilegedOncePayloads = payload.processPayloadScripts(ofType: .loginPrivilegedOnce, consoleUser: consoleUser, runOnceData: prefs.overrideLoginOnce)
        let processedLoginPrivilegedEveryPayloads = payload.processPayloadScripts(ofType: .loginPrivilegedEvery, consoleUser: consoleUser)
        
        if !(processedLoginPrivilegedOncePayloads || onceDir.isEmpty) {
            processItems(.loginPrivilegedOnce, consoleUser: consoleUser, once: true, override: prefs.overrideLoginOnce)
        }
        
        if !(processedLoginPrivilegedEveryPayloads || everyDir.isEmpty) {
            processItems(.loginPrivilegedEvery, consoleUser: consoleUser)
        }
    }
}

/// Processes all `.loginEvery` tasks for the current user login.
///
/// This function runs scripts that execute at **every** login for the active
/// console user, skipping execution if the user is in the ignored users list.
///
/// - Parameters:
///   - payload: The `ScriptPayloads` instance containing available scripts.
///   - prefs: The `OutsetPreferences` object containing ignored user lists.
///
/// - Note: All actions are logged at `.info` level.
func processLoginEveryTasks(consoleUser: String, payload: ScriptPayloads, prefs: OutsetPreferences) {
    writeLog("Processing scripts in login-every", logLevel: .info)
    let everyDir = PayloadType.loginEvery
    
    runIfNotIgnoredUser(consoleUser: consoleUser, prefs: prefs) {
        let processedLogonPayloads = payload.processPayloadScripts(ofType: .loginEvery, consoleUser: consoleUser)
        
        if !(processedLogonPayloads || everyDir.isEmpty) {
            processItems(.loginEvery, consoleUser: consoleUser)
        }
    }
}

/// Processes all `.loginOnce` tasks for the current user login.
///
/// This function runs scripts that execute only once for the active console
/// user, with run-once tracking stored in `prefs.overrideLoginOnce`.
/// Skips execution if the user is in the ignored users list.
///
/// - Parameters:
///   - payload: The `ScriptPayloads` instance containing available scripts.
///   - prefs: The `OutsetPreferences` object containing ignored user lists
///     and override data.
///
/// - Note: All actions are logged at `.info` level.
func processLoginOnceTasks(consoleUser: String, payload: ScriptPayloads, prefs: OutsetPreferences) {
    writeLog("Processing scripts in login-once", logLevel: .info)
    let onceDir = PayloadType.loginOnce
    
    runIfNotIgnoredUser(consoleUser: consoleUser, prefs: prefs) {
        let processedLogonPayloads = payload.processPayloadScripts(ofType: .loginOnce, consoleUser: consoleUser)
        
        if !(processedLogonPayloads || onceDir.isEmpty) {
            processItems(.loginOnce, consoleUser: consoleUser, once: true, override: prefs.overrideLoginOnce)
        }
    }
}
