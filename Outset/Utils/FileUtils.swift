//
//  Utils.swift
//  outset
//
//  Created by Bart Reardon on 3/12/2022.
//

import Foundation

func installPackage(pkg: String) -> Bool {
    // Installs pkg onto boot drive
    if isRoot() {
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

func ensureWorkingFolders() {
    // Ensures working folders are all present and creates them if necessary
    let workingDirectories = [
        bootEveryDir,
        bootOnceDir,
        loginWindowDir,
        loginEveryDir,
        loginOnceDir,
        loginEveryPrivilegedDir,
        loginOncePrivilegedDir,
        onDemandDir,
        logDirectory
    ]

    for directory in workingDirectories where !checkDirectoryExists(path: directory) {
        writeLog("\(directory) does not exist, creating now.", logLevel: .debug)
        do {
            try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        } catch {
            writeLog("could not create path at \(directory)", logLevel: .error)
        }
    }
}

func checkFileExists(path: String) -> Bool {
    return FileManager.default.fileExists(atPath: path)
}

func checkDirectoryExists(path: String) -> Bool {
    var isDirectory: ObjCBool = false
    _ = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
    return isDirectory.boolValue
}

func folderContents(path: String) -> [String] {
    // Returns a array of strings containing the folder contents
    // Does not perform a recursive list
    var filelist: [String] = []
    do {
        let files = try FileManager.default.contentsOfDirectory(atPath: path)
        let sortedFiles = files.sorted()
        for file in sortedFiles {
            filelist.append("\(path)/\(file)")
        }
    } catch {
        return []
    }
    return filelist
}

func verifyPermissions(pathname: String) -> Bool {
    // Files should be owned by root
    // Files that are not scripts should have permissions 644 (-rw-r--r--)
    // Files that are scripts should have permissions 755 (-rwxr-xr-x)
    // If the permission for the request file is not correct then return fals to indicate it should not be processed

    let (ownerID, mode) = getFileProperties(pathname: pathname)
    let posixPermissions = String(mode.intValue, radix: 8, uppercase: false)
    let errorMessage = "Permissions for \(pathname) are incorrect. Should be owned by root and with mode"

    writeLog("ownerID for \(pathname) : \(String(describing: ownerID))", logLevel: .debug)
    writeLog("posixPermissions for \(pathname) : \(String(describing: posixPermissions))", logLevel: .debug)

    if ["pkg", "mpkg", "dmg", "mobileconfig"].contains(pathname.lowercased().split(separator: ".").last) {
        if ownerID == 0 && mode == requiredFilePermissions {
            return true
        } else {
            writeLog("\(errorMessage) x644", logLevel: .error)
        }
    } else {
        if ownerID == 0 && mode == requiredExecutablePermissions {
            return true
        } else {
            writeLog("\(errorMessage) x755", logLevel: .error)
        }
    }
    return false
}

func getFileProperties(pathname: String) -> (ownerID: Int, permissions: NSNumber) {
    // returns the ID and permissions of the specified file
    var fileAttributes: [FileAttributeKey: Any]
    var ownerID: Int = 0
    var mode: NSNumber = 0
    do {
        fileAttributes = try FileManager.default.attributesOfItem(atPath: pathname)
        if let ownerProperty = fileAttributes[.ownerAccountID] as? Int {
            ownerID = ownerProperty
        }
        if let modeProperty = fileAttributes[.posixPermissions] as? NSNumber {
            mode = modeProperty
        }
    } catch {
        writeLog("Could not read file at path \(pathname)", logLevel: .error)
    }
    return (ownerID, mode)
}

func pathCleanup(pathname: String) {
    // check if folder and clean all files in that folder
    // Deletes given script or cleans folder
    writeLog("Cleaning up \(pathname)", logLevel: .debug)
    if checkDirectoryExists(path: pathname) {
        for fileItem in folderContents(path: pathname) {
            writeLog("Cleaning up \(fileItem)", logLevel: .debug)
            deletePath(fileItem)
        }
    } else if checkFileExists(path: pathname) {
        writeLog("\(pathname) exists", logLevel: .debug)
        deletePath(pathname)
    } else {
        writeLog("\(pathname) doesn't seem to exist", logLevel: .error)
    }
}

func deletePath(_ path: String) {
    // Deletes the specified file
    writeLog("Deleting \(path)", logLevel: .debug)
    do {
        try FileManager.default.removeItem(atPath: path)
        writeLog("\(path) deleted", logLevel: .debug)
    } catch {
        writeLog("\(path) could not be removed", logLevel: .error)
    }
}

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

func performLogRotation(logFolderPath: String, logFileBaseName: String, maxLogFiles: Int = 30) {
    let fileManager = FileManager.default
    let currentDay = Calendar.current.component(.day, from: Date())

    // Check if the day has changed
    let newestLogFile = logFolderPath + "/" + logFileBaseName
    if fileManager.fileExists(atPath: newestLogFile) {
        let fileCreationDate = try? fileManager.attributesOfItem(atPath: newestLogFile)[.creationDate] as? Date
        if let creationDate = fileCreationDate {
            let dayOfCreation = Calendar.current.component(.day, from: creationDate)
            if dayOfCreation != currentDay {
                // rotate files
                for archivedLogFile in (1...maxLogFiles).reversed() {
                    let sourcePath = logFolderPath + "/" + (archivedLogFile == 1 ? logFileBaseName : "\(logFileBaseName).\(archivedLogFile-1)")
                    let destinationPath = logFolderPath + "/" + "\(logFileBaseName).\(archivedLogFile)"

                    if fileManager.fileExists(atPath: sourcePath) {
                        if archivedLogFile == maxLogFiles {
                            // Delete the oldest log file if it exists
                            try? fileManager.removeItem(atPath: sourcePath)
                        } else {
                            // Move the log file to the next number in the rotation
                            try? fileManager.moveItem(atPath: sourcePath, toPath: destinationPath)
                        }
                    }
                }
                writeLog("Logrotate complete", logLevel: .debug)
            }
        }
    }
}
