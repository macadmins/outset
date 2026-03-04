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
