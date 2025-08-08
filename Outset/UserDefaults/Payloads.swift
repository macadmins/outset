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

typealias ScriptEntry = [String: Data]

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
    private func decodeBase64Script(base64Data: Data) -> String? {
        if let data = Data(base64Encoded: base64Data),
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
            writeLog("Checking payloads for \(context)", logLevel: .debug)
            guard let scripts = scripts else {
                writeLog("No payload scripts found for context: \(context)", logLevel: .debug)
                return false
            }
            writeLog("Processing scripts for context: \(context)")
            for (name, base64Data) in scripts {
                writeLog("Processing \(context) payload script : \(name)")
                if let script = decodeBase64Script(base64Data: base64Data) {
                    if let tempScript = saveTempFile(script) {
                        processScripts(scripts: [tempScript.path], altName: name, once: runOnceType, override: runOnceData)
                        cleanupTempFile(tempScript)
                        
                        // record runeonce data for boot-once payloads
                        if context == PayloadKeys.bootOnce.key {
                            writeLog("Writing run-once data for \(context)", logLevel: .debug)
                            let bootOnceData: RunOnce = [name: Date()]
                            writeRunOncePlist(runOnceData: bootOnceData, bootOnce: true)
                        }
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
        var keys: [String] = []
        // keys += CFPreferencesCopyKeyList(appBundle, kCFPreferencesAnyUser, kCFPreferencesAnyHost) as? [String] ?? []
        for (key, _) in userDefaults.dictionaryRepresentation() where key.starts(with: "script_payloads") {
            keys.append(key)
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
        // let forced = CFPreferencesAppValueIsForced("script_payloads" as CFString, appBundle)
        var payloads: [ScriptPayloads] = []
        var currentPayload: ScriptPayloads = ScriptPayloads()
        // we will want to limit returning payloads to managed profiles only
        // unless running in debug mode

        for key in allPreferenceKeys where key.starts(with: "script_payloads") {
            writeLog("found key \(key)", logLevel: .debug)
            if CFPreferencesAppValueIsForced(key as CFString, appBundle) {
                writeLog("Payload \"\(key)\" is managed")
            } else {
                writeLog("Payload \"\(key)\" is not managed")
                if !debugMode {
                    writeLog("Payloads in \"\(key)\" will not be processed")
                    continue
                } else {
                    writeLog("DEBUG is enabled. Payloads in \"\(key)\" will be processed")
                }
            }
            if let payloadDict = CFPreferencesCopyAppValue(key as CFString, appBundle) {
                // writeLog("\(payloadDict)", logLevel: .debug)
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
        writeLog("Error: CFPropertyList is not a dictionary", logLevel: .error)
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
