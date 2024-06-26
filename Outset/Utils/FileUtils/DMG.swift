//
//  DMG.swift
//  Outset
//
//  Created by Bart E Reardon on 26/6/2024.
//

import Foundation

func mountDmg(dmg: String) -> String {
    // Attaches dmg and returns the path
    let cmd = "/usr/bin/hdiutil attach -nobrowse -noverify -noautoopen \(dmg)"
    writeLog("Attaching \(dmg)", logLevel: .debug)
    let (output, error, status) = runShellCommand(cmd)
    if status != 0 {
        writeLog("Failed attaching \(dmg) with error \(error)", logLevel: .error)
        return error
    }
    return output.trimmingCharacters(in: .whitespacesAndNewlines)
}

func detachDmg(dmgMount: String) -> String {
    // Detaches dmg
    writeLog("Detaching \(dmgMount)", logLevel: .debug)
    let cmd = "/usr/bin/hdiutil detach -force \(dmgMount)"
    let (output, error, status) = runShellCommand(cmd)
    if status != 0 {
        writeLog("Failed detaching \(dmgMount) with error \(error)", logLevel: .error)
        return error
    }
    return output.trimmingCharacters(in: .whitespacesAndNewlines)
}
