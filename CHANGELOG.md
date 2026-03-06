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

- **Background script execution** (`ItemProcessing.swift`, `Shell.swift`, `Preferences.swift`): scripts whose filename begins with an underscore (e.g. `_my-task.sh`) are now dispatched concurrently on background threads while the remaining foreground scripts continue to execute sequentially. Outset waits for all background tasks to finish before it exits, so the overall run is not complete until every script has returned. Key details:
  - Background scripts are dispatched before foreground scripts begin, so they start immediately.
  - All log output from background scripts is tagged `[BG:pid=N]` and streamed line-by-line in real time, allowing background and foreground log lines to interleave naturally.
  - Run-once semantics are fully supported for background scripts; the run-once record is written only on successful exit, with thread-safe access via a serial dispatch queue.
  - A per-script timeout watchdog terminates a background script that exceeds the configured limit and logs an error.
  - A new optional preference key `background_script_timeout` (integer, seconds, no default) sets the per-script timeout. When not set, Outset waits indefinitely for background scripts to exit.

- **Ed25519 script signing** (`Checksum.swift`, `ItemProcessing.swift`, `Preferences.swift`, `Outset.swift`): scripts can now be signed with an Ed25519 private key, with the signature embedded directly in the script as a `# ed25519: <base64sig>` comment. When an MDM-delivered public key (`manifest_signing_key` preference) is present, every script must carry a valid embedded signature — scripts without a valid signature are refused with an error log. Key details:
  - The signed payload is the script content with any existing `# ed25519:` comment line stripped, so the signature is stable across re-signing.
  - The public key is delivered via MDM only (as a base64-encoded 32-byte raw Ed25519 key in `manifest_signing_key`). The private key never leaves the admin workstation.
  - Signing is fully self-contained: scripts with embedded signatures are version-control friendly and require no separate manifest file.
  - Applies to all script processing paths including MDM payload scripts (which carry their embedded signature in the base64-encoded script body).
  - New CLI commands: `--generate-keypair` generates a fresh Ed25519 keypair and prints both keys; `--sign-script-file <path> --signing-key <private-key-base64>` signs one or more scripts in place.

## [4.0] - 2023-03-23
### Added
- Initial automated build of Outset
