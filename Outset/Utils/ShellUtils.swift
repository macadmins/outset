//
//  ShellUtils.swift
//  Outset
//
//  Created by Bart E Reardon on 5/9/2023.
//

import Foundation

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
