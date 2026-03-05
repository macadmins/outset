# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [4.3.0] - 2026-03-05

### Fixed

- **DMG package installation** (`installPackage`): corrected a variable assignment bug where the DMG mount path was used as the package path instead of the actual `.pkg`/`.mpkg` file path. Also fixed a loop that overwrote a single variable on each iteration, meaning only the last package in a DMG was ever installed. Packages found inside a mounted DMG are now collected into an array and each is installed in turn. The DMG is detached synchronously after all packages have been processed (no change in behaviour — `runShellCommand` has always been synchronous).

- **Network timeout** (`Boot.swift`): the configured `network_timeout` preference value was being divided by 10 before being passed to `waitForNetworkUp`, causing the actual wait to be ten times shorter than configured. For example, a configured value of 300 seconds would only wait 30 seconds. The value is now passed directly.

- **Privileged login trigger** (`Login.swift`): the condition that fires the `login-privileged` launchd trigger used `||` (OR) instead of `&&` (AND), meaning the trigger would only fire when *both* the `login-privileged-once` and `login-privileged-every` directories were non-empty. The corrected condition fires the trigger when *either* directory has content.

- **Array bounds crash** (`computeChecksum`): accessing `files[0]` before checking whether the array was empty could cause an index-out-of-bounds crash when called with an empty argument list. An early return guard has been added.

- **Log file permissions** (`writeFileLog`): newly created log files were given world-writable permissions (`0o666`). Permissions are now `0o644`.

- **Force unwraps** (`writeFileLog`, `runShellCommand`): force-unwrapped `String(data:encoding:)` and `Data(string.utf8)` calls have been replaced with nil-coalescing fallbacks, removing potential crash points if encoding unexpectedly fails.

### Changed

- **Console user is no longer a global variable**: `consoleUser` was previously stored as a mutable global, making it difficult to reason about and impossible to substitute in tests. It is now captured once at startup in `Outset.run()` and passed explicitly through the call chain to all functions that require it (`processLoginTasks`, `processLoginPrivilegedTasks`, `processLoginEveryTasks`, `processLoginOnceTasks`, `processOnDemandTasks`, `processOnDemandPrivilegedTasks`, `processItems`, `processScripts`, `processPayloadScripts`). Two additional globals that were only ever used inside `Boot.swift` (`loginwindowState`, `continueFirstBoot`) have been moved to local variables in that file.

### Added

- **Unit test target** (`OutsetTests`): a new `OutsetTests` test target has been added to the Xcode project using Swift Testing (`@Suite`, `@Test`, `#expect`). 27 tests cover:
  - `runIfNotIgnoredUser` — ignored-user skip logic and action execution
  - `checkFileExists` / `checkDirectoryExists` / `folderContents` — core file utilities
  - `createTrigger` / `pathCleanup` — trigger file creation and directory cleanup
  - `sha256` / `verifySHASUMForFile` / `computeChecksum` — checksum utilities including the empty-array guard
  - `OutsetPreferences` — default values, `CodingKeys` names, and JSON round-trip

- **Test coverage documentation** (`UntestableFunctionality.swift`): a source file in the test target documents every function not covered by automated tests, with a specific reason for each exclusion (`REQUIRES_ROOT`, `REQUIRES_FILESYSTEM_FIXTURE`, `REQUIRES_REAL_SHELL`, `REQUIRES_SYSTEM_STATE`, `REQUIRES_MDM`, `SIDE_EFFECTS_ONLY`).

## [4.0] - 2023-03-23
### Added
- Initial automated build of Outset
