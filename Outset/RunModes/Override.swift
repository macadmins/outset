//
//  Override.swift
//  Outset
//
//  Created by Reardon, Bart (IM&T, Black Mountain) on 6/8/2025.
//

import Foundation

func runAddOveride(_ overrides: [String] = [], prefs: OutsetPreferences) {
    ensureRoot("add scripts to override list")
    
    var overrideLoginOnce = prefs.overrideLoginOnce
    let loginOnce = PayloadType.loginOnce
    let loginPrivilegedOnce = PayloadType.loginPrivilegedOnce
    
    for var override in overrides {
        if override.starts(with: "payload=") {
            override = override.components(separatedBy: "=").last ?? "nil"
        } else if !override.contains(loginOnce.directoryPath) && !override.contains(loginPrivilegedOnce.directoryPath) {
            override = "\(loginOnce.directoryPath)/\(override)"
        }
        writeLog("Adding \(override) to override list", logLevel: .debug)
        overrideLoginOnce[override] = Date()
    }
    writeOutsetPreferences(prefs: prefs)
}

func runRemoveOveride(_ overrides: [String] = [], prefs: OutsetPreferences) {
    ensureRoot("remove scripts to override list")
    
    var overrideLoginOnce = prefs.overrideLoginOnce
    let loginOnce = PayloadType.loginOnce
    
    for var override in overrides {
        if override.starts(with: "payload=") {
            override = override.components(separatedBy: "=").last ?? "nil"
        } else if !override.contains(loginOnce.directoryPath) {
            override = "\(loginOnce.directoryPath)/\(override)"
        }
        writeLog("Removing \(override) from override list", logLevel: .debug)
        overrideLoginOnce.removeValue(forKey: override)
    }
    writeOutsetPreferences(prefs: prefs)
}
