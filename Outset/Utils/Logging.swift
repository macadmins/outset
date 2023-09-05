//
//  Logging.swift
//  Outset
//
//  Created by Bart E Reardon on 5/9/2023.
//

import Foundation
import OSLog

func oslogTypeToString(_ type: OSLogType) -> String {
    switch type {
    case OSLogType.default: return "default"
    case OSLogType.info: return "info"
    case OSLogType.debug: return "debug"
    case OSLogType.error: return "error"
    case OSLogType.fault: return "fault"
    default: return "unknown"
    }
}

func writeLog(_ message: String, logLevel: OSLogType = .info, log: OSLog = osLog) {
    // write to the system logs
    os_log("%{public}@", log: log, type: logLevel, message)
    if logLevel == .error || logLevel == .info || (debugMode && logLevel == .debug) {
        // print info, errors and debug to stdout
        print("\(oslogTypeToString(logLevel).uppercased()): \(message)")
    }
    // also write to a log file for accessability of those that don't want to manage the system log
    writeFileLog(message: message, logLevel: logLevel)
}

func writeFileLog(message: String, logLevel: OSLogType) {
    if logLevel == .debug && !debugMode {
        return
    }
    let logFileURL = URL(fileURLWithPath: logFile)
    if !checkFileExists(path: logFile) {
        FileManager.default.createFile(atPath: logFileURL.path, contents: nil, attributes: nil)
        let attributes = [FileAttributeKey.posixPermissions: 0o666]
        do {
            try FileManager.default.setAttributes(attributes, ofItemAtPath: logFileURL.path)
        } catch {
            print("\(oslogTypeToString(.error).uppercased()): Unable to create log file at \(logFile)")
            return
        }
    }
    do {
        let fileHandle = try FileHandle(forWritingTo: logFileURL)
        defer { fileHandle.closeFile() }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        let date = dateFormatter.string(from: Date())
        let logEntry = "\(date) \(oslogTypeToString(logLevel).uppercased()): \(message)\n"

        fileHandle.seekToEndOfFile()
        fileHandle.write(logEntry.data(using: .utf8)!)
    } catch {
        print("\(oslogTypeToString(.error).uppercased()): Unable to read log file at \(logFile)")
        return
    }
}

func writeSysReport() {
    // Logs system information to log file
    writeLog("User: \(getConsoleUserInfo())", logLevel: .debug)
    writeLog("Model: \(getDeviceHardwareModel())", logLevel: .debug)
    writeLog("Marketing Model: \(getMarketingModel())", logLevel: .debug)
    writeLog("Serial: \(getDeviceSerialNumber())", logLevel: .debug)
    writeLog("OS: \(getOSVersion())", logLevel: .debug)
    writeLog("Build: \(getOSBuildVersion())", logLevel: .debug)
}
