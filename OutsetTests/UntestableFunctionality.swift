//
//  UntestableFunctionality.swift
//  OutsetTests
//
//  Documents functions and behaviours that are not covered by automated tests,
//  with the reason why each is excluded. This is intentionally a source file
//  rather than a comment so it stays visible in the project navigator and is
//  reviewed alongside the tests.
//
//  Reasons are grouped into categories:
//
//  REQUIRES_ROOT
//      The function calls ensureRoot(), installs packages via /usr/sbin/installer,
//      writes to /Library/Preferences via CFPreferences with kCFPreferencesAnyUser,
//      or otherwise requires the process to be running as uid 0. Tests run as the
//      current user and cannot satisfy this requirement without a privileged helper,
//      which is out of scope for a unit test bundle.
//
//  REQUIRES_FILESYSTEM_FIXTURE
//      The function operates on the real Outset working directories
//      (/usr/local/outset/boot-once, /login-once, etc.) which do not exist in a
//      test environment and cannot be created without root. Mocking the path is
//      possible via PayloadType.updateOutsetDirectory() but the functions also
//      call verifyPermissions() which checks that files are owned by root (uid 0),
//      so even with a custom directory the permission check would fail for any
//      file created by a non-root test process.
//
//  REQUIRES_REAL_SHELL
//      The function executes external binaries (/bin/sh, /usr/sbin/installer,
//      /usr/bin/hdiutil) whose behaviour cannot be controlled or observed from
//      within the test process. Outcomes depend on the host environment and
//      would require integration test infrastructure (real packages, disk images)
//      rather than unit tests.
//
//  REQUIRES_SYSTEM_STATE
//      The function queries or modifies live system state: the SCDynamicStore
//      console user, NSUserName(), launchd service registration via SMAppService,
//      or the login window state via a privileged shell command. These cannot be
//      reliably set to known values in a test environment.
//
//  REQUIRES_MDM
//      The function reads CFPreferences values that are only "forced" when
//      delivered by an MDM profile. CFPreferencesAppValueIsForced() always
//      returns false in a user session without a profile applied, so the managed
//      payload processing path can never be exercised in a unit test.
//
//  SIDE_EFFECTS_ONLY
//      The function has no return value and its only observable effect is a
//      log entry (to os_log and a file on disk). Verifying log output would
//      require intercepting os_log or reading the log file after the fact, which
//      is fragile and provides low signal.
//
// ─────────────────────────────────────────────────────────────────────────────
//
// ITEMPROCESSING
//
// processItems(_:consoleUser:deleteItems:once:override:)
//   REQUIRES_FILESYSTEM_FIXTURE, REQUIRES_ROOT
//   Calls folderContents() on a PayloadType directory that must exist and be
//   root-owned, then calls verifyPermissions() which requires uid 0 ownership.
//   Would exit(1) if the directory does not exist.
//
// processPackages(packages:once:override:deleteItems:)
//   REQUIRES_ROOT, REQUIRES_REAL_SHELL
//   Calls installPackage() which requires root and invokes /usr/sbin/installer.
//
// processScripts(scripts:consoleUser:altName:once:override:deleteItems:)
//   REQUIRES_REAL_SHELL
//   Executes scripts via /bin/sh. The run-once tracking logic (the part worth
//   testing) is tightly coupled to loadRunOncePlist()/writeRunOncePlist() which
//   write to CFPreferences with kCFPreferencesAnyUser (requiring root) or to
//   UserDefaults in the app's bundle domain. Isolating just the tracking logic
//   would require extracting it into a separately testable function.
//
// ─────────────────────────────────────────────────────────────────────────────
//
// BOOT
//
// processBootTasks(prefs:)
//   REQUIRES_ROOT, REQUIRES_FILESYSTEM_FIXTURE, REQUIRES_SYSTEM_STATE
//   Calls ensureWorkingFolders() (requires root to create /usr/local/outset/),
//   writeOutsetPreferences() (requires root for CFPreferences write),
//   loginWindowUpdateState() (runs a privileged shell command), and
//   processItems() (requires root-owned filesystem fixtures).
//
// ─────────────────────────────────────────────────────────────────────────────
//
// LOGIN
//
// processLoginWindowTasks(payload:)
//   REQUIRES_FILESYSTEM_FIXTURE
//   Calls processItems(.loginWindow, consoleUser: "") which requires the
//   login-window directory to exist and contain root-owned files.
//
// processLoginTasks(consoleUser:payload:prefs:)
//   REQUIRES_FILESYSTEM_FIXTURE
//   The ignored-user skip path is tested via runIfNotIgnoredUser (covered).
//   The processing path calls processItems() which requires root-owned fixtures.
//   The privileged trigger creation path calls createTrigger() at a real path
//   in /private/tmp/ — this could be tested in isolation but is currently not.
//
// processLoginPrivilegedTasks(consoleUser:payload:prefs:)
//   REQUIRES_FILESYSTEM_FIXTURE, REQUIRES_ROOT
//
// processLoginEveryTasks(consoleUser:payload:prefs:)
//   REQUIRES_FILESYSTEM_FIXTURE
//
// processLoginOnceTasks(consoleUser:payload:prefs:)
//   REQUIRES_FILESYSTEM_FIXTURE
//
// ─────────────────────────────────────────────────────────────────────────────
//
// ON-DEMAND
//
// processOnDemandTasks(consoleUser:)
//   REQUIRES_SYSTEM_STATE, REQUIRES_FILESYSTEM_FIXTURE
//   The user-session guard uses NSUserName() to compare against the injected
//   consoleUser. NSUserName() returns the actual running user and cannot be
//   overridden. The processing path requires root-owned filesystem fixtures.
//
// processOnDemandPrivilegedTasks(consoleUser:)
//   REQUIRES_ROOT, REQUIRES_FILESYSTEM_FIXTURE
//
// ─────────────────────────────────────────────────────────────────────────────
//
// PACKAGES / DMG
//
// installPackage(pkg:)
//   REQUIRES_ROOT, REQUIRES_REAL_SHELL
//   Invokes /usr/sbin/installer. Requires root and a real .pkg or .dmg fixture.
//
// mountDmg(dmg:) / detachDmg(dmgMount:)
//   REQUIRES_REAL_SHELL
//   Invokes /usr/bin/hdiutil. Requires a real disk image file.
//
// ─────────────────────────────────────────────────────────────────────────────
//
// SHELL
//
// runShellCommand(_:args:verbose:)
//   REQUIRES_REAL_SHELL
//   Executes arbitrary shell commands. Could be tested with a benign command
//   (e.g. /bin/echo) but this would be testing Process/Pipe rather than Outset
//   logic. Not currently covered.
//
// ─────────────────────────────────────────────────────────────────────────────
//
// PERMISSIONS
//
// verifyPermissions(pathname:)
//   REQUIRES_ROOT
//   Checks that files are owned by root (uid 0). Any file created by a test
//   process is owned by the test user, so the check will always fail and the
//   function will always return false. Cannot be meaningfully tested without
//   a root-owned file fixture.
//
// getFileProperties(pathname:)
//   REQUIRES_ROOT (for useful values)
//   Can be called on any file, but the ownerID will never be 0 in a test
//   environment so only error paths are reachable.
//
// ─────────────────────────────────────────────────────────────────────────────
//
// PREFERENCES (runtime read/write)
//
// loadOutsetPreferences() / writeOutsetPreferences(prefs:)
//   REQUIRES_ROOT
//   The root path writes to /Library/Preferences via CFPreferences with
//   kCFPreferencesAnyUser/kCFPreferencesAnyHost, requiring uid 0. The non-root
//   path writes to UserDefaults in the app bundle domain, which will pollute the
//   test environment's preferences. The struct encoding/decoding is covered
//   separately in PreferencesTests.swift.
//
// loadRunOncePlist(bootOnce:) / writeRunOncePlist(runOnceData:bootOnce:)
//   REQUIRES_ROOT (for boot-once path)
//   The non-root path writes to UserDefaults and would leave persistent state
//   between test runs. The boot-once path requires root for CFPreferences.
//
// ─────────────────────────────────────────────────────────────────────────────
//
// PAYLOAD PROCESSING
//
// ScriptPayloads.processPayloadScripts(ofType:consoleUser:runOnceData:)
//   REQUIRES_MDM, REQUIRES_REAL_SHELL
//   The managed payload path requires CFPreferencesAppValueIsForced() to return
//   true, which only happens under an MDM profile. The debug path (unmanaged)
//   could be exercised by setting debugMode = true, but the decoded script would
//   still be executed via runShellCommand() against the real shell.
//
// ─────────────────────────────────────────────────────────────────────────────
//
// NETWORK
//
// isNetworkUp() / waitForNetworkUp(timeout:)
//   REQUIRES_SYSTEM_STATE
//   isNetworkUp() queries SCNetworkReachability which reflects live network
//   state. waitForNetworkUp() busy-polls with real sleeps. Neither can be
//   driven to a deterministic outcome in a unit test without mocking the
//   network stack.
//
// ─────────────────────────────────────────────────────────────────────────────
//
// SYSTEM INFO
//
// getConsoleUserInfo()
//   REQUIRES_SYSTEM_STATE
//   Queries SCDynamicStoreCopyConsoleUser, which returns the currently logged-in
//   user. Returns whatever user is at the console when tests run.
//
// ─────────────────────────────────────────────────────────────────────────────
//
// SERVICES (macOS 13+)
//
// ServiceManager.registerDaemons() / removeDaemons() / getStatus()
//   REQUIRES_ROOT, REQUIRES_SYSTEM_STATE
//   Uses SMAppService which requires root for daemon registration and reflects
//   live launchd state. Cannot be tested in a unit test environment.
//
// ─────────────────────────────────────────────────────────────────────────────
//
// LOGGING
//
// writeLog(_:logLevel:log:) / writeFileLog(message:logLevel:)
//   SIDE_EFFECTS_ONLY
//   Writes to os_log and to a log file at a hardcoded path. The log file path
//   is /usr/local/outset/logs/outset.log which requires root to write to in a
//   production environment.
//
// performLogRotation(logFolderPath:logFileBaseName:maxLogFiles:)
//   SIDE_EFFECTS_ONLY, REQUIRES_ROOT (for production path)
//   Could be tested with a temp directory but the observable outcome is only
//   file existence/absence, providing limited signal over what folderContents
//   tests already cover.
//
// ─────────────────────────────────────────────────────────────────────────────
//
// LEGACY
//
// migrateLegacyPreferences()
//   REQUIRES_ROOT
//   Reads from and writes to system-level CFPreferences domains. Would leave
//   persistent state on the test machine.

// This file intentionally contains no executable code.
