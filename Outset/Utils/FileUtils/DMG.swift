//
//  DMG.swift
//  Outset
//
//  Created by Bart E Reardon on 26/6/2024.
//

import Foundation

func mountDmg(dmg: String) -> String {
    // Attaches dmg and returns the mount point, or an empty string on failure
    let cmd = "/usr/bin/hdiutil attach -nobrowse -noverify -noautoopen -plist"
    writeLog("Attaching \(dmg)", logLevel: .debug)
    let (output, error, status) = runShellCommand(cmd, args: [dmg])
    if status != 0 {
        writeLog("Failed attaching \(dmg) with error \(error)", logLevel: .error)
        return ""
    }
    let mountPoint = dmgMountPoint(fromHdiutilPlist: output)
    if mountPoint.isEmpty {
        writeLog("Could not determine mount point for \(dmg) from hdiutil output", logLevel: .error)
    }
    return mountPoint
}

func dmgMountPoint(fromHdiutilPlist plistOutput: String) -> String {
    // Parses the plist produced by `hdiutil attach -plist` and returns the
    // mount point of the first mounted system entity. Partitioned images list
    // multiple entities; only the mounted volume carries a mount-point key.
    guard let data = plistOutput.data(using: .utf8),
          let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
          let dict = plist as? [String: Any],
          let entities = dict["system-entities"] as? [[String: Any]] else {
        return ""
    }
    for entity in entities {
        if let mountPoint = entity["mount-point"] as? String {
            return mountPoint
        }
    }
    return ""
}

func detachDmg(dmgMount: String) -> String {
    // Detaches dmg
    writeLog("Detaching \(dmgMount)", logLevel: .debug)
    let cmd = "/usr/bin/hdiutil detach -force"
    let (output, error, status) = runShellCommand(cmd, args: [dmgMount])
    if status != 0 {
        writeLog("Failed detaching \(dmgMount) with error \(error)", logLevel: .error)
        return error
    }
    return output.trimmingCharacters(in: .whitespacesAndNewlines)
}
