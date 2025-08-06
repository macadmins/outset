//
//  LoginWindow.swift
//  Outset
//
//  Created by Reardon, Bart (IM&T, Black Mountain) on 6/8/2025.
//

import Foundation

func processLoginWindowTasks(payload: ScriptPayloads) {
    writeLog("Processing scheduled runs for login window", logLevel: .info)
    let processedLoginWindowPayloads = payload.processPayloadScripts(ofType: .loginWindow)
    let loginWindowDir = PayloadType.loginWindow

    if !(processedLoginWindowPayloads || loginWindowDir.isEmpty) {
        processItems(.loginWindow)
    }
}

func processLoginTasks(payload: ScriptPayloads, prefs: OutsetPreferences) {
    writeLog("Processing scheduled runs for login", logLevel: .info)
    let onceDir = PayloadType.loginOnce
    let everyDir = PayloadType.loginEvery
    let onceDirPrivileged = PayloadType.loginPrivilegedOnce
    let everyDirPrivileged = PayloadType.loginPrivilegedEvery
    let ignoreUser = prefs.ignoredUsers.contains(consoleUser)
    
    if ignoreUser {
        writeLog("\(consoleUser) is in the ignore list. slipping", logLevel: .debug)
    } else {
        let processedLoginOncePayloads = payload.processPayloadScripts(ofType: .loginOnce, runOnceData: prefs.overrideLoginOnce)
        let processedLoginPayloads = payload.processPayloadScripts(ofType: .loginEvery)
        
        if !(processedLoginOncePayloads || onceDir.isEmpty) {
            processItems(.loginOnce, once: true, override: prefs.overrideLoginOnce)
        }
        
        if !(processedLoginPayloads || everyDir.isEmpty) {
            processItems(.loginEvery)
        }
        
        if !(onceDirPrivileged.isEmpty || everyDirPrivileged.isEmpty) {
            createTrigger(Trigger.loginPrivileged.path)
        }
    }
}

func processLoginPrivilegedTasks(payload: ScriptPayloads, prefs: OutsetPreferences) {
    writeLog("Processing scheduled runs for privileged login", logLevel: .info)
    let onceDir = PayloadType.loginPrivilegedOnce
    let everyDir = PayloadType.loginPrivilegedEvery
    let ignoreUser = prefs.ignoredUsers.contains(consoleUser)
    
    if checkFileExists(path: Trigger.loginPrivileged.path) {
        pathCleanup(Trigger.loginPrivileged.path)
    }
    if ignoreUser {
        writeLog("Skipping login privileged scripts for user \(consoleUser)")
    } else {
        let processedLoginPrivilegedOncePayloads = payload.processPayloadScripts(ofType: .loginPrivilegedOnce, runOnceData: prefs.overrideLoginOnce)
        let processedLoginPrivilegedEveryPayloads = payload.processPayloadScripts(ofType: .loginPrivilegedEvery)
        
        if !(processedLoginPrivilegedOncePayloads || onceDir.isEmpty) {
            processItems(.loginPrivilegedOnce, once: true, override: prefs.overrideLoginOnce)
        }
        
        if !(processedLoginPrivilegedEveryPayloads || everyDir.isEmpty) {
            processItems(.loginPrivilegedEvery)
        }
    }
}

func processLoginEveryTasks(payload: ScriptPayloads, prefs: OutsetPreferences) {
    writeLog("Processing scripts in login-every", logLevel: .info)
    let everyDir = PayloadType.loginEvery
    let ignoreUser = prefs.ignoredUsers.contains(consoleUser)
    
    if ignoreUser {
        writeLog("user \(consoleUser) is in the ignored list. skipping", logLevel: .debug)
    } else {
        let processedLogonPayloads = payload.processPayloadScripts(ofType: .loginEvery)
        
        if !(processedLogonPayloads || everyDir.isEmpty) {
            processItems(.loginEvery)
        }
    }
}

func processLoginOnceTasks(payload: ScriptPayloads, prefs: OutsetPreferences) {
    writeLog("Processing scripts in login-once", logLevel: .info)
    let onceDir = PayloadType.loginOnce
    let ignoreUser = prefs.ignoredUsers.contains(consoleUser)
    
    if ignoreUser {
        writeLog("user \(consoleUser) is in the ignored list. skipping", logLevel: .debug)
    } else {
        let processedLogonPayloads = payload.processPayloadScripts(ofType: .loginOnce)
        
        if !(processedLogonPayloads || onceDir.isEmpty) {
            processItems(.loginOnce, once: true, override: prefs.overrideLoginOnce)
        }
    }
}
