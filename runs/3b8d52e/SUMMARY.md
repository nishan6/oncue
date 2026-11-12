# CI results for 3b8d52e

- Commit: 3b8d52e76da9ae5303f929eae1e19d46c4611151
- Run: https://github.com/nishan6/oncue/actions/runs/43181626803
- Date (UTC): 2026-11-12T08:20:03Z

| Step | Result |
| --- | --- |
| Generate project | success (project changed: false) |
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
2026-11-12 08:19:36.921 appintentsmetadataprocessor[4415:16525] warning: Metadata extraction skipped. No AppIntents.framework dependency found.
```
## Smoke test
```
[smoke] app launched (pid 4515)
[smoke] machine profile created at /Users/runner/work/_temp/smoke/profile/MachineProfile.json
[smoke] new show opened (type com.nishanpani.oncue.show, windows: 1)
[smoke] saved to /Users/runner/work/_temp/smoke/smoke.oncue
[smoke] window closed
[smoke] saved file verified: format 1, 1 item(s), 4 camera(s)
[smoke] reopened smoke.oncue (windows: 1)
[smoke] PASS: create, save, close and reopen all succeeded
```
