//
//  Payloads.swift
//  Outset
//
//  Created by Bart E Reardon on 26/6/2024.
//

import Foundation

// Part of the script running functions
// Check to see if we have a payload or payloads containing scripts

// Should see if we can use dynamic naming or if we have to be specific
//

typealias ScriptEntry = [String: String]
typealias ScriptDictionary = [String: [ScriptEntry]]

struct ScriptPayload: Codable {
    var loginWindow: ScriptDictionary = [:]
    var loginOnce: ScriptDictionary = [:]
    var loginEvery: ScriptDictionary = [:]
    var loginPrivilegedOnce: ScriptDictionary = [:]
    var loginPrivilegedEvery: ScriptDictionary = [:]
    var bootOnce: ScriptDictionary = [:]
    var bootEvery: ScriptDictionary = [:]

    enum CodingKeys: String, CodingKey {
        case loginWindow = "login-window"
        case loginOnce = "login-once"
        case loginEvery = "login-every"
        case loginPrivilegedOnce = "login-privileged-once"
        case loginPrivilegedEvery = "login-privileged-every"
        case bootOnce = "boot-once"
        case bootEvery = "boot-every"
    }
}

func loadScriptPayload(forKey key: String) -> ScriptPayload? {
    if let savedData = UserDefaults.standard.data(forKey: key) {
        let decoder = JSONDecoder()
        if let loadedPayload = try? decoder.decode(ScriptPayload.self, from: savedData) {
            return loadedPayload
        }
    }
    return nil
}

func processScriptPayloads(payload: [ScriptEntry], once: Bool = false, override: [String: Date] = [:]) {
    let permissions: NSNumber = 0o755
    for scripts in payload {
        for (scriptName, b64script) in scripts {
            // Convert the script bundle from base64
            if let scriptData = Data(base64Encoded: b64script, options: .ignoreUnknownCharacters) {
                // write to temp location
                let tempDirectory = URL(fileURLWithPath: payloadDirectory, isDirectory: true)
                let tempFilePath = tempDirectory.appendingPathComponent(scriptName)
                do {
                    try scriptData.write(to: tempFilePath)
                    writeLog("Data written to temporary file: \(tempFilePath)", logLevel: .debug)
                } catch {
                    writeLog("Failed to write data to temporary file: \(error)", logLevel: .error)
                    return
                }

                // set file permissions
                do {
                    try FileManager.default.setAttributes([.posixPermissions: permissions], ofItemAtPath: tempFilePath.absoluteString)
                    writeLog("Permissions set successfully to 755 for file: \(tempFilePath)", logLevel: .debug)
                    processScripts(scripts: [tempFilePath.absoluteString], once: once, override: override)
                } catch {
                    writeLog("Failed to set permissions for file \(tempFilePath): \(error)", logLevel: .error)
                    writeLog("Payload \(scriptName) will not be processed", logLevel: .error)
                }

                // remove temp script
                deletePath(tempFilePath.absoluteString)
            }
        }
    }
}

func retrievePayload(forKey key: String) -> [ScriptEntry] {
    let bundleID = Bundle.main.bundleIdentifier! as CFString
    if CFPreferencesAppValueIsForced(key as CFString, bundleID) {
        if let value = CFPreferencesCopyValue(key as CFString, bundleID, kCFPreferencesAnyUser, kCFPreferencesAnyHost) as? [ScriptEntry] {
            return value
        }
    }
    return []
}

func retrieveScriptPayload() {
    if !retrievePayload(forKey: "login-window").isEmpty {

    }
}

/*


*/
