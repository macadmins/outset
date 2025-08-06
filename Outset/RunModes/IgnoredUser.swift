//
//  IgnoredUser.swift
//  Outset
//
//  Created by Reardon, Bart (IM&T, Black Mountain) on 6/8/2025.
//

import Foundation

func addIgnoredUsers(_ userArray: [String] = [], prefs: OutsetPreferences) {
    ensureRoot("add to ignored users")
    var ignoredUsers = prefs.ignoredUsers
    for username in userArray {
        if ignoredUsers.contains(username) {
            writeLog("User \"\(username)\" is already in the ignored users list", logLevel: .info)
        } else {
            writeLog("Adding \(username) to ignored users list", logLevel: .info)
            ignoredUsers.append(username)
        }
    }
    writeOutsetPreferences(prefs: prefs)
}

func removeIgnoredUsers(_ userArray: [String] = [], prefs: OutsetPreferences) {
    ensureRoot("remove ignored users")
    var ignoredUsers = prefs.ignoredUsers
    for username in ignoredUsers {
        if let index = ignoredUsers.firstIndex(of: username) {
            ignoredUsers.remove(at: index)
        }
    }
    writeOutsetPreferences(prefs: prefs)
}
