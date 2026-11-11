# CI results for 237cd8a

- Commit: 237cd8a4f5cb6688478b14e863cd036cf72abafd
- Run: https://github.com/nishan6/oncue/actions/runs/43090233513
- Date (UTC): 2026-11-11T19:49:21Z

| Step | Result |
| --- | --- |
| Generate project | success (project changed: true) |
| Package tests | success |
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
Test Case '-[OnCueCoreTests.EditingTests testAddShotsAtEndAfterAndInSection]' passed (0.001 seconds).
Test Case '-[OnCueCoreTests.EditingTests testAddSongsAndSegmentsInPlace]' passed (0.001 seconds).
Test Case '-[OnCueCoreTests.EditingTests testCamerasNumberingAndDeletion]' passed (0.001 seconds).
Test Case '-[OnCueCoreTests.EditingTests testDragReorderKeepsTimeSlots]' passed (0.001 seconds).
Test Case '-[OnCueCoreTests.EditingTests testMoveHelperMatchesSwiftUISemantics]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.EditingTests testMovingSectionsCarriesTheirShots]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.EditingTests testNudgeDuplicateEditDelete]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.EditingTests testOrderBasedItemsStayNumbered]' passed (0.001 seconds).
Test Case '-[OnCueCoreTests.EditingTests testRenameReorderDuplicateDelete]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.EditingTests testReorderWithinSectionOnly]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.EditingTests testSampleProductionSurvivesSaveAndReopen]' passed (0.008 seconds).
Test Case '-[OnCueCoreTests.EditingTests testScriptChecks]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.EditingTests testTimeBaseConversionKeepsTiming]' passed (0.000 seconds).
Test Suite 'EditingTests' passed at 2026-11-11 19:48:42.673.
	 Executed 14 tests, with 0 failures (0 unexpected) in 0.018 (0.019) seconds
Test Case '-[OnCueCoreTests.MachineProfileTests testCorruptProfileIsKeptAsBackupAndDefaultsUsed]' passed (0.005 seconds).
Test Case '-[OnCueCoreTests.MachineProfileTests testMissingProfileIsCreatedWithDefaults]' passed (0.002 seconds).
Test Case '-[OnCueCoreTests.MachineProfileTests testNewerProfileFormatIsNotOverwrittenInPlace]' passed (0.005 seconds).
Test Case '-[OnCueCoreTests.MachineProfileTests testOpeningAnotherShowDoesNotTouchTheProfile]' passed (0.007 seconds).
Test Case '-[OnCueCoreTests.MachineProfileTests testProfileChangesDoNotMutateShows]' passed (0.002 seconds).
Test Case '-[OnCueCoreTests.MachineProfileTests testProfileChangesPersistAcrossLaunches]' passed (0.003 seconds).
Test Case '-[OnCueCoreTests.MachineProfileTests testProfileMissingFieldsGetDefaults]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.MachineProfileTests testShowFilesCarryNoMachineSettings]' passed (0.004 seconds).
Test Suite 'MachineProfileTests' passed at 2026-11-11 19:48:42.704.
	 Executed 8 tests, with 0 failures (0 unexpected) in 0.031 (0.032) seconds
Test Case '-[OnCueCoreTests.ModelTests testBarsPositionsParseAndFormat]' passed (0.001 seconds).
Test Case '-[OnCueCoreTests.ModelTests testCameraLabels]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.ModelTests testEnsureShotTracksAddsTrackPerOutput]' passed (0.002 seconds).
Test Case '-[OnCueCoreTests.ModelTests testOrderPositions]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.ModelTests testSecondsFromBeats]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.ModelTests testSecondsPositionsParseAndFormat]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.ModelTests testSectionsAndEnds]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.ModelTests testStarterShow]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.ModelTests testTimecodeHelpers]' passed (0.000 seconds).
Test Suite 'ModelTests' passed at 2026-11-11 19:48:42.710.
	 Executed 9 tests, with 0 failures (0 unexpected) in 0.005 (0.006) seconds
Test Case '-[OnCueCoreTests.PersistenceTests testCorruptFileOnDiskIsNotModified]' passed (0.002 seconds).
Test Case '-[OnCueCoreTests.PersistenceTests testEmptyFileGivesClearError]' passed (0.001 seconds).
Test Case '-[OnCueCoreTests.PersistenceTests testEmptyObjectIsAnEmptyShow]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.PersistenceTests testEncodedFileCarriesCurrentSchemaVersion]' passed (0.001 seconds).
Test Case '-[OnCueCoreTests.PersistenceTests testEveryFieldSurvivesRoundTrip]' passed (0.001 seconds).
Test Case '-[OnCueCoreTests.PersistenceTests testFutureSchemaFileIsLeftUntouched]' passed (0.002 seconds).
Test Case '-[OnCueCoreTests.PersistenceTests testFutureSchemaIsRefusedWithClearError]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.PersistenceTests testGoldenFileResavesAsCurrentSchemaAndReopens]' passed (0.003 seconds).
Test Case '-[OnCueCoreTests.PersistenceTests testGoldenSchema0FileOpens]' passed (0.001 seconds).
Test Case '-[OnCueCoreTests.PersistenceTests testJSONArrayIsNotAShow]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.PersistenceTests testMissingFieldsGetDefaults]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.PersistenceTests testMissingFileGivesError]' passed (0.003 seconds).
Test Case '-[OnCueCoreTests.PersistenceTests testNonJSONGivesClearError]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.PersistenceTests testSaveCloseReopenOnDisk]' passed (0.003 seconds).
Test Case '-[OnCueCoreTests.PersistenceTests testStarterShowRoundTrips]' passed (0.002 seconds).
Test Case '-[OnCueCoreTests.PersistenceTests testUnknownEnumValuesFallBackSafely]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.PersistenceTests testWrongValueTypeNamesTheField]' passed (0.000 seconds).
Test Suite 'PersistenceTests' passed at 2026-11-11 19:48:42.734.
	 Executed 17 tests, with 0 failures (0 unexpected) in 0.022 (0.024) seconds
Test Suite 'OnCueCorePackageTests.xctest' passed at 2026-11-11 19:48:42.734.
	 Executed 48 tests, with 0 failures (0 unexpected) in 0.076 (0.080) seconds
Test Suite 'All tests' passed at 2026-11-11 19:48:42.734.
	 Executed 48 tests, with 0 failures (0 unexpected) in 0.076 (0.082) seconds
✔ Test run with 0 tests passed after 0.001 seconds.
```
## Build result
```
** BUILD FAILED **
/Users/runner/work/oncue/oncue/OnCue/Workspace/WorkspaceModel.swift:24:43: error: missing argument for parameter 'from' in call
```
## Warnings (0)
```
```
## Smoke test
```
```
