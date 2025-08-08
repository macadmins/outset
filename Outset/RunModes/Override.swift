//
//  Override.swift
//  Outset
//
//  Created by Bart Reardon on 6/8/2025.
//

import Foundation

/// Adds one or more scripts to the login-once override list.
///
/// This function ensures the current process has root privileges before
/// modifying the override list.
/// - Each override entry is processed as follows:
///   1. If it begins with `"payload="`, the prefix is stripped, leaving only
///      the payload path or script name.
///   2. If it does not already contain the `.loginOnce` or `.loginPrivilegedOnce`
///      payload directory path, the `.loginOnce` path is prepended.
/// - The processed override path is added to `prefs.overrideLoginOnce` with the
///   current date as the value.
///
/// After processing all overrides, the updated preferences are written to disk.
///
/// - Parameters:
///   - overrides: An array of script names or payload paths to add to the
///     override list. Defaults to an empty array.
///   - prefs: The `OutsetPreferences` object containing the current override
///     list and other configuration.
///
/// - Important: Requires root privileges.
/// - SeeAlso: `runRemoveOveride(_:prefs:)`
func runAddOveride(_ overrides: [String] = [], prefs: inout OutsetPreferences) {
    ensureRoot("add scripts to override list")
    let loginOnce = PayloadType.loginOnce
    let loginPrivilegedOnce = PayloadType.loginPrivilegedOnce

    for var override in overrides {
        if override.starts(with: "payload=") {
            override = override.components(separatedBy: "=").last ?? "nil"
        } else if !override.contains(loginOnce.directoryPath) &&
                  !override.contains(loginPrivilegedOnce.directoryPath) {
            override = "\(loginOnce.directoryPath)/\(override)"
        }
        writeLog("Adding \(override) to override list", logLevel: .debug)
        prefs.overrideLoginOnce[override] = Date()
    }
    writeOutsetPreferences(prefs: prefs)
}

/// Removes one or more scripts from the login-once override list.
///
/// This function ensures the current process has root privileges before
/// modifying the override list.
/// - Each override entry is processed as follows:
///   1. If it begins with `"payload="`, the prefix is stripped, leaving only
///      the payload path or script name.
///   2. If it does not already contain the `.loginOnce` payload directory path,
///      the `.loginOnce` path is prepended.
/// - The processed override path is removed from `prefs.overrideLoginOnce` if
///   present.
///
/// After processing all overrides, the updated preferences are written to disk.
///
/// - Parameters:
///   - overrides: An array of script names or payload paths to remove from the
///     override list. Defaults to an empty array.
///   - prefs: The `OutsetPreferences` object containing the current override
///     list and other configuration.
///
/// - Important: Requires root privileges.
/// - SeeAlso: `runAddOveride(_:prefs:)`
func runRemoveOveride(_ overrides: [String] = [], prefs: inout OutsetPreferences) {
    ensureRoot("remove scripts to override list")
    let loginOnce = PayloadType.loginOnce

    for var override in overrides {
        if override.starts(with: "payload=") {
            override = override.components(separatedBy: "=").last ?? "nil"
        } else if !override.contains(loginOnce.directoryPath) {
            override = "\(loginOnce.directoryPath)/\(override)"
        }
        writeLog("Removing \(override) from override list", logLevel: .debug)
        prefs.overrideLoginOnce.removeValue(forKey: override)
    }
    writeOutsetPreferences(prefs: prefs)
}
