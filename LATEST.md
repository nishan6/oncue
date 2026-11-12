# CI results for 6064c8c

- Commit: 6064c8c98f25eac67331ac29e84a02794978471c
- Run: https://github.com/nishan6/oncue/actions/runs/43332252785
- Date (UTC): 2026-11-12T23:56:42Z

| Step | Result |
| --- | --- |
| Generate project | success (project changed: true) |
| Package tests | failure |
| App build | failure |
| Launch smoke test | skipped |
| Screenshots | skipped |
| DMG | skipped |

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
/Users/runner/work/oncue/oncue/Packages/OnCueCore/Tests/OnCueCoreTests/MediaPoolTests.swift:25:33: error: 'nil' is not compatible with expected argument type 'UUID'
   |                                 `- error: 'nil' is not compatible with expected argument type 'UUID'
/Users/runner/work/oncue/oncue/Packages/OnCueCore/Tests/OnCueCoreTests/MediaPoolTests.swift:25:33: error: 'nil' is not compatible with expected argument type 'UUID'
   |                                 `- error: 'nil' is not compatible with expected argument type 'UUID'
/Users/runner/work/oncue/oncue/Packages/OnCueCore/Tests/OnCueCoreTests/MediaPoolTests.swift:25:33: error: 'nil' is not compatible with expected argument type 'UUID'
   |                                 `- error: 'nil' is not compatible with expected argument type 'UUID'
/Users/runner/work/oncue/oncue/Packages/OnCueCore/Tests/OnCueCoreTests/MediaPoolTests.swift:25:33: error: 'nil' is not compatible with expected argument type 'UUID'
   |                                 `- error: 'nil' is not compatible with expected argument type 'UUID'
/Users/runner/work/oncue/oncue/Packages/OnCueCore/Tests/OnCueCoreTests/MediaPoolTests.swift:25:33: error: 'nil' is not compatible with expected argument type 'UUID'
   |                                 `- error: 'nil' is not compatible with expected argument type 'UUID'
/Users/runner/work/oncue/oncue/Packages/OnCueCore/Tests/OnCueCoreTests/MediaPoolTests.swift:25:33: error: 'nil' is not compatible with expected argument type 'UUID'
   |                                 `- error: 'nil' is not compatible with expected argument type 'UUID'
/Users/runner/work/oncue/oncue/Packages/OnCueCore/Tests/OnCueCoreTests/MediaPoolTests.swift:25:33: error: 'nil' is not compatible with expected argument type 'UUID'
   |                                 `- error: 'nil' is not compatible with expected argument type 'UUID'
/Users/runner/work/oncue/oncue/Packages/OnCueCore/Tests/OnCueCoreTests/MediaPoolTests.swift:25:33: error: 'nil' is not compatible with expected argument type 'UUID'
   |                                 `- error: 'nil' is not compatible with expected argument type 'UUID'
/Users/runner/work/oncue/oncue/Packages/OnCueCore/Tests/OnCueCoreTests/MediaPoolTests.swift:25:33: error: 'nil' is not compatible with expected argument type 'UUID'
   |                                 `- error: 'nil' is not compatible with expected argument type 'UUID'
error: fatalError
```
## Build result
```
** BUILD FAILED **
/Users/runner/work/oncue/oncue/OnCue/Workspace/ShowWorkspaceView.swift:12:25: error: the compiler is unable to type-check this expression in reasonable time; try breaking up the expression into distinct sub-expressions
```
## Warnings (0)
```
```
## Smoke test
```
```
## DMG
```
```
