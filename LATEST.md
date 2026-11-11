# CI results for 7b15fe8

- Commit: 7b15fe87a0bf2d05856c01047d8dcf257fd39735
- Run: https://github.com/nishan6/oncue/actions/runs/43092801327
- Date (UTC): 2026-11-11T20:04:01Z

| Step | Result |
| --- | --- |
| Generate project | success (project changed: false) |
| Package tests | success |
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
Test Case '-[OnCueCoreTests.EditingTests testAddShotsAtEndAfterAndInSection]' passed (0.001 seconds).
Test Case '-[OnCueCoreTests.EditingTests testAddSongsAndSegmentsInPlace]' passed (0.001 seconds).
Test Case '-[OnCueCoreTests.EditingTests testCamerasNumberingAndDeletion]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.EditingTests testDragReorderKeepsTimeSlots]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.EditingTests testMoveHelperMatchesSwiftUISemantics]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.EditingTests testMovingSectionsCarriesTheirShots]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.EditingTests testNudgeDuplicateEditDelete]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.EditingTests testOrderBasedItemsStayNumbered]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.EditingTests testRenameReorderDuplicateDelete]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.EditingTests testReorderWithinSectionOnly]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.EditingTests testSampleProductionSurvivesSaveAndReopen]' passed (0.005 seconds).
Test Case '-[OnCueCoreTests.EditingTests testScriptChecks]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.EditingTests testTimeBaseConversionKeepsTiming]' passed (0.000 seconds).
Test Suite 'EditingTests' passed at 2026-11-11 20:03:17.822.
	 Executed 14 tests, with 0 failures (0 unexpected) in 0.012 (0.012) seconds
Test Case '-[OnCueCoreTests.MachineProfileTests testCorruptProfileIsKeptAsBackupAndDefaultsUsed]' passed (0.002 seconds).
Test Case '-[OnCueCoreTests.MachineProfileTests testMissingProfileIsCreatedWithDefaults]' passed (0.001 seconds).
Test Case '-[OnCueCoreTests.MachineProfileTests testNewerProfileFormatIsNotOverwrittenInPlace]' passed (0.001 seconds).
Test Case '-[OnCueCoreTests.MachineProfileTests testOpeningAnotherShowDoesNotTouchTheProfile]' passed (0.002 seconds).
Test Case '-[OnCueCoreTests.MachineProfileTests testProfileChangesDoNotMutateShows]' passed (0.001 seconds).
Test Case '-[OnCueCoreTests.MachineProfileTests testProfileChangesPersistAcrossLaunches]' passed (0.001 seconds).
Test Case '-[OnCueCoreTests.MachineProfileTests testProfileMissingFieldsGetDefaults]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.MachineProfileTests testShowFilesCarryNoMachineSettings]' passed (0.003 seconds).
Test Suite 'MachineProfileTests' passed at 2026-11-11 20:03:17.834.
	 Executed 8 tests, with 0 failures (0 unexpected) in 0.012 (0.012) seconds
Test Case '-[OnCueCoreTests.ModelTests testBarsPositionsParseAndFormat]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.ModelTests testCameraLabels]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.ModelTests testEnsureShotTracksAddsTrackPerOutput]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.ModelTests testOrderPositions]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.ModelTests testSecondsFromBeats]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.ModelTests testSecondsPositionsParseAndFormat]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.ModelTests testSectionsAndEnds]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.ModelTests testStarterShow]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.ModelTests testTimecodeHelpers]' passed (0.000 seconds).
Test Suite 'ModelTests' passed at 2026-11-11 20:03:17.835.
	 Executed 9 tests, with 0 failures (0 unexpected) in 0.001 (0.002) seconds
Test Case '-[OnCueCoreTests.PersistenceTests testCorruptFileOnDiskIsNotModified]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.PersistenceTests testEmptyFileGivesClearError]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.PersistenceTests testEmptyObjectIsAnEmptyShow]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.PersistenceTests testEncodedFileCarriesCurrentSchemaVersion]' passed (0.001 seconds).
Test Case '-[OnCueCoreTests.PersistenceTests testEveryFieldSurvivesRoundTrip]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.PersistenceTests testFutureSchemaFileIsLeftUntouched]' passed (0.001 seconds).
Test Case '-[OnCueCoreTests.PersistenceTests testFutureSchemaIsRefusedWithClearError]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.PersistenceTests testGoldenFileResavesAsCurrentSchemaAndReopens]' passed (0.001 seconds).
Test Case '-[OnCueCoreTests.PersistenceTests testGoldenSchema0FileOpens]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.PersistenceTests testJSONArrayIsNotAShow]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.PersistenceTests testMissingFieldsGetDefaults]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.PersistenceTests testMissingFileGivesError]' passed (0.001 seconds).
Test Case '-[OnCueCoreTests.PersistenceTests testNonJSONGivesClearError]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.PersistenceTests testSaveCloseReopenOnDisk]' passed (0.001 seconds).
Test Case '-[OnCueCoreTests.PersistenceTests testStarterShowRoundTrips]' passed (0.001 seconds).
Test Case '-[OnCueCoreTests.PersistenceTests testUnknownEnumValuesFallBackSafely]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.PersistenceTests testWrongValueTypeNamesTheField]' passed (0.000 seconds).
Test Suite 'PersistenceTests' passed at 2026-11-11 20:03:17.844.
	 Executed 17 tests, with 0 failures (0 unexpected) in 0.008 (0.008) seconds
Test Suite 'OnCueCorePackageTests.xctest' passed at 2026-11-11 20:03:17.844.
	 Executed 48 tests, with 0 failures (0 unexpected) in 0.033 (0.034) seconds
Test Suite 'All tests' passed at 2026-11-11 20:03:17.844.
	 Executed 48 tests, with 0 failures (0 unexpected) in 0.033 (0.035) seconds
✔ Test run with 0 tests passed after 0.001 seconds.
```
## Build result
```
** BUILD SUCCEEDED **
```
## Warnings (       1)
```
2026-11-11 20:03:46.464 appintentsmetadataprocessor[1646:8391] warning: Metadata extraction skipped. No AppIntents.framework dependency found.
```
## Smoke test
```
[smoke] app launched (pid 1660)
[smoke] machine profile created at /Users/runner/work/_temp/smoke/profile/MachineProfile.json
[smoke] new show opened (type com.nishanpani.oncue.show, windows: 1)
[smoke] saved to /Users/runner/work/_temp/smoke/smoke.oncue
[smoke] window closed
[smoke] saved file verified: format 1, 1 item(s), 4 camera(s)
[smoke] reopened smoke.oncue (windows: 1)
[smoke] PASS: create, save, close and reopen all succeeded
```
