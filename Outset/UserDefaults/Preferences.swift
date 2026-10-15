//
//  Preferences.swift
//  Outset
//
//  Created by Bart E Reardon on 5/9/2023.
//

import Foundation

typealias RunOnce = [String: Date]

struct OutsetPreferences: Codable {
    var waitForNetwork: Bool = defaultWaitForNetwork
    var networkTimeout: Int = defaultNetworkTimeout
    var ignoredUsers: [String] = []
    var overrideLoginOnce: RunOnce = RunOnce()
    // Timeout in seconds for background scripts (default 30). A value of 0
    // disables the limit and background scripts run until they exit naturally.
    var backgroundScriptTimeout: Int = defaultBackgroundScriptTimeout
    // Optional base64-encoded Ed25519 public key. When present (typically delivered
    // via MDM), every script must carry a valid embedded `# ed25519: <sig>` comment.
    // Scripts without a valid signature are refused.
    var manifestSigningKey: String = ""

    enum CodingKeys: String, CodingKey {
        case waitForNetwork = "wait_for_network"
        case networkTimeout = "network_timeout"
        case ignoredUsers = "ignored_users"
        case overrideLoginOnce = "override_login_once"
        case backgroundScriptTimeout = "background_script_timeout"
        case manifestSigningKey = "manifest_signing_key"
    }
}

func writeOutsetPreferences(prefs: OutsetPreferences) {
    if debugMode { showPreferencePath("Stor") }

    let defaults = UserDefaults.standard
    let appID = Bundle.main.bundleIdentifier! as CFString

    let values = localPreferenceValues(prefs: prefs, isManaged: isRoot ? preferenceIsManaged : { _ in false })
    for (key, value) in values {
        if isRoot {
            CFPreferencesSetValue(
                key as CFString,
                value as CFPropertyList,
                appID,
                kCFPreferencesAnyUser,
                kCFPreferencesAnyHost
            )
        } else {
            defaults.set(value, forKey: key)
        }
    }

    if isRoot {
        // Ensure values are written to /Library/Preferences
        CFPreferencesSynchronize(appID, kCFPreferencesAnyUser, kCFPreferencesAnyHost)
    } else {
        // Usually not necessary, but harmless if you want immediate flush
        defaults.synchronize()
    }
}

// Interprets a raw CFPreferences value as a boolean. Key presence alone must
// never be treated as true: writeOutsetPreferences persists every key on boot,
// so the key exists on all installations regardless of its value.
func boolPreference(_ rawValue: Any?, defaultValue: Bool) -> Bool {
    return rawValue as? Bool ?? defaultValue
}

func loadOutsetPreferences() -> OutsetPreferences {

    if debugMode {
        showPreferencePath("Load")
    }

    let defaults = UserDefaults.standard
    var outsetPrefs = OutsetPreferences()

    if isRoot {
        // Managed values take precedence over /Library/Preferences, never root's private domain.
        outsetPrefs.networkTimeout = rootPreferenceValue("network_timeout") as? Int ?? 180
        outsetPrefs.ignoredUsers = rootPreferenceValue("ignored_users") as? [String] ?? []
        outsetPrefs.overrideLoginOnce = rootPreferenceValue("override_login_once") as? RunOnce ?? [:]
        outsetPrefs.waitForNetwork = boolPreference(rootPreferenceValue("wait_for_network"), defaultValue: defaultWaitForNetwork)
        outsetPrefs.backgroundScriptTimeout = rootPreferenceValue("background_script_timeout") as? Int ?? defaultBackgroundScriptTimeout
        // manifest_signing_key is only honoured when MDM-managed (forced). A locally
        // written key could be used to disable script processing without detection,
        // so we ignore it unless it comes from a managed profile. In debug mode a
        // local value is accepted to allow workflow testing without an MDM enrolment.
        let signingKeyManaged = preferenceIsManaged("manifest_signing_key")
        if signingKeyManaged || debugMode {
            outsetPrefs.manifestSigningKey = rootPreferenceValue("manifest_signing_key") as? String ?? ""
            if !signingKeyManaged {
                writeLog("manifest_signing_key is not MDM-managed — accepted in debug mode only", logLevel: .debug)
            }
        } else if rootPreferenceValue("manifest_signing_key") != nil {
            writeLog("manifest_signing_key is present but not MDM-managed — ignoring to prevent tampering", logLevel: .error)
        }
    } else {
        // load preferences for the current user, which includes /Library/Preferences
        outsetPrefs.networkTimeout = defaults.integer(forKey: "network_timeout")
        outsetPrefs.ignoredUsers = defaults.array(forKey: "ignored_users") as? [String] ?? []
        outsetPrefs.overrideLoginOnce = defaults.object(forKey: "override_login_once") as? RunOnce ?? [:]
        outsetPrefs.waitForNetwork = defaults.bool(forKey: "wait_for_network")
        if defaults.object(forKey: "background_script_timeout") != nil {
            outsetPrefs.backgroundScriptTimeout = defaults.integer(forKey: "background_script_timeout")
        }

        outsetPrefs.manifestSigningKey = defaults.string(forKey: "manifest_signing_key") ?? ""

    }
    return outsetPrefs
}

// Do not materialize managed values in the local domain: they must disappear
// when the profile is removed, revealing the original local value or default.
func localPreferenceValues(prefs: OutsetPreferences, isManaged: (String) -> Bool) -> [String: Any] {
    var values: [String: Any] = [:]
    for child in Mirror(reflecting: prefs).children {
        guard let propertyName = child.label else { continue }
        let key = propertyName.camelCaseToUnderscored()
        if !isManaged(key) { values[key] = child.value }
    }
    return values
}

func preferenceIsManaged(_ key: String) -> Bool {
    CFPreferencesAppValueIsForced(key as CFString, Bundle.main.bundleIdentifier! as CFString)
}

func rootPreferenceValue(_ key: String) -> Any? {
    let appID = Bundle.main.bundleIdentifier! as CFString
    return resolvePreferenceValue(
        isManaged: preferenceIsManaged(key),
        managedValue: { CFPreferencesCopyAppValue(key as CFString, appID) },
        systemValue: { CFPreferencesCopyValue(key as CFString, appID, kCFPreferencesAnyUser, kCFPreferencesAnyHost) }
    )
}

// Keep unmanaged reads out of root's private preference domain.
func resolvePreferenceValue(isManaged: Bool, managedValue: () -> Any?, systemValue: () -> Any?) -> Any? {
    if isManaged, let value = managedValue() { return value }
    return systemValue()
}

/// Loads the run-once records for the current context.
///
/// - Parameter machineScoped: `true` for contexts whose records apply to the
///   machine as a whole (the boot contexts), which use the bare `run_once` key.
///   `false` - the default - scopes records to the console user under
///   `run_once-<username>`. This must reflect the payload context, not merely
///   whether the process is running as root: the privileged login contexts also
///   run as root but record per-user.
func loadRunOncePlist(machineScoped: Bool = false) -> RunOnce {

    if debugMode {
        showPreferencePath("Load")
    }

    let defaults = UserDefaults.standard
    var runOnceKey = "run_once"

    if isRoot {
        if !machineScoped {
            runOnceKey += "-"+getConsoleUserInfo().username
        }
        return CFPreferencesCopyValue(runOnceKey as CFString, Bundle.main.bundleIdentifier! as CFString, kCFPreferencesAnyUser, kCFPreferencesAnyHost) as? RunOnce ?? [:]
    } else {
        return defaults.object(forKey: runOnceKey) as? RunOnce ?? [:]
    }
}

/// Persists the run-once records for the current context.
///
/// - Parameter machineScoped: see `loadRunOncePlist(machineScoped:)`. Loads and
///   writes for the same context must always agree, or records are written to a
///   key that is never read back.
func writeRunOncePlist(runOnceData: RunOnce, machineScoped: Bool = false) {

    if debugMode {
        showPreferencePath("Stor")
    }

    let defaults = UserDefaults.standard
    var runOnceKey = "run_once"

    if isRoot {
        if !machineScoped {
            runOnceKey += "-"+getConsoleUserInfo().username
        }
        CFPreferencesSetValue(runOnceKey as CFString,
                              runOnceData as CFPropertyList,
                              Bundle.main.bundleIdentifier! as CFString,
                              kCFPreferencesAnyUser,
                              kCFPreferencesAnyHost)
    } else {
        defaults.set(runOnceData, forKey: runOnceKey)
    }
}

func showPreferencePath(_ action: String) {
    var prefsPath: String
    if isRoot {
        prefsPath = "/Library/Preferences".appending("/\(Bundle.main.bundleIdentifier!).plist")
    } else {
        let path = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true)
        prefsPath = path[0].appending("/Preferences").appending("/\(Bundle.main.bundleIdentifier!).plist")
    }
    writeLog("\(action)ing preference file: \(prefsPath)", logLevel: .debug)
}
