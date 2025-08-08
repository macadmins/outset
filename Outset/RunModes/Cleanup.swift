//
//  Cleanup.swift
//  Outset
//
//  Created by Bart Reardon on 6/8/2025.
//

import Foundation

func runCleanup() {
    writeLog("Cleaning up on-demand directories.", logLevel: .info)
    pathCleanup(Trigger.onDemand.path)
    pathCleanup(Trigger.onDemandPrivileged.path)
    pathCleanup(PayloadType.onDemand.directoryPath)
    pathCleanup(PayloadType.onDemandPrivileged.directoryPath)
    pathCleanup(Trigger.cleanup.path)
}
