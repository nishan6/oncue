# CI results for f777667

- Commit: f77766754797bc70705fda04bc22b114b2f71548
- Run: https://github.com/nishan6/oncue/actions/runs/43159174985
- Date (UTC): 2026-11-12T05:09:43Z

| Step | Result |
| --- | --- |
| Generate project | success (project changed: true) |
| Package tests | failure |
| App build | success |
| Launch smoke test | success |
| Screenshots | success |

## Toolchain
```
ProductName:		macOS
ProductVersion:		15.8.2
BuildVersion:		24H232
Xcode 16.4
Build version 16F6
swift-driver version: 1.120.5 Apple Swift version 6.1.2 (swiftlang-6.1.2.1.2 clang-1700.0.13.5)
Target: arm64-apple-macosx15.0
arm64
Version: 2.46.0
```
## Test summary
```
/Users/runner/work/oncue/oncue/Packages/OnCueCore/Tests/OnCueCoreTests/PersistenceTests.swift:218:92: error: extra arguments at positions #2, #3 in call
    |                                                                                            `- error: extra arguments at positions #2, #3 in call
/Users/runner/work/oncue/oncue/Packages/OnCueCore/Tests/OnCueCoreTests/PersistenceTests.swift:219:62: error: argument passed to call that takes no arguments
    |                                                              `- error: argument passed to call that takes no arguments
/Users/runner/work/oncue/oncue/Packages/OnCueCore/Tests/OnCueCoreTests/PersistenceTests.swift:220:62: error: argument passed to call that takes no arguments
    |                                                              `- error: argument passed to call that takes no arguments
/Users/runner/work/oncue/oncue/Packages/OnCueCore/Tests/OnCueCoreTests/PersistenceTests.swift:221:58: error: argument passed to call that takes no arguments
    |                                                          `- error: argument passed to call that takes no arguments
/Users/runner/work/oncue/oncue/Packages/OnCueCore/Tests/OnCueCoreTests/PersistenceTests.swift:222:59: error: argument passed to call that takes no arguments
    |                                                           `- error: argument passed to call that takes no arguments
/Users/runner/work/oncue/oncue/Packages/OnCueCore/Tests/OnCueCoreTests/PersistenceTests.swift:230:80: error: argument passed to call that takes no arguments
    |                                                                                `- error: argument passed to call that takes no arguments
/Users/runner/work/oncue/oncue/Packages/OnCueCore/Tests/OnCueCoreTests/PersistenceTests.swift:218:92: error: extra arguments at positions #2, #3 in call
    |                                                                                            `- error: extra arguments at positions #2, #3 in call
/Users/runner/work/oncue/oncue/Packages/OnCueCore/Tests/OnCueCoreTests/PersistenceTests.swift:219:62: error: argument passed to call that takes no arguments
    |                                                              `- error: argument passed to call that takes no arguments
/Users/runner/work/oncue/oncue/Packages/OnCueCore/Tests/OnCueCoreTests/PersistenceTests.swift:220:62: error: argument passed to call that takes no arguments
    |                                                              `- error: argument passed to call that takes no arguments
/Users/runner/work/oncue/oncue/Packages/OnCueCore/Tests/OnCueCoreTests/PersistenceTests.swift:221:58: error: argument passed to call that takes no arguments
    |                                                          `- error: argument passed to call that takes no arguments
/Users/runner/work/oncue/oncue/Packages/OnCueCore/Tests/OnCueCoreTests/PersistenceTests.swift:222:59: error: argument passed to call that takes no arguments
    |                                                           `- error: argument passed to call that takes no arguments
/Users/runner/work/oncue/oncue/Packages/OnCueCore/Tests/OnCueCoreTests/PersistenceTests.swift:230:80: error: argument passed to call that takes no arguments
    |                                                                                `- error: argument passed to call that takes no arguments
/Users/runner/work/oncue/oncue/Packages/OnCueCore/Tests/OnCueCoreTests/PersistenceTests.swift:218:92: error: extra arguments at positions #2, #3 in call
    |                                                                                            `- error: extra arguments at positions #2, #3 in call
/Users/runner/work/oncue/oncue/Packages/OnCueCore/Tests/OnCueCoreTests/PersistenceTests.swift:219:62: error: argument passed to call that takes no arguments
    |                                                              `- error: argument passed to call that takes no arguments
/Users/runner/work/oncue/oncue/Packages/OnCueCore/Tests/OnCueCoreTests/PersistenceTests.swift:220:62: error: argument passed to call that takes no arguments
    |                                                              `- error: argument passed to call that takes no arguments
/Users/runner/work/oncue/oncue/Packages/OnCueCore/Tests/OnCueCoreTests/PersistenceTests.swift:221:58: error: argument passed to call that takes no arguments
    |                                                          `- error: argument passed to call that takes no arguments
/Users/runner/work/oncue/oncue/Packages/OnCueCore/Tests/OnCueCoreTests/PersistenceTests.swift:222:59: error: argument passed to call that takes no arguments
    |                                                           `- error: argument passed to call that takes no arguments
/Users/runner/work/oncue/oncue/Packages/OnCueCore/Tests/OnCueCoreTests/PersistenceTests.swift:230:80: error: argument passed to call that takes no arguments
    |                                                                                `- error: argument passed to call that takes no arguments
error: fatalError
```
## Build result
```
** BUILD SUCCEEDED **
```
## Warnings (       2)
```
/Users/runner/work/oncue/oncue/Packages/OnCueCore/Sources/OnCueCore/Engine/SwitchLog.swift:84:60: warning: implicit capture of 'plain' requires that 'ISO8601DateFormatter' conforms to 'Sendable'; this is an error in the Swift 6 language mode
2026-11-12 05:09:19.977 appintentsmetadataprocessor[4222:15658] warning: Metadata extraction skipped. No AppIntents.framework dependency found.
```
## Smoke test
```
[smoke] app launched (pid 4238)
[smoke] machine profile created at /Users/runner/work/_temp/smoke/profile/MachineProfile.json
[smoke] new show opened (type com.nishanpani.oncue.show, windows: 1)
[smoke] saved to /Users/runner/work/_temp/smoke/smoke.oncue
[smoke] window closed
[smoke] saved file verified: format 1, 1 item(s), 4 camera(s)
[smoke] reopened smoke.oncue (windows: 1)
[smoke] PASS: create, save, close and reopen all succeeded
```
