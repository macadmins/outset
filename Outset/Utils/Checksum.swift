//
//  Checksum.swift
//  Outset
//
//  Created by Bart E Reardon on 5/9/2023.
//

import Foundation

struct FileHashes: Codable {
    var sha256sum: [String: String] = [String: String]()
}

func checksumLoadApprovedFiles() -> [String: String] {
    // imports the list of file hashes that are approved to run
    var outsetFileHashList = FileHashes()

    let defaults = UserDefaults.standard
    let hashes = defaults.object(forKey: "sha256sum")

    if let data = hashes as? [String: String] {
        for (key, value) in data {
            outsetFileHashList.sha256sum[key] = value
        }
    }

    return outsetFileHashList.sha256sum
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
                        printStdOut("\(fileURL.relativePath) : \(shasum)")
                        shasumPlist.sha256sum[fileURL.relativePath] = shasum
                    }
                }
            } catch {
                printStdErr(error.localizedDescription)
                printStdErr(fileURL.absoluteString)
            }
        }

        writeLog("PLIST", logLevel: .info)
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        do {
            let data = try encoder.encode(shasumPlist)
            if let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] {
                let formatted = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
                if let string = String(data: formatted, encoding: .utf8) {
                    printStdOut(string)
                }
            }
        } catch {
            writeLog("plist encoding failed", logLevel: .error)
        }
    }
}
