//
//  Checksum.swift
//  Outset
//
//  Created by Bart E Reardon on 5/9/2023.
//

import Foundation
import CryptoKit

// MARK: - Ed25519 embedded-signature support

/// The comment format used to embed a signature inside a script file.
/// The line must appear anywhere in the script and match this prefix exactly.
let ed25519CommentPrefix = "# ed25519: "

/// Returns the canonical signable content of a script: the raw file content
/// with any existing embedded `# ed25519: …` line stripped out.
///
/// Stripping rather than appending means the signature covers a stable payload
/// that an admin can inspect or version-control without the sig comment present.
func canonicalContent(of scriptContent: String) -> Data {
    let lines = scriptContent.components(separatedBy: "\n")
    let stripped = lines.filter { !$0.hasPrefix(ed25519CommentPrefix) }
    return stripped.joined(separator: "\n").data(using: .utf8) ?? Data()
}

/// Verifies the Ed25519 signature embedded in a script file.
///
/// - Parameters:
///   - path: Absolute path to the script file on disk.
///   - publicKeyBase64: Base64-encoded 32-byte Ed25519 public key (as stored in `manifest_signing_key`).
/// - Returns: `true` if a valid `# ed25519: <sig>` comment is present and the
///   signature verifies against the canonical content; `false` otherwise.
func verifyScriptSignature(path: String, publicKeyBase64: String) -> Bool {
    // Load raw file content
    guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
        writeLog("Script signing: could not read file \(path)", logLevel: .error)
        return false
    }

    // Find the embedded signature comment
    let lines = content.components(separatedBy: "\n")
    guard let sigLine = lines.first(where: { $0.hasPrefix(ed25519CommentPrefix) }) else {
        writeLog("Script signing: no embedded signature found in \(path)", logLevel: .error)
        return false
    }

    let sigBase64 = String(sigLine.dropFirst(ed25519CommentPrefix.count)).trimmingCharacters(in: .whitespaces)

    // Decode the public key
    guard let keyData = Data(base64Encoded: publicKeyBase64) else {
        writeLog("Script signing: invalid base64 public key", logLevel: .error)
        return false
    }
    guard let publicKey = try? Curve25519.Signing.PublicKey(rawRepresentation: keyData) else {
        writeLog("Script signing: could not construct public key from raw bytes", logLevel: .error)
        return false
    }

    // Decode the signature
    guard let sigData = Data(base64Encoded: sigBase64) else {
        writeLog("Script signing: invalid base64 signature in \(path)", logLevel: .error)
        return false
    }

    // Verify signature over canonical content (file minus the sig comment line)
    let payload = canonicalContent(of: content)
    let valid = publicKey.isValidSignature(sigData, for: payload)

    if valid {
        writeLog("Script signing: verified signature for \(path)", logLevel: .debug)
    } else {
        writeLog("Script signing: signature verification FAILED for \(path)", logLevel: .error)
    }
    return valid
}

/// Signs a script file and embeds the base64 signature as a `# ed25519: <sig>` comment.
///
/// - Parameters:
///   - path: Absolute path to the script file. The file is updated in place.
///   - privateKeyBase64: Base64-encoded 32-byte Ed25519 private key raw representation.
/// - Returns: `true` on success, `false` if any step fails.
@discardableResult
func signScript(path: String, privateKeyBase64: String) -> Bool {
    guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
        printStdErr("Could not read file: \(path)")
        return false
    }

    guard let keyData = Data(base64Encoded: privateKeyBase64) else {
        printStdErr("Invalid base64 private key")
        return false
    }
    guard let privateKey = try? Curve25519.Signing.PrivateKey(rawRepresentation: keyData) else {
        printStdErr("Could not construct private key from raw bytes")
        return false
    }

    // Compute signature over canonical content (strip any previous sig line first)
    let payload = canonicalContent(of: content)
    guard let sigData = try? privateKey.signature(for: payload) else {
        printStdErr("Signing failed for \(path)")
        return false
    }
    let sigBase64 = sigData.base64EncodedString()
    let sigComment = "\(ed25519CommentPrefix)\(sigBase64)"

    // Strip any existing sig line and append the new one
    let lines = content.components(separatedBy: "\n")
    var stripped = lines.filter { !$0.hasPrefix(ed25519CommentPrefix) }

    // Insert after the shebang line if present, otherwise at the top
    let insertIndex = stripped.first?.hasPrefix("#!") == true ? 1 : 0
    stripped.insert(sigComment, at: insertIndex)

    let updated = stripped.joined(separator: "\n")
    do {
        try updated.write(toFile: path, atomically: true, encoding: .utf8)
    } catch {
        printStdErr("Could not write signed script to \(path): \(error.localizedDescription)")
        return false
    }

    printStdOut("Signed: \(path)")
    return true
}

/// Generates a new Ed25519 signing keypair and prints both the private key (for the
/// admin to store securely) and the public key (for deployment via MDM as `manifest_signing_key`).
func generateSigningKeypair() {
    let privateKey = Curve25519.Signing.PrivateKey()
    let publicKey = privateKey.publicKey

    let privateKeyBase64 = privateKey.rawRepresentation.base64EncodedString()
    let publicKeyBase64 = publicKey.rawRepresentation.base64EncodedString()

    printStdOut("Ed25519 signing keypair generated.")
    printStdOut("")
    printStdOut("Private key (keep secret — used to sign scripts):")
    printStdOut(privateKeyBase64)
    printStdOut("")
    printStdOut("Public key (deploy via MDM as 'manifest_signing_key'):")
    printStdOut(publicKeyBase64)
}

struct FileHashes: Codable {
    var sha256sum: [String: String] = [String: String]()
}

func computeChecksum(_ files: [String] = []) {
    guard !files.isEmpty else { return }

    if files[0].lowercased() == "all" {
        checksumAllFiles()
    } else {
        for fileToHash in files {
            let url = URL(fileURLWithPath: fileToHash)
            if let hash = sha256(for: url) {
                printStdOut("Checksum for file \(fileToHash): \(hash)")
            }
        }
    }
}

func printChecksumReport() {
    writeLog("Checksum report", logLevel: .info)
    for (filename, checksum) in checksumLoadApprovedFiles() {
        writeLog("\(filename) : \(checksum)", logLevel: .info)
    }
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
                if fileAttributes.isRegularFile! && fileURL.pathExtension != "plist" && fileURL.lastPathComponent != "outset" && !fileURL.relativePath.contains(logFilePath) {
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
