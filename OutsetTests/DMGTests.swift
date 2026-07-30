//
//  DMGTests.swift
//  OutsetTests
//

import Testing
import Foundation

@Suite("dmgMountPoint")
struct DMGMountPointTests {

    // Captured from `hdiutil attach -nobrowse -noverify -noautoopen -plist` for a
    // typical APFS disk image. The mounted volume is the only entity with a
    // mount-point key; the partition scheme and container entities have none.
    static let apfsSample = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
        <key>system-entities</key>
        <array>
            <dict>
                <key>content-hint</key>
                <string>GUID_partition_scheme</string>
                <key>dev-entry</key>
                <string>/dev/disk4</string>
                <key>potentially-mountable</key>
                <false/>
                <key>unmapped-content-hint</key>
                <string>GUID_partition_scheme</string>
            </dict>
            <dict>
                <key>content-hint</key>
                <string>Apple_APFS</string>
                <key>dev-entry</key>
                <string>/dev/disk4s1</string>
                <key>potentially-mountable</key>
                <false/>
                <key>unmapped-content-hint</key>
                <string>7C3457EF-0000-11AA-AA11-00306543ECAC</string>
            </dict>
            <dict>
                <key>content-hint</key>
                <string>41504653-0000-11AA-AA11-00306543ECAC</string>
                <key>dev-entry</key>
                <string>/dev/disk5s1</string>
                <key>mount-point</key>
                <string>/Volumes/Demo Installer</string>
                <key>potentially-mountable</key>
                <true/>
                <key>unmapped-content-hint</key>
                <string>41504653-0000-11AA-AA11-00306543ECAC</string>
            </dict>
        </array>
    </dict>
    </plist>
    """

    // A single-entity HFS+ image where the lone entity is the mounted volume.
    static let hfsSample = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
        <key>system-entities</key>
        <array>
            <dict>
                <key>content-hint</key>
                <string>Apple_HFS</string>
                <key>dev-entry</key>
                <string>/dev/disk6</string>
                <key>mount-point</key>
                <string>/Volumes/Demo</string>
                <key>potentially-mountable</key>
                <true/>
            </dict>
        </array>
    </dict>
    </plist>
    """

    @Test("Returns the mount point from a partitioned APFS image")
    func returnsMountPointForApfsImage() {
        #expect(dmgMountPoint(fromHdiutilPlist: Self.apfsSample) == "/Volumes/Demo Installer")
    }

    @Test("Returns the mount point from a single-entity HFS image")
    func returnsMountPointForHfsImage() {
        #expect(dmgMountPoint(fromHdiutilPlist: Self.hfsSample) == "/Volumes/Demo")
    }

    @Test("Returns empty string for non-plist output")
    func returnsEmptyForNonPlistOutput() {
        let tableOutput = "/dev/disk4\tGUID_partition_scheme\t\n/dev/disk4s1\tApple_HFS\t/Volumes/Demo"
        #expect(dmgMountPoint(fromHdiutilPlist: tableOutput).isEmpty == true)
    }

    @Test("Returns empty string for empty output")
    func returnsEmptyForEmptyOutput() {
        #expect(dmgMountPoint(fromHdiutilPlist: "").isEmpty == true)
    }

    @Test("Returns empty string when no entity has a mount point")
    func returnsEmptyWhenNothingMounted() {
        let unmountedSample = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>system-entities</key>
            <array>
                <dict>
                    <key>content-hint</key>
                    <string>GUID_partition_scheme</string>
                    <key>dev-entry</key>
                    <string>/dev/disk4</string>
                    <key>potentially-mountable</key>
                    <false/>
                </dict>
            </array>
        </dict>
        </plist>
        """
        #expect(dmgMountPoint(fromHdiutilPlist: unmountedSample).isEmpty == true)
    }
}
