//
//  Preferences.swift
//  Outset
//
//  Created by Bart E Reardon on 5/9/2023.
//

import Foundation

struct OutsetPreferences: Codable {
    var waitForNetwork: Bool = false
    var networkTimeout: Int = 180
    var ignoredUsers: [String] = []
    var overrideLoginOnce: [String: Date] = [String: Date]()

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
        outsetPrefs.overrideLoginOnce = CFPreferencesCopyValue("override_login_once" as CFString, Bundle.main.bundleIdentifier! as CFString, kCFPreferencesAnyUser, kCFPreferencesAnyHost) as? [String: Date] ?? [:]
        outsetPrefs.waitForNetwork = (CFPreferencesCopyValue("wait_for_network" as CFString, Bundle.main.bundleIdentifier! as CFString, kCFPreferencesAnyUser, kCFPreferencesAnyHost) != nil)
    } else {
        // load preferences for the current user, which includes /Library/Preferences
        outsetPrefs.networkTimeout = defaults.integer(forKey: "network_timeout")
        outsetPrefs.ignoredUsers = defaults.array(forKey: "ignored_users") as? [String] ?? []
        outsetPrefs.overrideLoginOnce = defaults.object(forKey: "override_login_once") as? [String: Date] ?? [:]
        outsetPrefs.waitForNetwork = defaults.bool(forKey: "wait_for_network")
    }
    return outsetPrefs
}

func loadRunOncePlist() -> [String: Date] {

    if debugMode {
        showPrefrencePath("Load")
    }

    let defaults = UserDefaults.standard
    var runOnceKey = "run_once"

    if isRoot() {
        runOnceKey += "-"+getConsoleUserInfo().username
        return CFPreferencesCopyValue(runOnceKey as CFString, Bundle.main.bundleIdentifier! as CFString, kCFPreferencesAnyUser, kCFPreferencesAnyHost) as? [String: Date] ?? [:]
    } else {
        return defaults.object(forKey: runOnceKey) as? [String: Date] ?? [:]
    }
}

func writeRunOncePlist(runOnceData: [String: Date]) {

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

func migrateLegacyPreferences() {
    let newoldRootUserDefaults = "/var/root/Library/Preferences/io.macadmins.Outset.plist"
    // shared folder should not contain any executable content, iterate and update as required
    if checkFileExists(path: shareDirectory) || checkFileExists(path: newoldRootUserDefaults) {
        writeLog("Legacy preferences exist. Migrating to user defaults", logLevel: .debug)

        let legacyOutsetPreferencesFile = "\(shareDirectory)com.chilcote.outset.plist"
        let legacyRootRunOncePlistFile = "com.github.outset.once.\(getConsoleUserInfo().userID).plist"
        let userHomeDirectory = FileManager.default.homeDirectoryForCurrentUser
        let userHomePath = userHomeDirectory.relativeString.replacingOccurrences(of: "file://", with: "")
        let legacyUserRunOncePlistFile = userHomePath+"Library/Preferences/com.github.outset.once.plist"

        var shareFiles: [String] = []
        shareFiles.append(legacyOutsetPreferencesFile)
        shareFiles.append(legacyRootRunOncePlistFile)
        shareFiles.append(legacyUserRunOncePlistFile)
        shareFiles.append(newoldRootUserDefaults)

        for filename in shareFiles where checkFileExists(path: filename) {

            let url = URL(fileURLWithPath: filename)
            do {
                let data = try Data(contentsOf: url)
                switch filename {

                case newoldRootUserDefaults:
                    if isRoot() {
                        writeLog("\(newoldRootUserDefaults) migration", logLevel: .debug)
                        let legacyDefaultKeys = CFPreferencesCopyKeyList(Bundle.main.bundleIdentifier! as CFString, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
                        for key in legacyDefaultKeys as! [CFString] {
                            let keyValue = CFPreferencesCopyValue(key, Bundle.main.bundleIdentifier! as CFString, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
                            CFPreferencesSetValue(key as CFString,
                                                  keyValue as CFPropertyList,
                                                  Bundle.main.bundleIdentifier! as CFString,
                                                  kCFPreferencesAnyUser,
                                                  kCFPreferencesAnyHost)
                        }
                        deletePath(newoldRootUserDefaults)
                    }
                case legacyOutsetPreferencesFile:
                    if isRoot() {
                        writeLog("\(legacyOutsetPreferencesFile) migration", logLevel: .debug)
                        do {
                            let legacyPreferences = try PropertyListDecoder().decode(OutsetPreferences.self, from: data)
                            writeOutsetPreferences(prefs: legacyPreferences)
                            writeLog("Migrated Legacy Outset Preferences", logLevel: .debug)
                            deletePath(legacyOutsetPreferencesFile)
                        } catch {
                            writeLog("legacy Preferences migration failed", logLevel: .error)
                        }
                    }
                case legacyRootRunOncePlistFile, legacyUserRunOncePlistFile:
                    writeLog("\(legacyRootRunOncePlistFile) and \(legacyUserRunOncePlistFile) migration", logLevel: .debug)
                    do {
                        let legacyRunOncePlistData = try PropertyListDecoder().decode([String: Date].self, from: data)
                        writeRunOncePlist(runOnceData: legacyRunOncePlistData)
                        writeLog("Migrated Legacy Runonce Data", logLevel: .debug)
                        if isRoot() {
                            deletePath(legacyRootRunOncePlistFile)
                        } else {
                            deletePath(legacyUserRunOncePlistFile)
                        }
                    } catch {
                        writeLog("legacy Run Once Plist migration failed", logLevel: .error)
                    }

                default:
                    continue
                }
            } catch {
                writeLog("could not load \(filename)", logLevel: .error)
            }

        }

        if checkFileExists(path: shareDirectory) && folderContents(path: shareDirectory).isEmpty {
            deletePath(shareDirectory)
        }
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
