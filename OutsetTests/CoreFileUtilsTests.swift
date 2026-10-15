//
//  CoreFileUtilsTests.swift
//  OutsetTests
//

import Testing
import Foundation

@Suite("checkFileExists")
struct CheckFileExistsTests {

    @Test("Returns true for existing file")
    func returnsTrueForExistingFile() throws {
        let tmpURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        FileManager.default.createFile(atPath: tmpURL.path, contents: nil)
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        #expect(checkFileExists(path: tmpURL.path) == true)
    }

    @Test("Returns false for non-existent file")
    func returnsFalseForMissingFile() {
        #expect(checkFileExists(path: "/tmp/outset-test-nonexistent-\(UUID().uuidString)") == false)
    }
}

@Suite("checkDirectoryExists")
struct CheckDirectoryExistsTests {

    @Test("Returns true for existing directory")
    func returnsTrueForExistingDirectory() throws {
        let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        #expect(checkDirectoryExists(path: tmpDir.path) == true)
    }

    @Test("Returns false for non-existent directory")
    func returnsFalseForMissingDirectory() {
        #expect(checkDirectoryExists(path: "/tmp/outset-test-nonexistent-\(UUID().uuidString)") == false)
    }

    @Test("Returns false for a file path (not a directory)")
    func returnsFalseForFilePath() throws {
        let tmpURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        FileManager.default.createFile(atPath: tmpURL.path, contents: nil)
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        #expect(checkDirectoryExists(path: tmpURL.path) == false)
    }
}

@Suite("folderContents")
struct FolderContentsTests {

    @Test("Returns empty array for empty directory")
    func returnsEmptyArrayForEmptyDirectory() throws {
        let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        #expect(folderContents(path: tmpDir.path).isEmpty == true)
    }

    @Test("Returns empty array for non-existent directory")
    func returnsEmptyArrayForMissingDirectory() {
        #expect(folderContents(path: "/tmp/outset-test-nonexistent-\(UUID().uuidString)").isEmpty == true)
    }

    @Test("Returns sorted list of full paths")
    func returnsSortedFullPaths() throws {
        let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let names = ["charlie.sh", "alpha.sh", "bravo.sh"]
        for name in names {
            FileManager.default.createFile(atPath: tmpDir.appendingPathComponent(name).path, contents: nil)
        }

        let contents = folderContents(path: tmpDir.path)
        #expect(contents.count == 3)
        // Should be sorted alphabetically
        #expect(contents[0].hasSuffix("alpha.sh"))
        #expect(contents[1].hasSuffix("bravo.sh"))
        #expect(contents[2].hasSuffix("charlie.sh"))
        // Each entry should be a full path
        #expect(contents.allSatisfy { $0.hasPrefix(tmpDir.path) })
    }
}

@Suite("createTrigger and pathCleanup")
struct TriggerTests {

    @Test("createTrigger creates a file at the given path")
    func createsTriggerFile() {
        let path = NSTemporaryDirectory() + "outset-test-trigger-\(UUID().uuidString)"
        defer { try? FileManager.default.removeItem(atPath: path) }

        createTrigger(path)
        #expect(checkFileExists(path: path) == true)
    }

    @Test("pathCleanup removes a file")
    func removesFile() throws {
        let tmpURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        FileManager.default.createFile(atPath: tmpURL.path, contents: nil)

        pathCleanup(tmpURL.path)
        #expect(checkFileExists(path: tmpURL.path) == false)
    }

    @Test("pathCleanup empties a directory without removing it")
    func emptiesDirectory() throws {
        let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        FileManager.default.createFile(atPath: tmpDir.appendingPathComponent("file1").path, contents: nil)
        FileManager.default.createFile(atPath: tmpDir.appendingPathComponent("file2").path, contents: nil)

        pathCleanup(tmpDir.path)

        #expect(checkDirectoryExists(path: tmpDir.path) == true)
        #expect(folderContents(path: tmpDir.path).isEmpty == true)
    }
}

@Suite("verifyPermissions")
struct VerifyPermissionsTests {

    // Files a test creates are owned by the test user, so the tests trust that
    // user alongside root. outset itself trusts root only.
    let owners: Set<uid_t> = [0, getuid()]

    func makeDirectory() throws -> URL {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func makeFile(in dir: URL, name: String, mode: Int) -> URL {
        let url = dir.appendingPathComponent(name)
        FileManager.default.createFile(atPath: url.path, contents: Data("#!/bin/sh\n".utf8),
                                       attributes: [.posixPermissions: mode])
        return url
    }

    @Test("Accepts a 755 script in folders writable only by their owner")
    func acceptsScript() throws {
        let dir = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let script = makeFile(in: dir, name: "run.sh", mode: 0o755)

        #expect(verifyPermissions(pathname: script.path, trustedOwners: owners) == true)
    }

    @Test("Rejects a script with the wrong mode")
    func rejectsWrongMode() throws {
        let dir = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let script = makeFile(in: dir, name: "run.sh", mode: 0o775)

        #expect(verifyPermissions(pathname: script.path, trustedOwners: owners) == false)
    }

    @Test("Rejects a file not owned by a trusted owner")
    func rejectsUntrustedOwner() throws {
        let dir = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let script = makeFile(in: dir, name: "run.sh", mode: 0o755)

        #expect(verifyPermissions(pathname: script.path, trustedOwners: [0]) == false)
    }

    @Test("Rejects a symlink even when its target passes")
    func rejectsSymlink() throws {
        let dir = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let target = makeFile(in: dir, name: "target.sh", mode: 0o755)
        let link = dir.appendingPathComponent("link.sh")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)

        #expect(verifyPermissions(pathname: link.path, trustedOwners: owners) == false)
    }

    @Test("Rejects a script inside a group- or world-writable folder")
    func rejectsWritableParent() throws {
        let dir = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let inner = dir.appendingPathComponent("inner")
        try FileManager.default.createDirectory(at: inner, withIntermediateDirectories: false,
                                                attributes: [.posixPermissions: 0o777])
        let script = makeFile(in: inner, name: "run.sh", mode: 0o755)

        #expect(verifyPermissions(pathname: script.path, trustedOwners: owners) == false)
    }

    @Test("Expects 644 for packages")
    func packageMode() throws {
        let dir = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let pkg = makeFile(in: dir, name: "thing.pkg", mode: 0o644)
        let executablePkg = makeFile(in: dir, name: "other.pkg", mode: 0o755)

        #expect(verifyPermissions(pathname: pkg.path, trustedOwners: owners) == true)
        #expect(verifyPermissions(pathname: executablePkg.path, trustedOwners: owners) == false)
    }
}

@Suite("verifyParentChain")
struct VerifyParentChainTests {

    let owners: Set<uid_t> = [0, getuid()]

    @Test("Rejects a symlinked folder that sits in a writable folder")
    func rejectsLinkInWritableFolder() throws {
        let base = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }

        let real = base.appendingPathComponent("real")
        try FileManager.default.createDirectory(at: real, withIntermediateDirectories: false)
        let open = base.appendingPathComponent("open")
        try FileManager.default.createDirectory(at: open, withIntermediateDirectories: false,
                                                attributes: [.posixPermissions: 0o777])
        let link = open.appendingPathComponent("scripts")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: real)
        let script = real.appendingPathComponent("run.sh")
        FileManager.default.createFile(atPath: script.path, contents: Data("#!/bin/sh\n".utf8),
                                       attributes: [.posixPermissions: 0o755])

        #expect(verifyPermissions(pathname: script.path, trustedOwners: owners) == true)
        #expect(verifyPermissions(pathname: link.appendingPathComponent("run.sh").path, trustedOwners: owners) == false)
    }

    @Test("Accepts a symlinked folder that sits in a root-only folder")
    func acceptsLinkInLockedFolder() throws {
        let base = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }

        let real = base.appendingPathComponent("real")
        try FileManager.default.createDirectory(at: real, withIntermediateDirectories: false)
        let link = base.appendingPathComponent("scripts")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: real)
        FileManager.default.createFile(atPath: real.appendingPathComponent("run.sh").path,
                                       contents: Data("#!/bin/sh\n".utf8),
                                       attributes: [.posixPermissions: 0o755])

        #expect(verifyPermissions(pathname: link.appendingPathComponent("run.sh").path, trustedOwners: owners) == true)
    }

    @Test("Rejects a chain of links whose middle hop sits in a writable folder")
    func rejectsChainedLinkThroughWritableFolder() throws {
        let base = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }

        let real = base.appendingPathComponent("real")
        try FileManager.default.createDirectory(at: real, withIntermediateDirectories: false)
        let open = base.appendingPathComponent("open")
        try FileManager.default.createDirectory(at: open, withIntermediateDirectories: false,
                                                attributes: [.posixPermissions: 0o777])
        let middle = open.appendingPathComponent("middle")
        try FileManager.default.createSymbolicLink(at: middle, withDestinationURL: real)
        let first = base.appendingPathComponent("scripts")
        try FileManager.default.createSymbolicLink(atPath: first.path, withDestinationPath: middle.path)
        FileManager.default.createFile(atPath: real.appendingPathComponent("run.sh").path,
                                       contents: Data("#!/bin/sh\n".utf8),
                                       attributes: [.posixPermissions: 0o755])

        #expect(verifyPermissions(pathname: first.appendingPathComponent("run.sh").path, trustedOwners: owners) == false)
    }
}

@Suite("Permission validation edge cases")
struct PermissionEdgeCaseTests {
    let owners: Set<uid_t> = [0, getuid()]

    @Test("Missing files and directory payloads are rejected")
    func rejectsMissingAndDirectory() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        #expect(!verifyPermissions(pathname: directory.appendingPathComponent("missing.sh").path, trustedOwners: owners))
        #expect(!verifyPermissions(pathname: directory.path, trustedOwners: owners))
    }

    @Test("Files belonging to an untrusted owner are rejected")
    func rejectsUntrustedOwner() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: file) }
        try Data().write(to: file)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: file.path)
        #expect(!verifyPermissions(pathname: file.path, trustedOwners: []))
    }

    @Test("A relative parent link can resolve through safe folders")
    func relativeLink() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let real = directory.appendingPathComponent("real")
        try FileManager.default.createDirectory(at: real, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = real.appendingPathComponent("run.sh")
        try Data().write(to: file)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: file.path)
        let link = directory.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(atPath: link.path, withDestinationPath: "real")
        #expect(verifyPermissions(pathname: link.appendingPathComponent("run.sh").path, trustedOwners: owners))
    }

    @Test("Parent link loops terminate and are rejected")
    func linkLoop() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let link = directory.appendingPathComponent("loop")
        try FileManager.default.createSymbolicLink(atPath: link.path, withDestinationPath: "loop")
        #expect(!verifyParentChain(of: link.appendingPathComponent("run.sh").path, trustedOwners: owners))
    }
}
