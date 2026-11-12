# CI results for 25d02a5

- Commit: 25d02a5bd3a91f8cddf0c4d4dfedb60550e483c5
- Run: https://github.com/nishan6/oncue/actions/runs/43181949770
- Date (UTC): 2026-11-12T08:21:27Z

| Step | Result |
| --- | --- |
| Generate project | success (project changed: true) |
| Package tests | failure |
| App build | failure |
| Launch smoke test | skipped |
| Screenshots | skipped |

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
error: emit-module command failed with exit code 1 (use -v to see invocation)
/Users/runner/work/oncue/oncue/Packages/OnCueCore/Sources/OnCueCore/Model/Model.swift:468:15: error: type 'Show' does not conform to protocol 'Hashable'
    |               `- error: type 'Show' does not conform to protocol 'Hashable'
/Users/runner/work/oncue/oncue/Packages/OnCueCore/Sources/OnCueCore/Model/Model.swift:468:15: error: type 'Show' does not conform to protocol 'Hashable'
    |               `- error: type 'Show' does not conform to protocol 'Hashable'
/Users/runner/work/oncue/oncue/Packages/OnCueCore/Sources/OnCueCore/Model/Model.swift:468:15: error: type 'Show' does not conform to protocol 'Hashable'
    |               `- error: type 'Show' does not conform to protocol 'Hashable'
/Users/runner/work/oncue/oncue/Packages/OnCueCore/Sources/OnCueCore/Model/Model.swift:468:15: error: type 'Show' does not conform to protocol 'Hashable'
    |               `- error: type 'Show' does not conform to protocol 'Hashable'
/Users/runner/work/oncue/oncue/Packages/OnCueCore/Sources/OnCueCore/Model/Model.swift:468:15: error: type 'Show' does not conform to protocol 'Hashable'
    |               `- error: type 'Show' does not conform to protocol 'Hashable'
/Users/runner/work/oncue/oncue/Packages/OnCueCore/Sources/OnCueCore/Model/Model.swift:468:15: error: type 'Show' does not conform to protocol 'Hashable'
    |               `- error: type 'Show' does not conform to protocol 'Hashable'
/Users/runner/work/oncue/oncue/Packages/OnCueCore/Sources/OnCueCore/Model/Model.swift:468:15: error: type 'Show' does not conform to protocol 'Hashable'
    |               `- error: type 'Show' does not conform to protocol 'Hashable'
/Users/runner/work/oncue/oncue/Packages/OnCueCore/Sources/OnCueCore/Model/Model.swift:468:15: error: type 'Show' does not conform to protocol 'Hashable'
    |               `- error: type 'Show' does not conform to protocol 'Hashable'
/Users/runner/work/oncue/oncue/Packages/OnCueCore/Sources/OnCueCore/Model/Model.swift:468:15: error: type 'Show' does not conform to protocol 'Hashable'
    |               `- error: type 'Show' does not conform to protocol 'Hashable'
/Users/runner/work/oncue/oncue/Packages/OnCueCore/Sources/OnCueCore/Model/Model.swift:468:15: error: type 'Show' does not conform to protocol 'Hashable'
    |               `- error: type 'Show' does not conform to protocol 'Hashable'
error: fatalError
```
## Build result
```
** BUILD FAILED **
/Users/runner/work/oncue/oncue/Packages/OnCueCore/Sources/OnCueCore/Model/Model.swift:468:15: error: type 'Show' does not conform to protocol 'Hashable'
```
## Warnings (0)
```
```
## Smoke test
```
```
