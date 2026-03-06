//
//  LoginTests.swift
//  OutsetTests
//

import Testing
import Foundation

@Suite("runIfNotIgnoredUser")
struct RunIfNotIgnoredUserTests {

    @Test("Runs action when user is not in ignored list")
    func runsActionForNonIgnoredUser() {
        var prefs = OutsetPreferences()
        prefs.ignoredUsers = ["ignoreduser"]
        var actionRan = false

        let result = runIfNotIgnoredUser(consoleUser: "normaluser", prefs: prefs) {
            actionRan = true
        }

        #expect(result == true)
        #expect(actionRan == true)
    }

    @Test("Skips action when user is in ignored list")
    func skipsActionForIgnoredUser() {
        var prefs = OutsetPreferences()
        prefs.ignoredUsers = ["ignoreduser"]
        var actionRan = false

        let result = runIfNotIgnoredUser(consoleUser: "ignoreduser", prefs: prefs) {
            actionRan = true
        }

        #expect(result == false)
        #expect(actionRan == false)
    }

    @Test("Runs action when ignored list is empty")
    func runsActionWithEmptyIgnoredList() {
        let prefs = OutsetPreferences()
        var actionRan = false

        let result = runIfNotIgnoredUser(consoleUser: "anyuser", prefs: prefs) {
            actionRan = true
        }

        #expect(result == true)
        #expect(actionRan == true)
    }

    @Test("Handles multiple users in ignored list")
    func handlesMultipleIgnoredUsers() {
        var prefs = OutsetPreferences()
        prefs.ignoredUsers = ["user1", "user2", "user3"]

        var ranForUser2 = false
        let result = runIfNotIgnoredUser(consoleUser: "user2", prefs: prefs) {
            ranForUser2 = true
        }

        #expect(result == false)
        #expect(ranForUser2 == false)

        var ranForUser4 = false
        let result2 = runIfNotIgnoredUser(consoleUser: "user4", prefs: prefs) {
            ranForUser4 = true
        }

        #expect(result2 == true)
        #expect(ranForUser4 == true)
    }
}
