//
//  Preferences.swift
//  Outset
//
//  Created by Bart E Reardon on 5/9/2023.
//

import Foundation

typealias RunOnce = [String: Date]

struct OutsetPreferences: Codable {
    var waitForNetwork: Bool = false
    var networkTimeout: Int = 180
    var ignoredUsers: [String] = []
    var overrideLoginOnce: RunOnce = RunOnce()

    enum CodingKeys: String, CodingKey {
        case waitForNetwork = "wait_for_network"
        case networkTimeout = "network_timeout"
        case ignoredUsers = "ignored_users"
        case overrideLoginOnce = "override_login_once"
    }
}

func writeOutsetPreferences(prefs: OutsetPreferences) {

    if debugMode {
        showPrefrencePath("Stor")
    }

    let defaults = UserDefaults.standard

    // Take the OutsetPreferences object and write it to UserDefaults
    let mirror = Mirror(reflecting: prefs)
    for child in mirror.children {
        // Use the name of each property as the key, and save its value to UserDefaults
        if let propertyName = child.label {
            let key = propertyName.camelCaseToUnderscored()
            if isRoot() {
                // write the preference to /Library/Preferences/
                CFPreferencesSetValue(key as CFString,
                                      child.value as CFPropertyList,
                                      Bundle.main.bundleIdentifier! as CFString,
                                      kCFPreferencesAnyUser,
                                      kCFPreferencesAnyHost)
            } else {
                // write the preference to ~/Library/Preferences/
                defaults.set(child.value, forKey: key)
            }
        }
    }
}

func loadOutsetPreferences() -> OutsetPreferences {

    if debugMode {
        showPrefrencePath("Load")
    }

    let defaults = UserDefaults.standard
    var outsetPrefs = OutsetPreferences()

    if isRoot() {
        // force preferences to be read from /Library/Preferences instead of root's preferences
        outsetPrefs.networkTimeout = CFPreferencesCopyValue("network_timeout" as CFString, Bundle.main.bundleIdentifier! as CFString, kCFPreferencesAnyUser, kCFPreferencesAnyHost) as? Int ?? 180
        outsetPrefs.ignoredUsers = CFPreferencesCopyValue("ignored_users" as CFString, Bundle.main.bundleIdentifier! as CFString, kCFPreferencesAnyUser, kCFPreferencesAnyHost) as? [String] ?? []
        outsetPrefs.overrideLoginOnce = CFPreferencesCopyValue("override_login_once" as CFString, Bundle.main.bundleIdentifier! as CFString, kCFPreferencesAnyUser, kCFPreferencesAnyHost) as? RunOnce ?? [:]
        outsetPrefs.waitForNetwork = (CFPreferencesCopyValue("wait_for_network" as CFString, Bundle.main.bundleIdentifier! as CFString, kCFPreferencesAnyUser, kCFPreferencesAnyHost) != nil)
    } else {
        // load preferences for the current user, which includes /Library/Preferences
        outsetPrefs.networkTimeout = defaults.integer(forKey: "network_timeout")
        outsetPrefs.ignoredUsers = defaults.array(forKey: "ignored_users") as? [String] ?? []
        outsetPrefs.overrideLoginOnce = defaults.object(forKey: "override_login_once") as? RunOnce ?? [:]
        outsetPrefs.waitForNetwork = defaults.bool(forKey: "wait_for_network")
    }
    return outsetPrefs
}

func loadRunOncePlist() -> RunOnce {

    if debugMode {
        showPrefrencePath("Load")
    }

    let defaults = UserDefaults.standard
    var runOnceKey = "run_once"

    if isRoot() {
        runOnceKey += "-"+getConsoleUserInfo().username
        return CFPreferencesCopyValue(runOnceKey as CFString, Bundle.main.bundleIdentifier! as CFString, kCFPreferencesAnyUser, kCFPreferencesAnyHost) as? RunOnce ?? [:]
    } else {
        return defaults.object(forKey: runOnceKey) as? RunOnce ?? [:]
    }
}

func writeRunOncePlist(runOnceData: RunOnce) {

    if debugMode {
        showPrefrencePath("Stor")
    }

    let defaults = UserDefaults.standard
    var runOnceKey = "run_once"

    if isRoot() {
        runOnceKey += "-"+getConsoleUserInfo().username
        CFPreferencesSetValue(runOnceKey as CFString,
                              runOnceData as CFPropertyList,
                              Bundle.main.bundleIdentifier! as CFString,
                              kCFPreferencesAnyUser,
                              kCFPreferencesAnyHost)
    } else {
        defaults.set(runOnceData, forKey: runOnceKey)
    }
}

func showPrefrencePath(_ action: String) {
    var prefsPath: String
    if isRoot() {
        prefsPath = "/Library/Preferences".appending("/\(Bundle.main.bundleIdentifier!).plist")
    } else {
        let path = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true)
        prefsPath = path[0].appending("/Preferences").appending("/\(Bundle.main.bundleIdentifier!).plist")
    }
    writeLog("\(action)ing preference file: \(prefsPath)", logLevel: .debug)
}
