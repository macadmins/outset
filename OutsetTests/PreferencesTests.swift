//
//  PreferencesTests.swift
//  OutsetTests
//

import Testing
import Foundation

@Suite("OutsetPreferences defaults")
struct OutsetPreferencesTests {

    @Test("Default values are correct")
    func defaultValues() {
        let prefs = OutsetPreferences()
        #expect(prefs.waitForNetwork == false)
        #expect(prefs.networkTimeout == 180)
        #expect(prefs.ignoredUsers.isEmpty)
        #expect(prefs.overrideLoginOnce.isEmpty)
    }

    @Test("CodingKeys use underscore format")
    func codingKeysUseUnderscoreFormat() throws {
        // Encode and check the JSON keys match the expected preference key names
        let prefs = OutsetPreferences()
        let data = try JSONEncoder().encode(prefs)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["wait_for_network"] != nil)
        #expect(json["network_timeout"] != nil)
        #expect(json["ignored_users"] != nil)
        #expect(json["override_login_once"] != nil)
    }

    @Test("Encodes and decodes correctly")
    func roundTrip() throws {
        var prefs = OutsetPreferences()
        prefs.waitForNetwork = true
        prefs.networkTimeout = 300
        prefs.ignoredUsers = ["alice", "bob"]

        let data = try JSONEncoder().encode(prefs)
        let decoded = try JSONDecoder().decode(OutsetPreferences.self, from: data)

        #expect(decoded.waitForNetwork == true)
        #expect(decoded.networkTimeout == 300)
        #expect(decoded.ignoredUsers == ["alice", "bob"])
    }
}

@Suite("Run-once record scope")
struct RunOnceScopeTests {

    // Regression: processScripts chose the run-once key with `isRoot`, which is
    // true for both --boot and --login-privileged. Privileged login items were
    // therefore recorded under the machine-wide `run_once` key, so only the
    // first user to log in ever ran them.
    @Test("Only the boot contexts are machine scoped")
    func bootContextsAreMachineScoped() {
        #expect(PayloadType.bootOnce.machineScoped == true)
        #expect(PayloadType.bootEvery.machineScoped == true)
    }

    @Test("Privileged login contexts record per user, not machine wide")
    func privilegedLoginContextsArePerUser() {
        #expect(PayloadType.loginPrivilegedOnce.machineScoped == false)
        #expect(PayloadType.loginPrivilegedEvery.machineScoped == false)
    }

    @Test("Remaining contexts record per user")
    func otherContextsArePerUser() {
        #expect(PayloadType.loginOnce.machineScoped == false)
        #expect(PayloadType.loginEvery.machineScoped == false)
        #expect(PayloadType.loginWindow.machineScoped == false)
        #expect(PayloadType.onDemand.machineScoped == false)
        #expect(PayloadType.onDemandPrivileged.machineScoped == false)
        #expect(PayloadType.shared.machineScoped == false)
    }

    // The two properties are independent: a context can be run-once without
    // being machine scoped, which is exactly the login-privileged-once case
    // that the original conflation broke.
    @Test("Run-once and machine scope are independent")
    func onceAndScopeAreIndependent() {
        #expect(PayloadType.loginPrivilegedOnce.once == true)
        #expect(PayloadType.loginPrivilegedOnce.machineScoped == false)
        #expect(PayloadType.bootEvery.once == false)
        #expect(PayloadType.bootEvery.machineScoped == true)
    }
}

@Suite("Boolean preference interpretation")
struct BoolPreferenceTests {

    // Regression: loadOutsetPreferences once treated key *presence* as true.
    // Because writeOutsetPreferences persists every key on boot, that made
    // wait_for_network effectively always-on, which disabled auto-login on
    // every installation.
    @Test("A stored false loads as false even though the key is present")
    func storedFalseLoadsAsFalse() {
        #expect(boolPreference(false, defaultValue: false) == false)
        #expect(boolPreference(false, defaultValue: true) == false)
        // CFPreferencesCopyValue returns CF types, which bridge to NSNumber
        #expect(boolPreference(kCFBooleanFalse as Any, defaultValue: true) == false)
        #expect(boolPreference(NSNumber(value: false), defaultValue: true) == false)
    }

    @Test("A stored true loads as true")
    func storedTrueLoadsAsTrue() {
        #expect(boolPreference(true, defaultValue: false) == true)
        #expect(boolPreference(kCFBooleanTrue as Any, defaultValue: false) == true)
    }

    @Test("A missing key falls back to the default")
    func missingKeyUsesDefault() {
        #expect(boolPreference(nil, defaultValue: false) == false)
        #expect(boolPreference(nil, defaultValue: true) == true)
    }

    @Test("A non-boolean value falls back to the default")
    func nonBooleanValueUsesDefault() {
        #expect(boolPreference("true", defaultValue: false) == false)
    }
}

@Suite("Root preference precedence")
struct RootPreferencePrecedenceTests {
    @Test("A managed value wins over a conflicting system value")
    func managedWins() {
        let value = resolvePreferenceValue(isManaged: true, managedValue: { 600 }, systemValue: { 180 })
        #expect(value as? Int == 600)
    }

    @Test("An unmanaged key never reads the merged app domain")
    func unmanagedReadsSystem() {
        let value = resolvePreferenceValue(isManaged: false, managedValue: {
            Issue.record("Unmanaged keys must not read the merged domain")
            return 999
        }, systemValue: { 180 })
        #expect(value as? Int == 180)
    }

    @Test("A missing managed value falls back to the system value")
    func missingManagedValue() {
        #expect(resolvePreferenceValue(isManaged: true, managedValue: { nil }, systemValue: { 180 }) as? Int == 180)
    }

    @Test("An absent value preserves the caller's default")
    func missingValue() {
        let value = resolvePreferenceValue(isManaged: false, managedValue: { nil }, systemValue: { nil })
        #expect(value == nil)
        #expect(boolPreference(value, defaultValue: defaultWaitForNetwork) == false)
    }

    @Test("A managed false overrides a local true")
    func managedFalse() {
        let value = resolvePreferenceValue(isManaged: true, managedValue: { false }, systemValue: { true })
        #expect(boolPreference(value, defaultValue: true) == false)
    }
}

@Suite("Local preference persistence")
struct LocalPreferencePersistenceTests {
    @Test("Managed values are not persisted over existing local values")
    func profileRemovalRevealsLocalValue() {
        var local: [String: Any] = ["network_timeout": 180]
        var effective = OutsetPreferences()
        effective.networkTimeout = 600
        effective.waitForNetwork = true
        let values = localPreferenceValues(prefs: effective, isManaged: { $0 == "network_timeout" })
        for (key, value) in values { local[key] = value }
        #expect(local["network_timeout"] as? Int == 180)
        #expect(local["wait_for_network"] as? Bool == true)
    }

    @Test("A managed key without a local value stays absent")
    func managedKeyStaysAbsent() {
        let values = localPreferenceValues(prefs: OutsetPreferences(), isManaged: { $0 == "network_timeout" })
        #expect(values["network_timeout"] == nil)
        #expect(values["background_script_timeout"] as? Int == 30)
        #expect(values["manifest_signing_key"] as? String == "")
    }
}
