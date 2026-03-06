//
//  ShellUtils.swift
//  Outset
//
//  Created by Bart E Reardon on 5/9/2023.
//

import Foundation

/// Launches a shell command and streams its stdout/stderr line by line to the
/// provided log callbacks as they are produced, rather than buffering until exit.
/// Blocks until the process exits. Intended to be called from a background
/// DispatchQueue so the streaming output is interleaved naturally in the log.
///
/// - Parameters:
///   - command: The shell command to run (passed to /bin/sh -c).
///   - args: Optional arguments appended to the command string.
///   - logTag: Prefix prepended to every streamed output line (e.g. "[BG:pid=N]").
///   - onOutput: Called with each complete stdout line as it arrives.
///   - onError: Called with each complete stderr line as it arrives.
///   - processRef: Populated with the launched Process so the caller can
///                 terminate it externally (e.g. on timeout).
/// - Returns: The process exit code.
func runShellCommandTracked(_ command: String,
                            args: [String] = [],
                            logTag: String = "",
                            onOutput: @escaping (String) -> Void,
                            onError: @escaping (String) -> Void,
                            processRef: inout Process?) -> Int32 {
    let task = Process()
    let outPipe = Pipe()
    let errPipe = Pipe()

    var cmd = command
    for arg in args {
        cmd += " '\(arg)'"
    }

    task.launchPath = "/bin/sh"
    task.arguments = ["-c", cmd]
    task.standardOutput = outPipe
    task.standardError = errPipe
    task.launch()

    processRef = task

    // Stream stdout line by line as data arrives
    var outBuffer = Data()
    outPipe.fileHandleForReading.readabilityHandler = { handle in
        let chunk = handle.availableData
        guard !chunk.isEmpty else { return }
        outBuffer.append(chunk)
        // Emit each complete line; hold back any partial final line
        while let newlineRange = outBuffer.range(of: Data([0x0A])) {
            let lineData = outBuffer.subdata(in: outBuffer.startIndex..<newlineRange.lowerBound)
            outBuffer.removeSubrange(outBuffer.startIndex...newlineRange.lowerBound)
            if let line = String(data: lineData, encoding: .utf8), !line.isEmpty {
                onOutput(line)
            }
        }
    }

    // Stream stderr line by line
    var errBuffer = Data()
    errPipe.fileHandleForReading.readabilityHandler = { handle in
        let chunk = handle.availableData
        guard !chunk.isEmpty else { return }
        errBuffer.append(chunk)
        while let newlineRange = errBuffer.range(of: Data([0x0A])) {
            let lineData = errBuffer.subdata(in: errBuffer.startIndex..<newlineRange.lowerBound)
            errBuffer.removeSubrange(errBuffer.startIndex...newlineRange.lowerBound)
            if let line = String(data: lineData, encoding: .utf8), !line.isEmpty {
                onError(line)
            }
        }
    }

    task.waitUntilExit()

    // Flush any remaining partial line that arrived without a trailing newline
    outPipe.fileHandleForReading.readabilityHandler = nil
    errPipe.fileHandleForReading.readabilityHandler = nil

    if !outBuffer.isEmpty, let line = String(data: outBuffer, encoding: .utf8), !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        onOutput(line.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    if !errBuffer.isEmpty, let line = String(data: errBuffer, encoding: .utf8), !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        onError(line.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    return task.terminationStatus
}

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

    output.append(String(data: data, encoding: .utf8) ?? "")
    error.append(String(data: errordata, encoding: .utf8) ?? "")

    task.waitUntilExit()
    let status = task.terminationStatus
    if verbose {
        writeLog("Completed task \(command) with status \(status)", logLevel: .debug)
        writeLog("Task output: \n\(output)", logLevel: .debug)
    }
    return (output, error, status)
}
