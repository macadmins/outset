//
//  Services.swift
//  Outset
//
//  Created by Bart Reardon on 21/3/2023.
//
// swiftlint:disable line_length

import Foundation
import ServiceManagement

@available(macOS 13.0, *)
class ServiceManager {

    // The identifier must match the CFBundleIdentifier string in Info.plist.
    // LaunchDaemon path: $APP.app/Contents/Library/LaunchDaemons/
    let bootDaemon = SMAppService.daemon(plistName: "io.macadmins.Outset.boot.plist")
    let loginPrivilegedDaemon = SMAppService.daemon(plistName: "io.macadmins.Outset.login-privileged.plist")
    let cleanupDaemon = SMAppService.daemon(plistName: "io.macadmins.Outset.cleanup.plist")

    // LaunchAgent path: $APP.app/Contents/Library/LaunchAgents/
    let loginAgent = SMAppService.agent(plistName: "io.macadmins.Outset.login.plist")
    let onDemandAgent = SMAppService.agent(plistName: "io.macadmins.Outset.on-demand.plist")
    let loginWindowAgent = SMAppService.agent(plistName: "io.macadmins.Outset.login-window.plist")

    func servicesEnabled() -> Bool {
        return SMAppService.mainApp.status == .enabled
    }

    func disableAppService() {
        try? SMAppService.mainApp.unregister()
    }

    func enableAppService() {
        try? SMAppService.mainApp.register()
    }

    private func register(_ service: SMAppService) {
        if !isRoot() {
            writeLog("Must be root to register \(service.description)",
                     logLevel: .error)
            return
        }
        if service.status == .enabled {
            writeLog("\(service.description) status: \(statusToString(service))",
                     logLevel: .info)
        } else {
            do {
                try service.register()
            } catch let error {
                if error.localizedDescription.contains("Operation not permitted") {
                    writeLog("\(service.description): \(error.localizedDescription). Login item requires approval", logLevel: .error)
                } else if !error.localizedDescription.contains("Service cannot load in requested session") {
                    writeLog("\(service.description): \(error.localizedDescription)", logLevel: .error)
                }
            }
        }
    }

    private func unregister(_ service: SMAppService) {
        if !isRoot() {
            writeLog("Must be root to unregister \(service.description)",
                     logLevel: .error)
            return
        }
        if service.status == .enabled {
            do {
                try service.unregister()
            } catch let error {
                writeLog("\(service.description): \(error.localizedDescription)", logLevel: .error)
            }
        } else {
            writeLog("\(service.description) status: \(statusToString(service))",
                     logLevel: .info)
        }
    }

    private func statusToString(_ service: SMAppService) -> String {
        switch service.status {
        case .notRegistered:
            return "Not Registered"
        case .enabled:
            return "Enabled"
        case .requiresApproval:
            return "Requires Approval"
        case .notFound:
            return "Not Found"
        default:
            return "Unknown status"
        }
    }

    private func status(_ service: SMAppService) {
        writeLog("\(service.description) status: \(statusToString(service))", logLevel: .info)
    }

    func registerDaemons() {
        writeLog("registering Services", logLevel: .debug)
        register(bootDaemon)
        register(loginPrivilegedDaemon)
        register(cleanupDaemon)
        register(loginAgent)
        register(onDemandAgent)
        // Disabled for the time being until ServiceManagement and loginwindow agent issues are resolved
        // register(loginWindowAgent)
    }

    func removeDaemons() {
        writeLog("de-registering Services", logLevel: .debug)
        unregister(bootDaemon)
        unregister(loginPrivilegedDaemon)
        unregister(cleanupDaemon)
        unregister(loginAgent)
        unregister(onDemandAgent)
        // Disabled for the time being until ServiceManagement and loginwindow agent issues are resolved
        // unregister(loginWindowAgent)
    }

    func getStatus() {
        writeLog("getting Services status", logLevel: .info)
        status(bootDaemon)
        status(loginPrivilegedDaemon)
        status(cleanupDaemon)
        status(loginAgent)
        status(onDemandAgent)
        status(loginWindowAgent)
    }
}

// swiftlint:enable line_length
