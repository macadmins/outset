//
//  LegacyPreferences.swift
//  Outset
//
//  Created by Bart E Reardon on 26/6/2024.
//

import Foundation

func migrateLegacyPreferences() {
    let newoldRootUserDefaults = "/var/root/Library/Preferences/io.macadmins.Outset.plist"
    // shared folder should not contain any executable content, iterate and update as required
    if checkFileExists(path: PayloadType.shared.directoryPath) || checkFileExists(path: newoldRootUserDefaults) {
        writeLog("Legacy preferences exist. Migrating to user defaults", logLevel: .debug)

        let legacyOutsetPreferencesFile = "\(PayloadType.shared.directoryPath)com.chilcote.outset.plist"
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
                    if isRoot {
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
                    if isRoot {
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
                        if isRoot {
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

        if checkFileExists(path: PayloadType.shared.directoryPath) && folderContents(path: PayloadType.shared.directoryPath).isEmpty {
            deletePath(PayloadType.shared.directoryPath)
        }
    }

}
