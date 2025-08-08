//
//  IgnoredUser.swift
//  Outset
//
//  Created by Reardon, Bart (IM&T, Black Mountain) on 6/8/2025.
//

import Foundation

/// Adds one or more usernames to the ignored users list in preferences.
///
/// This function ensures the current process has root privileges before
/// modifying the ignored users list.
/// - For each provided username:
///   - If the username is already present in `prefs.ignoredUsers`, a log entry
///     is written at `.info` level indicating no change.
///   - If the username is not present, it is appended to the ignored users list
///     and a log entry is written at `.info` level indicating the addition.
///
/// After processing all usernames, the updated preferences are written to disk.
///
/// - Parameters:
///   - userArray: An array of usernames to add. Defaults to an empty array.
///   - prefs: The `OutsetPreferences` object containing the current ignored
///     users list and other configuration.
///
/// - Important: Requires root privileges.
/// - SeeAlso: `removeIgnoredUsers(_:prefs:)`
func addIgnoredUsers(_ userArray: [String] = [], prefs: inout OutsetPreferences) {
    ensureRoot("add to ignored users")
    for username in userArray {
        if prefs.ignoredUsers.contains(username) {
            writeLog("User \"\(username)\" is already in the ignored users list", logLevel: .info)
        } else {
            writeLog("Adding \(username) to ignored users list", logLevel: .info)
            prefs.ignoredUsers.append(username)
        }
    }
    writeOutsetPreferences(prefs: prefs)
}

/// Removes one or more usernames from the ignored users list in preferences.
///
/// This function ensures the current process has root privileges before
/// modifying the ignored users list.
/// - For each username in `userArray`:
///   - If the username exists in `prefs.ignoredUsers`, it is removed and a log
///     entry is written at `.info` level indicating the removal.
///   - If the username does not exist in the list, a log entry is written at
///     `.info` level indicating that no change was made.
///
/// After processing, the updated preferences are written to disk.
///
/// - Parameters:
///   - userArray: An array of usernames to remove. Defaults to an empty array.
///   - prefs: The `OutsetPreferences` object containing the current ignored
///     users list and other configuration.
///
/// - Important: Requires root privileges.
/// - SeeAlso: `addIgnoredUsers(_:prefs:)`
func removeIgnoredUsers(_ userArray: [String] = [], prefs: inout OutsetPreferences) {
    ensureRoot("remove ignored users")
    for username in userArray {
        if let index = prefs.ignoredUsers.firstIndex(of: username) {
            writeLog("Removing \(username) from ignored users list", logLevel: .info)
            prefs.ignoredUsers.remove(at: index)
        } else {
            writeLog("User \"\(username)\" is not in the ignored users list", logLevel: .info)
        }

    }
    writeOutsetPreferences(prefs: prefs)
}
