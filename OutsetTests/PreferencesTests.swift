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
