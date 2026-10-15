import Foundation
import Testing

@Suite("Log rotation dates")
struct LogRotationTests {
    @Test("Rotation uses the full calendar date", arguments: [0, 1, 31, 365])
    func comparesFullDate(daysLater: Int) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let log = directory.appendingPathComponent("test.log")
        let contents = Data("original log".utf8)
        try contents.write(to: log)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let created = calendar.date(from: DateComponents(year: 2025, month: 1, day: 15, hour: 12))!
        try FileManager.default.setAttributes([.creationDate: created], ofItemAtPath: log.path)
        let now = calendar.date(byAdding: .day, value: daysLater, to: created)!

        performLogRotation(logFolderPath: directory.path, logFileBaseName: "test.log", now: now, calendar: calendar)

        let expected = daysLater == 0 ? log : directory.appendingPathComponent("test.log.1")
        #expect(try Data(contentsOf: expected) == contents)
        #expect(FileManager.default.fileExists(atPath: log.path) == (daysLater == 0))
    }

    @Test("A missing log needs no rotation")
    func missingLog() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        performLogRotation(logFolderPath: directory.path, logFileBaseName: "missing.log")
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty)
    }
}
