//
//  LoginWindow.swift
//  Outset
//
//  Created by Reardon, Bart (IM&T, Black Mountain) on 6/8/2025.
//

import Foundation

func processLoginWindowTasks() {
    writeLog("Processing scheduled runs for login window", logLevel: .info)

    if !scriptPayloads.processPayloadScripts(ofType: .loginWindow) &&
        !folderContents(type: .loginWindow).isEmpty {
        processItems(.loginWindow)
    }
}

func processLoginTasks() {
    writeLog("Processing scheduled runs for login", logLevel: .info)
    if !prefs.ignoredUsers.contains(consoleUser) {
        if !scriptPayloads.processPayloadScripts(ofType: .loginOnce, runOnceData: prefs.overrideLoginOnce) &&
            !folderContents(type: .loginOnce).isEmpty {
            processItems(.loginOnce, once: true, override: prefs.overrideLoginOnce)
        }
        if !scriptPayloads.processPayloadScripts(ofType: .loginEvery) &&
            !folderContents(type: .loginEvery).isEmpty {
            processItems(.loginEvery)
        }
        if !folderContents(type: .loginPrivilegedOnce).isEmpty || !folderContents(type: .loginPrivilegedEvery).isEmpty {
            createTrigger(Trigger.loginPrivileged.path)
        }
    }
}

func processLoginPrivilegedTasks() {
    writeLog("Processing scheduled runs for privileged login", logLevel: .info)
    if checkFileExists(path: Trigger.loginPrivileged.path) {
        pathCleanup(Trigger.loginPrivileged.path)
    }
    if !prefs.ignoredUsers.contains(consoleUser) {
        if !scriptPayloads.processPayloadScripts(ofType: .loginPrivilegedOnce, runOnceData: prefs.overrideLoginOnce) &&
            !folderContents(type: .loginPrivilegedOnce).isEmpty {
            processItems(.loginPrivilegedOnce, once: true, override: prefs.overrideLoginOnce)
        }
        if !scriptPayloads.processPayloadScripts(ofType: .loginPrivilegedEvery) &&
            !folderContents(type: .loginPrivilegedEvery).isEmpty {
            processItems(.loginPrivilegedEvery)
        }
    } else {
        writeLog("Skipping login scripts for user \(consoleUser)")
    }
}

func processLoginEveryTasks() {
    writeLog("Processing scripts in login-every", logLevel: .info)
    if !prefs.ignoredUsers.contains(consoleUser) {
        if !scriptPayloads.processPayloadScripts(ofType: .loginEvery) &&
            !folderContents(type: .loginEvery).isEmpty {
            processItems(.loginEvery)
        }
    }
}

func processLoginOnceTasks() {
    writeLog("Processing scripts in login-once", logLevel: .info)
    if !prefs.ignoredUsers.contains(consoleUser) {
        if !scriptPayloads.processPayloadScripts(ofType: .loginOnce, runOnceData: prefs.overrideLoginOnce) &&
            !folderContents(type: .loginOnce).isEmpty {
            processItems(.loginOnce, once: true, override: prefs.overrideLoginOnce)
        }
    } else {
        writeLog("user \(consoleUser) is in the ignored list. skipping", logLevel: .debug)
    }
}
