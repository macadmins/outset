//
//  Packages.swift
//  Outset
//
//  Created by Bart E Reardon on 26/6/2024.
//

import Foundation

func installPackage(pkg: String) -> Bool {
    // Installs pkg onto boot drive
    if isRoot {
        var pkgsToInstall: [String] = []
        var dmgMount: String = ""

        if pkg.lowercased().hasSuffix("dmg") {
            dmgMount = mountDmg(dmg: pkg)
            for file in folderContents(path: dmgMount) where ["pkg", "mpkg"].contains(file.lowercased().suffix(3)) {
                pkgsToInstall.append(file)
            }
        } else if ["pkg", "mpkg"].contains(pkg.lowercased().suffix(3)) {
            pkgsToInstall.append(pkg)
        }

        for pkgToInstall in pkgsToInstall {
            writeLog("Installing \(pkgToInstall)")
            let cmd = "/usr/sbin/installer -pkg \(pkgToInstall) -target /"
            let (output, error, status) = runShellCommand(cmd, verbose: true)
            if status != 0 {
                writeLog(error, logLevel: .error)
            } else {
                writeLog(output)
            }
        }

        if !dmgMount.isEmpty {
            writeLog(detachDmg(dmgMount: dmgMount))
        }

        return true
    } else {
        writeLog("Unable to process \(pkg)", logLevel: .error)
        writeLog("Must be root to install packages", logLevel: .error)
    }
    return false
}
