//
//  main.swift
//  outset
//
//  Created by Bart Reardon on 1/12/2022.
//
// swift implementation of outset by Joseph Chilcote https://github.com/chilcote/outset
//

import Foundation
import ArgumentParser
import OSLog

// Logic insertion point
@main
struct Outset: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "outset",
        abstract: "Outset is a utility that automatically processes scripts and/or packages at boot, on demand, or login.")

    @Flag(help: .hidden)
    var debug = false

    @Flag(help: "Used by launchd for scheduled runs at boot")
    var boot = false

    @Flag(help: "Used by launchd for scheduled runs at login")
    var login = false

    @Flag(help: "Used by launchd for scheduled runs at the login window")
    var loginWindow = false

    @Flag(help: "Used by launchd for scheduled privileged runs at login")
    var loginPrivileged = false

    @Flag(help: "Process scripts on demand")
    var onDemand = false

    @Flag(help: "Process scripts on demand with elevated privileges")
    var onDemandPrivileged = false

    @Flag(help: "Manually process scripts in login-every")
    var loginEvery = false

    @Flag(help: "Manually process scripts in login-once")
    var loginOnce = false

    @Flag(help: "Used by launchd to clean up on-demand dir")
    var cleanup = false

    @Option(help: ArgumentHelp("Add one or more users to ignored list", valueName: "username"))
    var addIgnoredUser: [String] = []

    @Option(help: ArgumentHelp("Remove one or more users from ignored list", valueName: "username"))
    var removeIgnoredUser: [String] = []

    @Option(help: ArgumentHelp("Add one or more scripts to override list", valueName: "script"), completion: .file())
    var addOverride: [String] = []

    // maintaining misspelt option as hidden
    @Option(help: .hidden, completion: .file())
    var addOveride: [String] = []

    @Option(help: ArgumentHelp("Remove one or more scripts from override list", valueName: "script"), completion: .file())
    var removeOverride: [String] = []

    // maintaining misspelt option as hidden
    @Option(help: .hidden, completion: .file())
    var removeOveride: [String] = []

    // removed from view in favour for checksum. retained to support backward compatability
    @Option(help: .hidden, completion: .file())
    var computeSHA: [String] = []

    @Option(help: ArgumentHelp("Compute the checksum (SHA256) hash of the given file. Use the keyword 'all' to compute all values and generate a formatted configuration plist", valueName: "file"), completion: .file())
    var checksum: [String] = []

    @Flag(help: .hidden)
    var shasumReport = false

    @Flag(help: .hidden)
    var checksumReport = false

    @Flag(help: .hidden)
    var enableServices = false

    @Flag(help: .hidden)
    var disableServices = false

    @Flag(help: .hidden)
    var serviceStatus = false

    @Flag(help: "Show version number")
    var version = false

    @Flag(help: "Generate a new Ed25519 signing keypair for script signature verification")
    var generateKeypair = false

    @Option(help: ArgumentHelp("Sign one or more script files with the given private key (base64). Embeds the signature as a '# ed25519: <sig>' comment.", valueName: "file"), completion: .file())
    var signScriptFile: [String] = []

    @Option(help: ArgumentHelp("Base64-encoded Ed25519 private key used with --sign-script-file", valueName: "key"))
    var signingKey: String = ""

    mutating func run() throws {

        if debug || UserDefaults.standard.bool(forKey: "verbose_logging") {
            debugMode = true
        }

        let consoleUser = getConsoleUserInfo().username

        if version {
            printStdOut("\(outsetVersion)")
            if debugMode {
                writeSysReport()
            }
        }

        // Service management
        if enableServices, #available(macOS 13.0, *) {
            let manager = ServiceManager()
            manager.registerDaemons()
        }

        if disableServices, #available(macOS 13.0, *) {
            let manager = ServiceManager()
            manager.removeDaemons()
        }

        if serviceStatus, #available(macOS 13.0, *) {
            let manager = ServiceManager()
            manager.getStatus()
        }
        
        // Combine arrays where names were changed (legacy)
        addOveride += addOverride
        removeOveride += removeOverride
        checksum += computeSHA
        
        // Shorthand instead of a block of if statements using runIf()
        runIf(boot) { processBootTasks(prefs: prefs) }
        runIf(loginWindow) { processLoginWindowTasks(payload: scriptPayloads) }
        runIf(login) { processLoginTasks(consoleUser: consoleUser, payload: scriptPayloads, prefs: prefs) }
        runIf(loginPrivileged) { processLoginPrivilegedTasks(consoleUser: consoleUser, payload: scriptPayloads, prefs: prefs) }
        runIf(loginEvery) { processLoginEveryTasks(consoleUser: consoleUser, payload: scriptPayloads, prefs: prefs) }
        runIf(loginOnce) { processLoginOnceTasks(consoleUser: consoleUser, payload: scriptPayloads, prefs: prefs) }
        runIf(onDemand) { processOnDemandTasks(consoleUser: consoleUser) }
        runIf(onDemandPrivileged) { processOnDemandPrivilegedTasks(consoleUser: consoleUser) }
        runIf(addIgnoredUser.count > 0) { addIgnoredUsers(addIgnoredUser, prefs: &prefs) }
        runIf(removeIgnoredUser.count > 0) { removeIgnoredUsers(removeIgnoredUser, prefs: &prefs) }
        runIf(addOveride.count > 0) { runAddOveride(addOveride, prefs: &prefs) }
        runIf(removeOveride.count > 0) { runRemoveOveride(removeOveride, prefs: &prefs) }
        runIf(checksum.count > 0) { computeChecksum(checksum) }
        runIf(shasumReport || checksumReport) { printChecksumReport() }
        runIf(cleanup) { runCleanup() }
        runIf(generateKeypair) { generateSigningKeypair() }
        if signScriptFile.count > 0 {
            guard !signingKey.isEmpty else {
                printStdErr("--sign-script-file requires --signing-key <private-key-base64>")
                throw ExitCode.failure
            }
            for path in signScriptFile {
                if !signScript(path: path, privateKeyBase64: signingKey) {
                    throw ExitCode.failure
                }
            }
        }
    }
}
