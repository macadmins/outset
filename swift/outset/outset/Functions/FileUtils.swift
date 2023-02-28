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

func ensure_working_folders() {
    // Ensures working folders are all present and creates them if necessary
    let working_directories = [
        boot_every_dir,
        boot_once_dir,
        login_every_dir,
        login_once_dir,
        login_privileged_every_dir,
        login_privileged_once_dir,
        on_demand_dir,
        share_dir
    ]

    for directory in working_directories {
        if !check_file_exists(path: directory, isDir: true) {
            writeLog("\(directory) does not exist, creating now.", status: .debug)
            do {
                try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
            } catch {
                writeLog("could not create path at \(directory)", status: .error)
            }
        }
    }
}

func migrate_legacy_preferences() {
    // shared folder should not contain any executable content, iterate and update as required
    // TODO: could probably be optimised as there is duplication with ensure_working_folders()
    if check_file_exists(path: share_dir) {
        writeLog("\(share_dir) exists. Migrating prefernces to user defaults", status: .debug)
        
        let legacyOutsetPreferencesFile = "com.chilcote.outset.plist"
        let legacyRootRunOncePlistFile = "com.github.outset.once.\(getConsoleUserInfo().userID).plist"
        let userHomePath = FileManager.default.homeDirectoryForCurrentUser.relativeString.replacingOccurrences(of: "file://", with: "")
        let legacyUserRunOncePlistFile = userHomePath+"Library/Preferences/com.github.outset.once.plist"

        var share_files = list_folder(path: share_dir)
        share_files.append(legacyRootRunOncePlistFile)
        share_files.append(legacyUserRunOncePlistFile)
        
        for filename in share_files {
            let url = URL(fileURLWithPath: filename)
            do {
                let data = try Data(contentsOf: url)
                switch filename {
                    
                    case legacyOutsetPreferencesFile:
                        let legacyPreferences = try PropertyListDecoder().decode(OutsetPreferences.self, from: data)
                        write_outset_preferences(prefs: legacyPreferences)
                        writeLog("Migrated Legacy Outset Preferences", status: .debug)
                        delete_file(legacyOutsetPreferencesFile)
                        writeLog("Deleted \(legacyOutsetPreferencesFile)", status: .debug)
                        
                    case legacyRootRunOncePlistFile, legacyUserRunOncePlistFile:
                        let legacyRunOncePlistData = try PropertyListDecoder().decode([String:Date].self, from: data)
                        write_runonce(runOnceData: legacyRunOncePlistData)
                        writeLog("Migrated Legacy Runonce Data", status: .debug)
                        if is_root() {
                            delete_file(legacyRootRunOncePlistFile)
                            writeLog("Deleted \(legacyRootRunOncePlistFile)", status: .debug)
                        } else {
                            delete_file(legacyUserRunOncePlistFile)
                            writeLog("Deleted \(legacyUserRunOncePlistFile)", status: .debug)
                        }
                        
                    default:
                        continue
                }
                
            } catch {
                writeLog("outset preferences plist  migration failed", status: .error)
            }
            
        }
    }

}

func check_file_exists(path: String, isDir: ObjCBool = false) -> Bool {
    // What is says on the tin
    var checkIsDir :ObjCBool = isDir
    return FileManager.default.fileExists(atPath: path, isDirectory: &checkIsDir)
}

func list_folder(path: String) -> [String] {
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

func check_permissions(pathname :String) -> Bool {
    // Files should be owned by root
    // Files that are not scripts should have permissions 644 (-rw-r--r--)
    // Files that are scripts should have permissions 755 (-rwxr-xr-x)
    // If the permission for the request file is not correct then return fals to indicate it should not be processed
    
    let (ownerID, mode) = get_file_owner_and_permissions(pathname: pathname) //fileAttributes[.ownerAccountID] as! Int
    let posixPermissions = String(mode.intValue, radix: 8, uppercase: false)

    writeLog("ownerID for \(pathname) : \(String(describing: ownerID))", status: .debug)
    writeLog("posixPermissions for \(pathname) : \(String(describing: posixPermissions))", status: .debug)

    if ["pkg", "mpkg", "dmg", "mobileconfig"].contains(pathname.lowercased().split(separator: ".").last) {
        if ownerID == 0 && mode == filePermissions {
            return true
        } else {
            writeLog("Permissions for \(pathname) are incorrect. Should be owned by root and with mode x644", status: .error)
        }
    } else {
        if ownerID == 0 && mode == executablePermissions {
            return true
        } else {
            writeLog("Permissions for \(pathname) are incorrect. Should be owned by root and with mode x755", status: .error)
        }
    }
    return false
}

func get_file_owner_and_permissions(pathname: String) -> (ownerID : Int, permissions : NSNumber) {
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

func path_cleanup(pathname: String) {
    // check if folder and clean all files in that folder
    // Deletes given script or cleans folder
    writeLog("Cleaning up \(pathname)", status: .debug)
    if check_file_exists(path: pathname, isDir: true) {
        for fileItem in list_folder(path: pathname) {
            delete_file(fileItem)
        }
    } else if check_file_exists(path: pathname) {
        delete_file(pathname)
    } else {
        writeLog("\(pathname) doesn't seem to exist", status: .error)
    }
}

func delete_file(_ path: String) {
    // Deletes the specified file
    writeLog("Deleting \(path)", status: .debug)
    do {
        try FileManager.default.removeItem(atPath: path)
        writeLog("\(path) deleted", status: .debug)
    } catch {
        writeLog("\(path) could not be removed", status: .error)
    }
}

func mount_dmg(dmg: String) -> String {
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

func detach_dmg(dmgMount: String) -> String {
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
    
    let url = URL(fileURLWithPath: outset_dir)
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
