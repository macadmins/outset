//
//  Functions.swift
//  outset
//
//  Created by Bart Reardon on 1/12/2022.
//

import Foundation
import SystemConfiguration
import IOKit
import CoreFoundation

enum Action {
    case enable
    case disable
}

func ensureRoot(_ reason: String) {
    if !isRoot {
        writeLog("Must be root to \(reason)", logLevel: .error)
        exit(1)
    }
}

var isRoot: Bool {
    return NSUserName() == "root"
}

func getConsoleUserInfo() -> (username: String, userID: String) {
    // We need the console user, not the process owner so NSUserName() won't work for our needs when outset runs as root
    var uid: uid_t = 0
    if let consoleUser = SCDynamicStoreCopyConsoleUser(nil, &uid, nil) as? String {
        return (consoleUser, "\(uid)")
    } else {
        return ("", "")
    }
}

func loginWindowUpdateState(_ action: Action) {
    var cmd: String
    let loginWindowPlist: String = "/System/Library/LaunchDaemons/com.apple.loginwindow.plist"
    switch action {
    case .enable:
        writeLog("Enabling loginwindow process", logLevel: .debug)
        cmd = "/bin/launchctl load \(loginWindowPlist)"
    case .disable:
        writeLog("Disabling loginwindow process", logLevel: .debug)
        cmd = "/bin/launchctl unload \(loginWindowPlist)"
    }
        _ = runShellCommand(cmd)
}

@discardableResult
func runIf(_ condition: Bool, _ action: () -> Void) -> Bool {
    if condition { action() }
    return condition
}
