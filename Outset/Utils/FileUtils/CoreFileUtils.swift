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
    return getFolderContents(path: path)
}

func folderContents(type: PayloadType) -> [String] {
    // Returns a array of strings containing the folder contents
    // Does not perform a recursive list
    let path = type.directoryPath
    return getFolderContents(path: path)
}

func getFolderContents(path: String) -> [String] {
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

func verifyPermissions(pathname: String, trustedOwners: Set<uid_t> = [0]) -> Bool {
    // An item runs only when no account other than root could have changed it:
    // - it is a regular file, never a symlink, so a root-owned link cannot point elsewhere
    // - it is owned by root, mode 644 for packages and profiles, 755 for scripts
    // - every directory above it is root-owned and writable by no group or other,
    //   to reject replacement paths writable through POSIX mode bits
    // trustedOwners exists for tests; outset itself always trusts root only.

    var info = stat()
    guard lstat(pathname, &info) == 0 else {
        writeLog("Could not read file at path \(pathname)", logLevel: .error)
        return false
    }

    guard info.st_mode & S_IFMT == S_IFREG else {
        writeLog("\(pathname) is not a regular file. Symlinks and folders are not run", logLevel: .error)
        return false
    }

    let isPackage = ["pkg", "mpkg", "dmg", "mobileconfig"].contains(pathname.lowercased().split(separator: ".").last)
    let required = isPackage ? FilePermissions.file : FilePermissions.executable
    let mode = info.st_mode & 0o7777

    writeLog("ownerID for \(pathname) : \(info.st_uid)", logLevel: .debug)
    writeLog("posixPermissions for \(pathname) : \(String(mode, radix: 8))", logLevel: .debug)

    guard trustedOwners.contains(info.st_uid), mode == required.rawValue.uint16Value else {
        writeLog("Permissions for \(pathname) are incorrect. Should be owned by root and with mode x\(String(required.rawValue.intValue, radix: 8))", logLevel: .error)
        return false
    }

    return verifyParentChain(of: pathname, trustedOwners: trustedOwners)
}

func verifyParentChain(of pathname: String, trustedOwners: Set<uid_t> = [0]) -> Bool {
    // Resolves the item's folder one component at a time, the way the kernel will when
    // outset runs it, and checks every folder the lookup passes through, including the
    // folders that hold each symlink hop. Each folder must be owned by a trusted owner and
    // not writable by group or other, so no other account can redirect the lookup.
    let parent = (pathname as NSString).deletingLastPathComponent
    guard parent.hasPrefix("/") else {
        writeLog("\(pathname) is not an absolute path", logLevel: .error)
        return false
    }

    func folderIsLocked(_ path: String) -> Bool {
        var info = stat()
        guard lstat(path, &info) == 0, info.st_mode & S_IFMT == S_IFDIR else {
            writeLog("\(path) above \(pathname) is not a readable folder. Skipping", logLevel: .error)
            return false
        }
        guard trustedOwners.contains(info.st_uid), info.st_mode & (S_IWGRP | S_IWOTH) == 0 else {
            writeLog("Folder \(path) above \(pathname) must be owned by root and writable only by root. Skipping", logLevel: .error)
            return false
        }
        return true
    }

    guard folderIsLocked("/") else { return false }
    var current = "/"
    var remaining = Array(parent.split(separator: "/").map(String.init).reversed())
    var hops = 0

    while let component = remaining.popLast() {
        switch component {
        case ".":
            continue
        case "..":
            current = (current as NSString).deletingLastPathComponent
            continue
        default:
            break
        }

        let next = (current as NSString).appendingPathComponent(component)
        var info = stat()
        guard lstat(next, &info) == 0 else {
            writeLog("Could not read \(next) above \(pathname)", logLevel: .error)
            return false
        }

        if info.st_mode & S_IFMT == S_IFLNK {
            // The link sits in `current`, which is already verified, so only root can change it.
            hops += 1
            guard hops <= 32, trustedOwners.contains(info.st_uid),
                  let target = try? FileManager.default.destinationOfSymbolicLink(atPath: next) else {
                writeLog("Could not follow \(next) above \(pathname). Skipping", logLevel: .error)
                return false
            }
            if target.hasPrefix("/") { current = "/" }
            remaining.append(contentsOf: target.split(separator: "/").map(String.init).reversed())
            continue
        }

        guard folderIsLocked(next) else { return false }
        current = next
    }
    return true
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
