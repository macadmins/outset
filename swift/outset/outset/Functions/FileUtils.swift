//
//  Utils.swift
//  outset
//
//  Created by Bart Reardon on 3/12/2022.
//

import Foundation

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

func ensure_shared_folder() {
    if !check_file_exists(path: share_dir) {
        writeLog("\(share_dir) does not exist, creating now.", status: .debug)
        do {
            try FileManager.default.createDirectory(atPath: share_dir, withIntermediateDirectories: true)
        } catch {
            writeLog("Something went wrong. \(share_dir) could not be created.", status: .error)
        }
    }
}

func check_file_exists(path: String, isDir: ObjCBool = false) -> Bool {
    var checkIsDir :ObjCBool = isDir
    return FileManager.default.fileExists(atPath: path, isDirectory: &checkIsDir)
}

func list_folder(path: String) -> [String] {
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

    var fileAttributes : [FileAttributeKey:Any]

    do {
        fileAttributes = try FileManager.default.attributesOfItem(atPath: pathname)// as Dictionary
    } catch {
        writeLog("Could not read file at path \(pathname)", status: .error)
        return false
    }

    let ownerID = fileAttributes[.ownerAccountID] as! Int
    let mode = fileAttributes[.posixPermissions] as! NSNumber
    let posixPermissions = String(mode.intValue, radix: 8, uppercase: false)

    writeLog("ownerID for \(pathname) : \(String(describing: ownerID))", status: .debug)
    writeLog("posixPermissions for \(pathname) : \(String(describing: posixPermissions))", status: .debug)

    if ["pkg", "mpkg", "dmg", "mobileconfig"].contains(pathname.lowercased().split(separator: ".").last) {
        if ownerID == 0 && posixPermissions == "644" {
            return true
        } else {
            writeLog("Permissions for \(pathname) are incorrect. Should be owned by root and with mode x644", status: .debug)
        }
    } else {
        if ownerID == 0 && posixPermissions == "755" {
            return true
        } else {
            writeLog("Permissions for \(pathname) are incorrect. Should be owned by root and with mode x755", status: .debug)
        }
    }
    return false
}

func path_cleanup(pathname: String) {
    // check if folder and clean all files in that folder
    // Deletes given script or cleans folder
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
    do {
        try FileManager.default.removeItem(atPath: path)
        writeLog("\(path) deleted", status: .debug)
    } catch {
        writeLog("\(path) could not be removed", status: .error)
    }
}

func mount_dmg(dmg: String) -> String {
    // Attaches dmg
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
