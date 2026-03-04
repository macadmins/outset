//
//  ChecksumTests.swift
//  OutsetTests
//

import Testing
import Foundation

@Suite("computeChecksum")
struct ComputeChecksumTests {

    @Test("Does not crash with empty array")
    func doesNotCrashWithEmptyArray() {
        // Previously would crash with index out of bounds
        computeChecksum([])
    }

    @Test("Does not crash with empty default argument")
    func doesNotCrashWithDefaultArgument() {
        computeChecksum()
    }
}

@Suite("sha256")
struct SHA256Tests {

    @Test("Returns nil for non-existent file")
    func returnsNilForMissingFile() {
        let url = URL(fileURLWithPath: "/tmp/outset-test-nonexistent-\(UUID().uuidString)")
        let result = sha256(for: url)
        #expect(result == nil)
    }

    @Test("Returns consistent hash for same content")
    func returnsSameHashForSameContent() throws {
        let tmpURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let content = "hello outset".data(using: .utf8)!
        try content.write(to: tmpURL)
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        let hash1 = sha256(for: tmpURL)
        let hash2 = sha256(for: tmpURL)

        #expect(hash1 != nil)
        #expect(hash1 == hash2)
    }

    @Test("Returns different hashes for different content")
    func returnsDifferentHashesForDifferentContent() throws {
        let tmpURL1 = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let tmpURL2 = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try "content A".data(using: .utf8)!.write(to: tmpURL1)
        try "content B".data(using: .utf8)!.write(to: tmpURL2)
        defer {
            try? FileManager.default.removeItem(at: tmpURL1)
            try? FileManager.default.removeItem(at: tmpURL2)
        }

        let hash1 = sha256(for: tmpURL1)
        let hash2 = sha256(for: tmpURL2)

        #expect(hash1 != hash2)
    }

    @Test("Hash is a 64-character hex string")
    func hashIsHexString() throws {
        let tmpURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try "test".data(using: .utf8)!.write(to: tmpURL)
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        let hash = sha256(for: tmpURL)
        #expect(hash?.count == 64)
        #expect(hash?.allSatisfy { $0.isHexDigit } == true)
    }
}

@Suite("verifySHASUMForFile")
struct VerifySHASUMTests {

    @Test("Returns false for file not in checksum list")
    func returnsFalseForUnknownFile() throws {
        let tmpURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try "content".data(using: .utf8)!.write(to: tmpURL)
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        let result = verifySHASUMForFile(filename: tmpURL.path, shasumArray: [:])
        #expect(result == false)
    }

    @Test("Returns true when checksum matches")
    func returnsTrueForMatchingChecksum() throws {
        let tmpURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let content = "outset checksum test content"
        try content.data(using: .utf8)!.write(to: tmpURL)
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        let hash = sha256(for: tmpURL)!
        let result = verifySHASUMForFile(filename: tmpURL.path, shasumArray: [tmpURL.path: hash])
        #expect(result == true)
    }

    @Test("Returns false when checksum does not match")
    func returnsFalseForMismatchedChecksum() throws {
        let tmpURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try "some content".data(using: .utf8)!.write(to: tmpURL)
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        let wrongHash = String(repeating: "a", count: 64)
        let result = verifySHASUMForFile(filename: tmpURL.path, shasumArray: [tmpURL.path: wrongHash])
        #expect(result == false)
    }
}
