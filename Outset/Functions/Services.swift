//
//  Services.swift
//  Outset
//
//  Created by Bart Reardon on 21/3/2023.
//

import Foundation
import ServiceManagement

@available(macOS 13.0, *)
class ServiceManager {

    // The identifier must match the CFBundleIdentifier string in Info.plist.
    // LaunchDaemon path: $APP.app/Contents/Library/LaunchDaemons/
    let bootDaemon = SMAppService.daemon(plistName: "io.macadmins.outset.boot.plist")
    let loginPrivilegedDaemon = SMAppService.daemon(plistName: "io.macadmins.outset.login-privileged.plist")
    let cleanupDaemon = SMAppService.daemon(plistName: "io.macadmins.outset.cleanup.plist")

    // LaunchAgent path: $APP.app/Contents/Library/LaunchAgents/
    let loginAgent = SMAppService.agent(plistName: "io.macadmins.outset.login.plist")
    let onDemandAgent = SMAppService.agent(plistName: "io.macadmins.outset.on-demand.plist")
    let loginWindowAgent = SMAppService.agent(plistName: "io.macadmins.outset.login-window.plist")

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
        // if service.status == .notRegistered {
            do {
                try service.register()
            } catch let error {
                writeLog("Registering service \(service.description) failed", logLevel: .error)
                writeLog(error.localizedDescription, logLevel: .error)
            }
        // }
    }

    private func deregister(_ service: SMAppService) {
        // if service.status != .notRegistered {
            do {
                try service.unregister()
            } catch let error {
                writeLog("Disabling service \(service.description) failed", logLevel: .error)
                writeLog(error.localizedDescription, logLevel: .error)
            }
        // }
    }

    private func statusToString(_ service: SMAppService) -> String {
        switch service.status {
        case .notRegistered:
            return "Not Registered"
        case .enabled:
            return "Enabled"
        case .requiresApproval:
            return "Required Approval"
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
        register(loginWindowAgent)
    }

    func removeDaemons() {
        writeLog("de-registering Services", logLevel: .debug)
        deregister(bootDaemon)
        deregister(loginPrivilegedDaemon)
        deregister(cleanupDaemon)
        deregister(loginAgent)
        deregister(onDemandAgent)
        deregister(loginWindowAgent)
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
