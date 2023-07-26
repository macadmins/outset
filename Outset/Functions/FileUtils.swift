//
//  Utils.swift
//  outset
//
//  Created by Bart Reardon on 3/12/2022.
//
// swiftlint:disable large_tuple line_length force_cast file_length cyclomatic_complexity function_body_length

import Foundation
import CommonCrypto

func runShellCommand(_ command: String, args: [String] = [], verbose: Bool = false) -> (output: String, error: String, exitCode: Int32) {
    // runs a shell command passed as an argument
    // If the verbose parameter is set to true, will log the command being run and its status when completed.
    // returns the output, error and exit code as a tuple.

    if verbose {
        writeLog("Running task \(command)", logLevel: .debug)
    }
    let task = Process()
    let pipe = Pipe()
    let errorpipe = Pipe()

    var cmd = command
    for arg in args {
        cmd += " '\(arg)'"
    }
    let arguments = ["-c", cmd]

    var output: String = ""
    var error: String = ""

    task.launchPath = "/bin/sh"
    task.arguments = arguments
    task.standardOutput = pipe
    task.standardError = errorpipe
    task.launch()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let errordata = errorpipe.fileHandleForReading.readDataToEndOfFile()

    output.append(String(data: data, encoding: .utf8)!)
    error.append(String(data: errordata, encoding: .utf8)!)

    task.waitUntilExit()
    let status = task.terminationStatus
    if verbose {
        writeLog("Completed task \(command) with status \(status)", logLevel: .debug)
        writeLog("Task output: \n\(output)", logLevel: .debug)
    }
    return (output, error, status)
}

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

func migrateLegacyPreferences() {
    let newoldRootUserDefaults = "/var/root/Library/Preferences/io.macadmins.Outset.plist"
    // shared folder should not contain any executable content, iterate and update as required
    if checkFileExists(path: shareDirectory) || checkFileExists(path: newoldRootUserDefaults) {
        writeLog("Legacy preferences exist. Migrating to user defaults", logLevel: .debug)

        let legacyOutsetPreferencesFile = "\(shareDirectory)com.chilcote.outset.plist"
        let legacyRootRunOncePlistFile = "com.github.outset.once.\(getConsoleUserInfo().userID).plist"
        let userHomeDirectory = FileManager.default.homeDirectoryForCurrentUser
        let userHomePath = userHomeDirectory.relativeString.replacingOccurrences(of: "file://", with: "")
        let legacyUserRunOncePlistFile = userHomePath+"Library/Preferences/com.github.outset.once.plist"

        var shareFiles: [String] = []
        shareFiles.append(legacyOutsetPreferencesFile)
        shareFiles.append(legacyRootRunOncePlistFile)
        shareFiles.append(legacyUserRunOncePlistFile)
        shareFiles.append(newoldRootUserDefaults)

        for filename in shareFiles where checkFileExists(path: filename) {

            let url = URL(fileURLWithPath: filename)
            do {
                let data = try Data(contentsOf: url)
                switch filename {

                case newoldRootUserDefaults:
                    if isRoot() {
                        writeLog("\(newoldRootUserDefaults) migration", logLevel: .debug)
                        let legacyDefaultKeys = CFPreferencesCopyKeyList(Bundle.main.bundleIdentifier! as CFString, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
                        for key in legacyDefaultKeys as! [CFString] {
                            let keyValue = CFPreferencesCopyValue(key, Bundle.main.bundleIdentifier! as CFString, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
                            CFPreferencesSetValue(key as CFString,
                                                  keyValue as CFPropertyList,
                                                  Bundle.main.bundleIdentifier! as CFString,
                                                  kCFPreferencesAnyUser,
                                                  kCFPreferencesAnyHost)
                        }
                        deletePath(newoldRootUserDefaults)
                    }
                case legacyOutsetPreferencesFile:
                    writeLog("\(legacyOutsetPreferencesFile) migration", logLevel: .debug)
                    do {
                        let legacyPreferences = try PropertyListDecoder().decode(OutsetPreferences.self, from: data)
                        writePreferences(prefs: legacyPreferences)
                        writeLog("Migrated Legacy Outset Preferences", logLevel: .debug)
                        deletePath(legacyOutsetPreferencesFile)
                    } catch {
                        writeLog("legacy Preferences migration failed", logLevel: .error)
                    }

                case legacyRootRunOncePlistFile, legacyUserRunOncePlistFile:
                    writeLog("\(legacyRootRunOncePlistFile) and \(legacyUserRunOncePlistFile) migration", logLevel: .debug)
                    do {
                        let legacyRunOncePlistData = try PropertyListDecoder().decode([String: Date].self, from: data)
                        writeRunOnce(runOnceData: legacyRunOncePlistData)
                        writeLog("Migrated Legacy Runonce Data", logLevel: .debug)
                        if isRoot() {
                            deletePath(legacyRootRunOncePlistFile)
                        } else {
                            deletePath(legacyUserRunOncePlistFile)
                        }
                    } catch {
                        writeLog("legacy Run Once Plist migration failed", logLevel: .error)
                    }

                default:
                    continue
                }
            } catch {
                writeLog("could not load \(filename)", logLevel: .error)
            }

        }

        if checkFileExists(path: shareDirectory) && folderContents(path: shareDirectory).isEmpty {
            deletePath(shareDirectory)
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

func verifySHASUMForFile(filename: String, shasumArray: [String: String]) -> Bool {
    // Verify that the file
    var proceed = false
        let errorMessage = "no required hash or file hash mismatch for: \(filename). Skipping"
        writeLog("checking hash for \(filename)", logLevel: .debug)
        let url = URL(fileURLWithPath: filename)
        if let fileHash = sha256(for: url) {
            writeLog("file hash : \(fileHash)", logLevel: .debug)
            if let storedHash = getValueForKey(filename, inArray: shasumArray) {
                writeLog("required hash : \(storedHash)", logLevel: .debug)
                if storedHash == fileHash {
                    proceed = true
                }
            }
        }
        if !proceed {
            writeLog(errorMessage, logLevel: .error)
        }

        return proceed
}

func sha256(for url: URL) -> String? {
    // computes a sha256sum for the specified file path and returns a string
    do {
        let fileData = try Data(contentsOf: url)
        let sha256 = fileData.sha256()
        return sha256.hexEncodedString()
    } catch {
        return nil
    }
}

func checksumAllFiles() {
    // compute checksum (SHA256) for all files in the outset directory
    // returns data in two formats to stdout:
    //   plaintext
    //   as plist format ready for import into an MDM or converting to a .mobileconfig

    let url = URL(fileURLWithPath: outsetDirectory)
    writeLog("CHECKSUM", logLevel: .info)
    var shasumPlist = FileHashes()
    if let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) {
        for case let fileURL as URL in enumerator {
            do {
                let fileAttributes = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
                if fileAttributes.isRegularFile! && fileURL.pathExtension != "plist" && fileURL.lastPathComponent != "outset" {
                    if let shasum = sha256(for: fileURL) {
                        print("\(fileURL.relativePath) : \(shasum)")
                        shasumPlist.sha256sum[fileURL.relativePath] = shasum
                    }
                }
            } catch { print(error, fileURL) }
        }

        writeLog("PLIST", logLevel: .info)
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        do {
            let data = try encoder.encode(shasumPlist)
            if let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] {
                let formatted = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
                if let string = String(data: formatted, encoding: .utf8) {
                    print(string)
                }
            }
        } catch {
            writeLog("plist encoding failed", logLevel: .error)
        }
    }
}

extension Data {
    // extension to the Data class that lets us compute sha256
    func sha256() -> Data {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        self.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(count), &hash)
        }
        return Data(hash)
    }

    func hexEncodedString() -> String {
        return map { String(format: "%02hhx", $0) }.joined()
    }
}

extension URL {
    var isDirectory: Bool {
       (try? resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
    }
}

// swiftlint:enable large_tuple line_length force_cast file_length cyclomatic_complexity function_body_length
