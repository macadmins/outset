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
        var pkgToInstall: String = ""
        var dmgMount: String = ""

        if pkg.lowercased().hasSuffix("dmg") {
            dmgMount = mountDmg(dmg: pkg)
            for files in folderContents(path: dmgMount) where ["pkg", "mpkg"].contains(files.lowercased().suffix(3)) {
                pkgToInstall = dmgMount
            }
        } else if ["pkg", "mpkg"].contains(pkg.lowercased().suffix(3)) {
            pkgToInstall = pkg
        }
        writeLog("Installing \(pkgToInstall)")
        let cmd = "/usr/sbin/installer -pkg \(pkgToInstall) -target /"
        let (output, error, status) = runShellCommand(cmd, verbose: true)
        if status != 0 {
            writeLog(error, logLevel: .error)
        } else {
            writeLog(output)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(5)) {
            if !dmgMount.isEmpty {
                writeLog(detachDmg(dmgMount: dmgMount))
            }
        }
        return true
    } else {
        writeLog("Unable to process \(pkg)", logLevel: .error)
        writeLog("Must be root to install packages", logLevel: .error)
    }
    return false
}
