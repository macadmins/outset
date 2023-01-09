//
//  Main.swift
//  Outset
//
//  Created by Bart Reardon on 10/12/2022.
//

import Foundation
import ServiceManagement


func main() {
    init_daemons()
    //∫exit(0)
}

func init_daemons() {
    // The identifier must match the CFBundleIdentifier string in Info.plist.

    if #available(macOS 13.0, *) {
        // LaunchDaemon path: $APP.app/Contents/Library/LaunchDaemons/com.example.daemon.plist
        let boot_daemon = SMAppService.daemon(plistName: "com.github.outset.boot.plist");
        let login_privileged_daemon = SMAppService.daemon(plistName: "com.github.outset.login-privileged.plist");
        let cleanup_daemon = SMAppService.daemon(plistName: "com.github.outset.cleanup.plist");

        // LaunchAgent path: $APP.app/Contents/Library/LaunchAgents/com.example.agent.plist
        let login_agent = SMAppService.agent(plistName: "com.github.outset.login.plist");
        let on_demand_agent = SMAppService.agent(plistName: "com.github.outset.on-demand.plist");

        // Retrieving the app reference if the main app itself needs to launch instead of a helper.
        // let mainApp = SMAppService.mainApp
        
        do {
            try boot_daemon.register()
            try login_privileged_daemon.register()
            try cleanup_daemon.register()
        } catch {
            print("registering LaunchDaemons failed")
        }
        
        do {
            try login_agent.register()
            try on_demand_agent.register()
        } catch {
            print("registering LaunchAgents failed")
        }
        
    } else {
        // Fallback on earlier versions
        // copy agents and daemons over
        print("Earlier verions of macOS do things the ye olde way")
    }

    
}
