//
//  Logging.swift
//  Outset
//
//  Created by Bart E Reardon on 5/9/2023.
//

import Foundation
import OSLog

// swiftlint:disable force_try
class StandardError: TextOutputStream {
    func write(_ string: String) {
      if #available(macOS 10.15.4, *) {
          try! FileHandle.standardError.write(contentsOf: Data(string.utf8))
      } else {
          // Fallback on earlier versions (should work on pre 10.15.4 but untested)
          if let data = string.data(using: .utf8) {
              FileHandle.standardError.write(data)
          }
      }
    }
}
// swiftlint:enable force_try

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

func printStdErr(_ errorMessage: String) {
    var standardError = StandardError()
    print(errorMessage, to: &standardError)
}

func printStdOut(_ message: String) {
    print(message)
}

func writeLog(_ message: String, logLevel: OSLogType = .info, log: OSLog = osLog) {
    // write to the system logs

    // let logger = Logger()  // 'Logger' is only available in macOS 11.0 or newer so we use os_log

    os_log("%{public}@", log: log, type: logLevel, message)
    switch logLevel {
    case .error, .debug, .fault:
        printStdErr("\(oslogTypeToString(logLevel).uppercased()): \(message)")
    default:
        printStdOut("\(oslogTypeToString(logLevel).uppercased()): \(message)")
    }

    // also write to a log file
    writeFileLog(message: message, logLevel: logLevel)
}

func writeFileLog(message: String, logLevel: OSLogType) {
    // write to a log file for accessability of those that don't want to manage the system log
    //if logLevel == .debug && !debugMode {
    //    return
    //}
    let logFileURL = URL(fileURLWithPath: logFilePath)
    if !checkFileExists(path: logFilePath) {
        FileManager.default.createFile(atPath: logFileURL.path, contents: nil, attributes: nil)
        let attributes = [FileAttributeKey.posixPermissions: 0o666]
        do {
            try FileManager.default.setAttributes(attributes, ofItemAtPath: logFileURL.path)
        } catch {
            printStdErr("\(oslogTypeToString(.error).uppercased()): Unable to create log file at \(logFilePath)")
            printStdErr(error.localizedDescription)
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
        printStdErr("\(oslogTypeToString(.error).uppercased()): Unable to read log file at \(logFilePath)")
        printStdErr(error.localizedDescription)
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
