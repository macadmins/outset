//
//  Utils.swift
//  outset
//
//  Created by Bart Reardon on 3/12/2022.
//

import Foundation

func ensureWorkingFolders() {
    // Ensures working folders are all present and creates them if necessary
    let workingDirectories = [
        PayloadType.bootEvery.directoryPath,
        PayloadType.bootOnce.directoryPath,
        PayloadType.loginWindow.directoryPath,
        PayloadType.loginEvery.directoryPath,
        PayloadType.loginOnce.directoryPath,
        PayloadType.loginPrivilegedEvery.directoryPath,
        PayloadType.loginPrivilegedOnce.directoryPath,
        PayloadType.onDemand.directoryPath,
        PayloadType.onDemandPrivileged.directoryPath,
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
        if ownerID == 0 && mode == FilePermissions.file.asNSNumber {
            return true
        } else {
            writeLog("\(errorMessage) x644", logLevel: .error)
        }
    } else {
        if ownerID == 0 && mode == FilePermissions.executable.asNSNumber {
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

func pathCleanup(_ pathname: String) {
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

func createTrigger(_ path: String) {
    FileManager.default.createFile(atPath: path, contents: nil)
}
