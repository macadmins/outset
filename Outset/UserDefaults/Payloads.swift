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

struct ScriptPayloads: Codable {
    var loginWindowScripts: ScriptEntry?
    var loginOnceScripts: ScriptEntry?
    var loginEveryScripts: ScriptEntry?
    var loginPrivilegedOnceScripts: ScriptEntry?
    var loginPrivilegedEveryScripts: ScriptEntry?
    var bootOnceScripts: ScriptEntry?
    var bootEveryScripts: ScriptEntry?

    enum CodingKeys: String, CodingKey {
        case loginWindowScripts = "login-window"
        case loginOnceScripts = "login-once"
        case loginEveryScripts = "login-every"
        case loginPrivilegedOnceScripts = "login-privileged-once"
        case loginPrivilegedEveryScripts = "login-privileged-every"
        case bootOnceScripts = "boot-once"
        case bootEveryScripts = "boot-every"
    }

    // Decodes base64 string into a script text
    private func decodeBase64Script(base64String: String) -> String? {
        if let data = Data(base64Encoded: base64String),
           let script = String(data: data, encoding: .utf8) {
            return script
        }
        return nil
    }

    func processPayloadScripts(ofType type: PayloadType? = nil, runOnceData: RunOnce = RunOnce()) -> Bool {
        // Determine which payloads to process based on the specified type
        let payloadsToProcess: [(String, ScriptEntry?)] = {
            switch type {
            case .loginWindow:
                return [(PayloadKeys.loginWindow.key, loginWindowScripts)]
            case .loginOnce:
                return [(PayloadKeys.loginOnce.key, loginOnceScripts)]
            case .loginEvery:
                return [(PayloadKeys.loginEvery.key, loginEveryScripts)]
            case .loginPrivilegedOnce:
                return [(PayloadKeys.loginPrivilegedOnce.key, loginPrivilegedOnceScripts)]
            case .loginPrivilegedEvery:
                return [(PayloadKeys.loginPrivilegedEvery.key, loginPrivilegedEveryScripts)]
            case .bootOnce:
                return [(PayloadKeys.bootOnce.key, bootOnceScripts)]
            case .bootEvery:
                return [(PayloadKeys.bootEvery.key, bootEveryScripts)]
            default:
                return []
            }
        }()

        let runOnceType = type?.once ?? false

        // Process each selected payload
        for (context, scripts) in payloadsToProcess {
            guard let scripts = scripts else {
                writeLog("No scripts found for context: \(context)", logLevel: .debug)
                return false
            }
            writeLog("Processing scripts for context: \(context)")
            for (name, base64Data) in scripts {
                writeLog("Processing \(context) payload script : \(name)")
                if let script = decodeBase64Script(base64String: base64Data) {
                    if let tempScript = saveTempFile(script) {
                        processScripts(scripts: [tempScript.path], altName: name, once: runOnceType, override: runOnceData)
                        cleanupTempFile(tempScript)
                    }
                } else {
                    writeLog("Failed to decode script: \(name)", logLevel: .error)
                }
            }
        }
        return true
    }

    private func saveTempFile(_ base64: String) -> URL? {
        // Write script to a temporary file
        let tempDir = FileManager.default.temporaryDirectory
        let tempFileURL = tempDir.appendingPathComponent(UUID().uuidString)

        do {
            try base64.write(to: tempFileURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tempFileURL.path)
            writeLog("Wrote payload to \(tempFileURL.path)", logLevel: .debug)
            return tempFileURL
        } catch {
            writeLog("Failed to write script to temporary file: \(error)", logLevel: .error)
        }
        return nil
    }

    private func cleanupTempFile(_ tempFile: URL) {
        // Clean up the temporary file
        do {
            try FileManager.default.removeItem(at: tempFile)
            writeLog("Cleaned up \(tempFile.path)", logLevel: .debug)
        } catch {
            writeLog("Failed to clean up temporary file \(tempFile.path): \(error)", logLevel: .error)
        }
    }
}

// Utility to load `ScriptPayloads` from UserDefaults
class ScriptPayloadManager {
    private let userDefaults: UserDefaults
    private let appBundle: CFString = Bundle.main.bundleIdentifier! as CFString

    init() {
        self.userDefaults = UserDefaults.standard
    }

    private var allPreferenceKeys: [String] {
        // Get the keys
        guard let keys = CFPreferencesCopyKeyList(appBundle, kCFPreferencesAnyUser, kCFPreferencesAnyHost) as? [String] else {
            return []
        }
        return keys
    }

    private func mergeScriptPayloads(_ payloads: [ScriptPayloads]) -> ScriptPayloads {
        func mergeEntries(_ keyPath: KeyPath<ScriptPayloads, ScriptEntry?>) -> ScriptEntry? {
            var combined: ScriptEntry = [:]
            for payload in payloads {
                if let entry = payload[keyPath: keyPath] {
                    for (key, value) in entry {
                        combined[key] = value
                    }
                }
            }
            return combined.isEmpty ? nil : combined
        }

        return ScriptPayloads(
            loginWindowScripts: mergeEntries(\.loginWindowScripts),
            loginOnceScripts: mergeEntries(\.loginOnceScripts),
            loginEveryScripts: mergeEntries(\.loginEveryScripts),
            loginPrivilegedOnceScripts: mergeEntries(\.loginPrivilegedOnceScripts),
            loginPrivilegedEveryScripts: mergeEntries(\.loginPrivilegedEveryScripts),
            bootOnceScripts: mergeEntries(\.bootOnceScripts),
            bootEveryScripts: mergeEntries(\.bootEveryScripts)
        )
    }

    // Loads and decodes ScriptPayloads from UserDefaults
    func loadScriptPayloads() -> ScriptPayloads? {
        let forced = CFPreferencesAppValueIsForced("script_payloads" as CFString, appBundle)
        var payloads: [ScriptPayloads] = []
        var currentPayload: ScriptPayloads = ScriptPayloads()
        // we will want to limit returning payloads to managed profiles only
        // unless running in debug mode

        for key in allPreferenceKeys where key.starts(with: "script_payloads") {
            print("found key \(key)")
            if CFPreferencesAppValueIsForced(key as CFString, appBundle) {
                writeLog("Payload \(key) is forced")
            } else {
                writeLog("Payload \(key) is not forced")
                if !debugMode {
                    continue
                }
            }
            if let payloadDict = CFPreferencesCopyValue(key as CFString, appBundle, kCFPreferencesAnyUser, kCFPreferencesAnyHost) {
                print(payloadDict)
                do {
                    let decoder = PropertyListDecoder()
                    let payloadData = try PropertyListSerialization.data(fromPropertyList: payloadDict, format: .xml, options: 0)
                    currentPayload = try decoder.decode(ScriptPayloads.self, from: payloadData)
                    payloads.append(currentPayload)
                } catch {
                    writeLog("Failed to decode script payloads for \(key): \(error)", logLevel: .debug)
                }
            }
        }
        return mergeScriptPayloads(payloads)
    }
}

func getScriptPayloads() -> ScriptPayloads {
    if let scriptPayloads = ScriptPayloadManager().loadScriptPayloads() {
        return scriptPayloads
    }
    return ScriptPayloads()
}

func appendContents(of propertyList: CFDictionary, to targetDictionary: inout ScriptPayloads) {
    // Convert CFPropertyList to Swift Dictionary
    guard let plistDictionary = propertyList as? [String: Any] else {
        print("Error: CFPropertyList is not a dictionary")
        return
    }

    // Append each key-value pair into the target dictionary
    for (key, value) in plistDictionary {
        writeLog("key :\(key) - value : \(value)")
    }
}

// swiftlint:disable colon operator_whitespace
public func +<K, V>(left: [K:V], right: [K:V]) -> [K:V] {
    return left.merging(right) { $1 }
}
// swiftlint:enable colon operator_whitespace
