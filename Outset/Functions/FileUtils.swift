//
//  Utils.swift
//  outset
//
//  Created by Bart Reardon on 3/12/2022.
//

import Foundation
import CommonCrypto

func runShellCommand(_ command: String, verbose : Bool = false) -> (output: String, error: String, exitCode: Int32) {
    // runs a shell command passed as an argument
    // If the verbose parameter is set to true, will log the command being run and its status when completed.
    // returns the output, error and exit code as a tuple.
    
    if verbose {
        writeLog("Running task \(command)", status: .debug)
    }
    let task = Process()
    let pipe = Pipe()
    let errorpipe = Pipe()
    
    var output: String = ""
    var error: String = ""

    task.standardOutput = pipe
    task.standardError = errorpipe
    task.arguments = ["-c", command]
    task.launchPath = "/bin/zsh"
    task.launch()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let errordata = errorpipe.fileHandleForReading.readDataToEndOfFile()

    output.append(String(data: data, encoding: .utf8)!)
    error.append(String(data: errordata, encoding: .utf8)!)

    task.waitUntilExit()
    let status = task.terminationStatus
    if verbose {
        writeLog("Completed task \(command) with status \(status)", status: .debug)
    }
    return (output, error, status)
}

func ensureWorkingFolders() {
    // Ensures working folders are all present and creates them if necessary
    let working_directories = [
        bootEveryDir,
        bootOnceDir,
        loginWindowDir,
        loginEveryDir,
        loginOnceDir,
        loginEveryPrivilegedDir,
        loginOncePrivilegedDir,
        onDemandDir
    ]

    for directory in working_directories {
        if !checkDirectoryExists(path: directory) {
            writeLog("\(directory) does not exist, creating now.", status: .debug)
            do {
                try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
            } catch {
                writeLog("could not create path at \(directory)", status: .error)
            }
        }
    }
}

func migrateLegacyPreferences() {
    // shared folder should not contain any executable content, iterate and update as required
    // TODO: could probably be optimised as there is duplication with ensure_working_folders()
    if checkDirectoryExists(path: shareDirectory) {
        writeLog("\(shareDirectory) exists. Migrating prefrences to user defaults", status: .debug)
        
        let legacyOutsetPreferencesFile = "\(shareDirectory)com.chilcote.outset.plist"
        let legacyRootRunOncePlistFile = "com.github.outset.once.\(getConsoleUserInfo().userID).plist"
        let userHomePath = FileManager.default.homeDirectoryForCurrentUser.relativeString.replacingOccurrences(of: "file://", with: "")
        let legacyUserRunOncePlistFile = userHomePath+"Library/Preferences/com.github.outset.once.plist"

        var share_files : [String] = []
        share_files.append(legacyOutsetPreferencesFile)
        share_files.append(legacyRootRunOncePlistFile)
        share_files.append(legacyUserRunOncePlistFile)
        
        for filename in share_files {
            if checkFileExists(path: filename) {
                let url = URL(fileURLWithPath: filename)
                do {
                    let data = try Data(contentsOf: url)
                    switch filename {
                        
                    case legacyOutsetPreferencesFile:
                        do {
                            let legacyPreferences = try PropertyListDecoder().decode(OutsetPreferences.self, from: data)
                            writePreferences(prefs: legacyPreferences)
                            writeLog("Migrated Legacy Outset Preferences", status: .debug)
                            deleteFile(legacyOutsetPreferencesFile)
                        } catch {
                            writeLog("legacy Preferences migration failed", status: .error)
                        }
                        
                    case legacyRootRunOncePlistFile, legacyUserRunOncePlistFile:
                        do {
                            let legacyRunOncePlistData = try PropertyListDecoder().decode([String:Date].self, from: data)
                            writeRunOnce(runOnceData: legacyRunOncePlistData)
                            writeLog("Migrated Legacy Runonce Data", status: .debug)
                            if isRoot() {
                                deleteFile(legacyRootRunOncePlistFile)
                            } else {
                                deleteFile(legacyUserRunOncePlistFile)
                            }
                        } catch {
                            writeLog("legacy Run Once Plist migration failed", status: .error)
                        }
                        
                    default:
                        continue
                    }
                } catch {
                    writeLog("could not load \(filename)", status: .error)
                }
            }
            
        }
        
        if folderContents(path: shareDirectory).isEmpty {
            do {
                try FileManager.default.removeItem(atPath: shareDirectory)
                writeLog("removed \(shareDirectory)", status: .debug)
            } catch {
                writeLog("could not remove \(shareDirectory)", status: .error)
            }
        }
    }

}

func checkFileExists(path: String) -> Bool {
    return FileManager.default.fileExists(atPath: path)
}

func checkDirectoryExists(path: String) -> Bool {
    var isDirectory: ObjCBool = false
    let _ = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
    return isDirectory.boolValue
}

func folderContents(path: String) -> [String] {
    // Returns a array of strings containing the folder contents
    // Does not perform a recursive list
    var filelist : [String] = []
    do {
        let files = try FileManager.default.contentsOfDirectory(atPath: path)
        for file in files {
            filelist.append("\(path)/\(file)")
        }
    } catch {
        return []
    }
    return filelist
}

func verifyPermissions(pathname :String) -> Bool {
    // Files should be owned by root
    // Files that are not scripts should have permissions 644 (-rw-r--r--)
    // Files that are scripts should have permissions 755 (-rwxr-xr-x)
    // If the permission for the request file is not correct then return fals to indicate it should not be processed
    
    let (ownerID, mode) = getFileProperties(pathname: pathname) //fileAttributes[.ownerAccountID] as! Int
    let posixPermissions = String(mode.intValue, radix: 8, uppercase: false)

    writeLog("ownerID for \(pathname) : \(String(describing: ownerID))", status: .debug)
    writeLog("posixPermissions for \(pathname) : \(String(describing: posixPermissions))", status: .debug)

    if ["pkg", "mpkg", "dmg", "mobileconfig"].contains(pathname.lowercased().split(separator: ".").last) {
        if ownerID == 0 && mode == requiredFilePermissions {
            return true
        } else {
            writeLog("Permissions for \(pathname) are incorrect. Should be owned by root and with mode x644", status: .error)
        }
    } else {
        if ownerID == 0 && mode == requiredExecutablePermissions {
            return true
        } else {
            writeLog("Permissions for \(pathname) are incorrect. Should be owned by root and with mode x755", status: .error)
        }
    }
    return false
}

func getFileProperties(pathname: String) -> (ownerID : Int, permissions : NSNumber) {
    // returns the ID and permissions of the specified file
    var fileAttributes : [FileAttributeKey:Any]
    var ownerID : Int = 0
    var mode : NSNumber = 0
    do {
        fileAttributes = try FileManager.default.attributesOfItem(atPath: pathname)// as Dictionary
        ownerID = fileAttributes[.ownerAccountID] as! Int
        mode = fileAttributes[.posixPermissions] as! NSNumber
    } catch {
        writeLog("Could not read file at path \(pathname)", status: .error)
    }
    return (ownerID,mode)
}

func pathCleanup(pathname: String) {
    // check if folder and clean all files in that folder
    // Deletes given script or cleans folder
    writeLog("Cleaning up \(pathname)", status: .debug)
    if checkDirectoryExists(path: pathname) {
        writeLog("\(pathname) is a folder. Iterating over files", status: .debug)
        for fileItem in folderContents(path: pathname) {
            writeLog("Cleaning up \(fileItem)", status: .debug)
            deleteFile(fileItem)
        }
    } else if checkFileExists(path: pathname) {
        writeLog("\(pathname) exists", status: .debug)
        deleteFile(pathname)
    } else {
        writeLog("\(pathname) doesn't seem to exist", status: .error)
    }
}

func deleteFile(_ path: String) {
    // Deletes the specified file
    writeLog("Deleting \(path)", status: .debug)
    do {
        try FileManager.default.removeItem(atPath: path)
        writeLog("\(path) deleted", status: .debug)
    } catch {
        writeLog("\(path) could not be removed", status: .error)
    }
}

func mountDmg(dmg: String) -> String {
    // Attaches dmg and returns the path
    let cmd = "/usr/bin/hdiutil attach -nobrowse -noverify -noautoopen \(dmg)"
    writeLog("Attaching \(dmg)", status: .debug)
    let (output, error, status) = runShellCommand(cmd)
    if status != 0 {
        writeLog("Failed attaching \(dmg) with error \(error)", status: .error)
        return error
    }
    return output.trimmingCharacters(in: .whitespacesAndNewlines)
}

func detachDmg(dmgMount: String) -> String {
    // Detaches dmg
    writeLog("Detaching \(dmgMount)", status: .debug)
    let cmd = "/usr/bin/hdiutil detach -force \(dmgMount)"
    let (output, error, status) = runShellCommand(cmd)
    if status != 0 {
        writeLog("Failed detaching \(dmgMount) with error \(error)", status: .error)
        return error
    }
    return output.trimmingCharacters(in: .whitespacesAndNewlines)
}

func verifySHASUMForFile(filename: String, shasumArray: [String:String]) -> Bool {
    // Verify that the file
    var proceed = false
    let errorMessage = "no required hash or file hash mismatch for: \(filename). Skipping"
    writeLog("checking hash for \(filename)", status: .debug)
    let url = URL(fileURLWithPath: filename)
    if let fileHash = sha256(for: url) {
        writeLog("file hash : \(fileHash)", status: .debug)
        if let storedHash = getValueForKey(filename, inArray: shasumArray) {
            writeLog("required hash : \(storedHash)", status: .debug)
            if storedHash == fileHash {
                proceed = true
            }
        }
    }
    if !proceed {
        writeLog(errorMessage, status: .error)
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

func shaAllFiles() {
    // compute sha256sum for all files in the outset directory
    // returns data in two formats to stdout:
    //   plaintext
    //   as plist format ready for import into an MDM or converting to a .mobileconfig
    
    let url = URL(fileURLWithPath: outsetDirectory)
    writeLog("SHASUM", status: .info)
    var shasum_plist = FileHashes()
    if let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) {
        for case let fileURL as URL in enumerator {
            do {
                let fileAttributes = try fileURL.resourceValues(forKeys:[.isRegularFileKey])
                if fileAttributes.isRegularFile! && fileURL.pathExtension != "plist" && fileURL.lastPathComponent != "outset" {
                    if let shasum = sha256(for: fileURL) {
                        print("\(fileURL.relativePath) : \(shasum)")
                        shasum_plist.sha256sum[fileURL.relativePath] = shasum
                    }
                }
            } catch { print(error, fileURL) }
        }
        
        writeLog("PLIST", status: .info)
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        do {
            let data = try encoder.encode(shasum_plist)
            if let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] {
                let formatted = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
                if let string = String(data: formatted, encoding: .utf8) {
                    print(string)
                }
            }
        } catch {
            writeLog("plist encoding failed", status: .error)
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
