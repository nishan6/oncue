# CI results for 17a1eed

- Commit: 17a1eedf246ad266ec15da07e5e389e787dc1ae8
- Run: https://github.com/nishan6/oncue/actions/runs/43163323559
- Date (UTC): 2026-11-12T05:47:33Z

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
/Users/runner/work/oncue/oncue/Packages/OnCueCore/Tests/OnCueCoreTests/PreShowCheckTests.swift:43:9: error: overlapping accesses to 'show', but modification requires exclusive access; consider copying to a local variable
    |         `- error: overlapping accesses to 'show', but modification requires exclusive access; consider copying to a local variable
/Users/runner/work/oncue/oncue/Packages/OnCueCore/Tests/OnCueCoreTests/PreShowCheckTests.swift:43:9: error: overlapping accesses to 'show', but modification requires exclusive access; consider copying to a local variable
    |         `- error: overlapping accesses to 'show', but modification requires exclusive access; consider copying to a local variable
/Users/runner/work/oncue/oncue/Packages/OnCueCore/Tests/OnCueCoreTests/PreShowCheckTests.swift:43:9: error: overlapping accesses to 'show', but modification requires exclusive access; consider copying to a local variable
    |         `- error: overlapping accesses to 'show', but modification requires exclusive access; consider copying to a local variable
/Users/runner/work/oncue/oncue/Packages/OnCueCore/Tests/OnCueCoreTests/PreShowCheckTests.swift:43:9: error: overlapping accesses to 'show', but modification requires exclusive access; consider copying to a local variable
    |         `- error: overlapping accesses to 'show', but modification requires exclusive access; consider copying to a local variable
error: fatalError
```
## Build result
```
** BUILD SUCCEEDED **
```
## Warnings (       1)
```
2026-11-12 05:47:08.880 appintentsmetadataprocessor[6244:22437] warning: Metadata extraction skipped. No AppIntents.framework dependency found.
```
## Smoke test
```
[smoke] app launched (pid 6261)
[smoke] machine profile created at /Users/runner/work/_temp/smoke/profile/MachineProfile.json
[smoke] new show opened (type com.nishanpani.oncue.show, windows: 1)
[smoke] saved to /Users/runner/work/_temp/smoke/smoke.oncue
[smoke] window closed
[smoke] saved file verified: format 1, 1 item(s), 4 camera(s)
[smoke] reopened smoke.oncue (windows: 1)
[smoke] PASS: create, save, close and reopen all succeeded
```
