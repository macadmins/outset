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
    var loginWindow: ScriptEntry?
    var loginOnce: ScriptEntry?
    var loginEvery: ScriptEntry?
    var loginPrivilegedOnce: ScriptEntry?
    var loginPrivilegedEvery: ScriptEntry?
    var bootOnce: ScriptEntry?
    var bootEvery: ScriptEntry?

    enum CodingKeys: String, CodingKey {
        case loginWindow = "login_window"
        case loginOnce = "login_once"
        case loginEvery = "login_every"
        case loginPrivilegedOnce = "login_privileged_once"
        case loginPrivilegedEvery = "login_privileged_every"
        case bootOnce = "boot_once"
        case bootEvery = "boot_every"
    }

    enum PayloadType {
        case loginWindow
        case loginOnce
        case loginEvery
        case loginPrivilegedOnce
        case loginPrivilegedEvery
        case bootOnce
        case bootEvery
    }

    // Decodes base64 string into a script text
    private func decodeBase64Script(base64String: String) -> String? {
        if let data = Data(base64Encoded: base64String),
           let script = String(data: data, encoding: .utf8) {
            return script
        }
        return nil
    }

    func processScripts(ofType type: PayloadType? = nil) {
        // Determine which payloads to process based on the specified type
        let payloadsToProcess: [(String, [String: String]?)] = {
            switch type {
            case .loginWindow:
                return [("login_once", loginWindow)]
            case .loginOnce:
                return [("login_once", loginOnce)]
            case .loginEvery:
                return [("login_every", loginEvery)]
            case .loginPrivilegedOnce:
                return [("login_once", loginPrivilegedOnce)]
            case .loginPrivilegedEvery:
                return [("login_once", loginPrivilegedEvery)]
            case .bootOnce:
                return [("boot_once", bootOnce)]
            case .bootEvery:
                return [("boot_every", bootEvery)]
            default:
                return []
            }
        }()

        // Process each selected payload
        for (context, scripts) in payloadsToProcess {
            guard let scripts = scripts else {
                print("No scripts found for context: \(context)")
                continue
            }
            writeLog("Processing scripts for context: \(context)")
            for (name, base64Data) in scripts {
                if let script = decodeBase64Script(base64String: base64Data) {
                    writeLog("Executing script: \(name)")
                    executeScript(script)
                } else {
                    writeLog("Failed to decode script: \(name)", logLevel: .error)
                }
            }
        }
    }

    private func executeScript(_ script: String) {
        // Write script to a temporary file
        let tempDir = FileManager.default.temporaryDirectory
        let tempFileURL = tempDir.appendingPathComponent(UUID().uuidString)

        do {
            try script.write(to: tempFileURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tempFileURL.path)
            writeLog("Wrote payload to \(tempFileURL.path)", logLevel: .debug)
        } catch {
            writeLog("Failed to write script to temporary file: \(error)", logLevel: .error)
            return
        }

        let (output, error, status) = runShellCommand(tempFileURL.path, args: [consoleUser], verbose: true)
        if status != 0 {
            writeLog(error, logLevel: .error)
        } else {
            writeLog(output)
        }

        // Clean up the temporary file
        do {
            try FileManager.default.removeItem(at: tempFileURL)
            writeLog("Cleaned up \(tempFileURL.path)", logLevel: .debug)
        } catch {
            writeLog("Failed to clean up temporary file \(tempFileURL.path): \(error)", logLevel: .error)
        }
    }

}

// Utility to load `ScriptPayloads` from UserDefaults
class ScriptPayloadManager {
    private let userDefaults: UserDefaults

    init() {
        self.userDefaults = UserDefaults.standard
    }

    // Loads and decodes ScriptPayloads from UserDefaults
    func loadScriptPayloads() -> ScriptPayloads? {
        guard let payloadDict = CFPreferencesCopyValue("script_payloads" as CFString, Bundle.main.bundleIdentifier! as CFString, kCFPreferencesAnyUser, kCFPreferencesAnyHost) else {
        // guard let payloadData = userDefaults.data(forKey: "script_payloads") else {
            writeLog("No script payloads found in UserDefaults.", logLevel: .debug)
            return nil
        }

        print(payloadDict)

        do {
            // Convert dictionary to Data and decode with PropertyListDecoder
            let payloadData = try PropertyListSerialization.data(fromPropertyList: payloadDict, format: .xml, options: 0)
            let decoder = PropertyListDecoder()
            return try decoder.decode(ScriptPayloads.self, from: payloadData)
        } catch {
            writeLog("Failed to decode script payloads: \(error)", logLevel: .debug)
            return nil
        }
    }
}

func processPayloadScripts() {
    let manager = ScriptPayloadManager()

    if let scriptPayloads = manager.loadScriptPayloads() {
        // Process only `login_once` scripts
        scriptPayloads.processScripts(ofType: .loginOnce)

        // To process all scripts, call without arguments:
        scriptPayloads.processScripts(ofType: .loginEvery)
    } else {
        writeLog("No payloads to process.", logLevel: .debug)
    }
}
