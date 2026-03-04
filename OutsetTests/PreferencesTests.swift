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
