# CI results for 169cf21

- Commit: 169cf2185457474858dc5946d3864d4d99ecb5a8
- Run: https://github.com/nishan6/oncue/actions/runs/43246062410
- Date (UTC): 2026-11-12T15:27:11Z

| Step | Result |
| --- | --- |
| Generate project | success (project changed: true) |
| Package tests | failure |
| App build | success |
| Launch smoke test | success |
| Screenshots | success |
| DMG | success |

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
Test Case '-[OnCueCoreTests.MTCTests testFullFrame]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.MTCTests testOutOfOrderPiecesAreIgnored]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.MTCTests testQuarterFramesGiveTimeTwoFramesOn]' passed (0.000 seconds).
Test Suite 'MTCTests' passed at 2026-11-12 15:19:07.111.
	 Executed 3 tests, with 0 failures (0 unexpected) in 0.000 (0.000) seconds
Test Case '-[OnCueCoreTests.MachineProfileTests testCorruptProfileIsKeptAsBackupAndDefaultsUsed]' passed (0.012 seconds).
Test Case '-[OnCueCoreTests.MachineProfileTests testMissingProfileIsCreatedWithDefaults]' passed (0.001 seconds).
Test Case '-[OnCueCoreTests.MachineProfileTests testNewerProfileFormatIsNotOverwrittenInPlace]' passed (0.002 seconds).
Test Case '-[OnCueCoreTests.MachineProfileTests testOpeningAnotherShowDoesNotTouchTheProfile]' passed (0.003 seconds).
Test Case '-[OnCueCoreTests.MachineProfileTests testProfileChangesDoNotMutateShows]' passed (0.002 seconds).
Test Case '-[OnCueCoreTests.MachineProfileTests testProfileChangesPersistAcrossLaunches]' passed (0.001 seconds).
Test Case '-[OnCueCoreTests.MachineProfileTests testProfileMissingFieldsGetDefaults]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.MachineProfileTests testShowFilesCarryNoMachierror: Exited with unexpected signal code 5
Test Case '-[OnCueCoreTests.MachineProfileTests testShowFilesCarryNoMachineSettings]' passed (0.004 seconds).
Test Suite 'MachineProfileTests' passed at 2026-11-12 15:19:07.136.
	 Executed 8 tests, with 0 failures (0 unexpected) in 0.025 (0.026) seconds
Test Case '-[OnCueCoreTests.MediaTests testMediaSurvivesSaving]' passed (0.001 seconds).
Test Case '-[OnCueCoreTests.MediaTests testMediaTimeMapping]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.MediaTests testWaveformPeaks]' passed (0.188 seconds).
Test Suite 'MediaTests' passed at 2026-11-12 15:19:07.326.
	 Executed 3 tests, with 0 failures (0 unexpected) in 0.189 (0.189) seconds
Test Case '-[OnCueCoreTests.ModelTests testBarsPositionsParseAndFormat]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.ModelTests testCameraLabels]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.ModelTests testEnsureShotTracksAddsTrackPerOutput]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.ModelTests testOrderPositions]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.ModelTests testSecondsFromBeats]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.ModelTests testSecondsPositionsParseAndFormat]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.ModelTests testSectionsAndEnds]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.ModelTests testStarterShow]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.ModelTests testTimecodeHelpers]' passed (0.000 seconds).
Test Suite 'ModelTests' passed at 2026-11-12 15:19:07.327.
	 Executed 9 tests, with 0 failures (0 unexpected) in 0.001 (0.002) seconds
Test Case '-[OnCueCoreTests.PersistenceTests testCorruptFileOnDiskIsNotModified]' passed (0.001 seconds).
Test Case '-[OnCueCoreTests.PersistenceTests testEmptyFileGivesClearError]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.PersistenceTests testEmptyObjectIsAnEmptyShow]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.PersistenceTests testEncodedFileCarriesCurrentSchemaVersion]' passed (0.001 seconds).
Test Case '-[OnCueCoreTests.PersistenceTests testEveryFieldSurvivesRoundTrip]' passed (0.001 seconds).
Test Case '-[OnCueCoreTests.PersistenceTests testFutureSchemaFileIsLeftUntouched]' passed (0.001 seconds).
Test Case '-[OnCueCoreTests.PersistenceTests testFutureSchemaIsRefusedWithClearError]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.PersistenceTests testGoldenFileResavesAsCurrentSchemaAndReopens]' passed (0.001 seconds).
Test Case '-[OnCueCoreTests.PersistenceTests testGoldenSchema0FileOpens]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.PersistenceTests testJSONArrayIsNotAShow]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.PersistenceTests testMissingFieldsGetDefaults]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.PersistenceTests testMissingFileGivesError]' passed (0.001 seconds).
Test Case '-[OnCueCoreTests.PersistenceTests testNonJSONGivesClearError]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.PersistenceTests testSaveCloseReopenOnDisk]' passed (0.002 seconds).
Test Case '-[OnCueCoreTests.PersistenceTests testStarterShowRoundTrips]' passed (0.001 seconds).
Test Case '-[OnCueCoreTests.PersistenceTests testUnknownEnumValuesFallBackSafely]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.PersistenceTests testWrongValueTypeNamesTheField]' passed (0.000 seconds).
Test Suite 'PersistenceTests' passed at 2026-11-12 15:19:07.338.
	 Executed 17 tests, with 0 failures (0 unexpected) in 0.010 (0.011) seconds
Test Case '-[OnCueCoreTests.PreShowCheckTests testATEMThatAnswersAndOneThatDoesnt]' passed (1.531 seconds).
Test Case '-[OnCueCoreTests.PreShowCheckTests testProblemsAreFound]' passed (0.014 seconds).
Test Case '-[OnCueCoreTests.PreShowCheckTests testPTZOverTCP]' passed (2.111 seconds).
Test Case '-[OnCueCoreTests.PreShowCheckTests testSampleShowOnTheSimulator]' passed (0.005 seconds).
Test Suite 'PreShowCheckTests' passed at 2026-11-12 15:19:11.000.
	 Executed 4 tests, with 0 failures (0 unexpected) in 3.661 (3.661) seconds
Test Case '-[OnCueCoreTests.ProjectStorageTests testBackupFolderKeepsEveryCopyAndFindsTheNewest]' passed (0.036 seconds).
OnCueCoreTests/ProjectStorageTests.swift:108: Fatal error: Unexpectedly found nil while unwrapping an Optional value
✔ Test run with 0 tests passed after 0.001 seconds.
```
## Build result
```
** BUILD SUCCEEDED **
```
## Warnings (       6)
```
/Users/runner/work/oncue/oncue/OnCue/Workspace/MediaPlayer.swift:134:36: warning: 'isPlayable' was deprecated in macOS 13.0: Use load(.isPlayable) instead
/Users/runner/work/oncue/oncue/Packages/OnCueCore/Sources/OnCueCore/Media/ItemMedia.swift:44:22: warning: 'tracks(withMediaType:)' was deprecated in macOS 13.0: Use loadTracks(withMediaType:) instead
/Users/runner/work/oncue/oncue/Packages/OnCueCore/Sources/OnCueCore/Media/ItemMedia.swift:83:47: warning: 'duration' was deprecated in macOS 13.0: Use load(.duration) instead
/Users/runner/work/oncue/oncue/Packages/OnCueCore/Sources/OnCueCore/Media/ItemMedia.swift:84:33: warning: 'tracks(withMediaType:)' was deprecated in macOS 13.0: Use loadTracks(withMediaType:) instead
/Users/runner/work/oncue/oncue/Packages/OnCueCore/Sources/OnCueCore/Media/TempoDetector.swift:8:33: warning: 'tracks(withMediaType:)' was deprecated in macOS 13.0: Use loadTracks(withMediaType:) instead
2026-11-12 15:22:14.227 appintentsmetadataprocessor[7445:25177] warning: Metadata extraction skipped. No AppIntents.framework dependency found.
```
## Smoke test
```
[smoke] app launched (pid 7464)
[smoke] machine profile created at /Users/runner/work/_temp/smoke/profile/MachineProfile.json
[smoke] new project opened (type com.nishanpani.oncue.show, windows: 1)
[smoke] saved to /Users/runner/work/_temp/smoke/smoke.oncue
[smoke] window closed
[smoke] saved project verified: package, format 2, 1 playlist(s), 1 scene(s), 4 camera(s), 1 backup(s) inside, 25 fps
[smoke] reopened smoke.oncue (windows: 1)
[smoke] PASS: create, save, close and reopen all succeeded
```
## DMG
```
/Users/runner/work/oncue/oncue/Packages/OnCueCore/Sources/OnCueCore/Media/ItemMedia.swift:84:33: warning: 'tracks(withMediaType:)' was deprecated in macOS 13.0: Use loadTracks(withMediaType:) instead
/Users/runner/work/oncue/oncue/Packages/OnCueCore/Sources/OnCueCore/Media/TempoDetector.swift:8:33: warning: 'tracks(withMediaType:)' was deprecated in macOS 13.0: Use loadTracks(withMediaType:) instead
/Users/runner/work/oncue/oncue/OnCue/Workspace/MediaPlayer.swift:134:36: warning: 'isPlayable' was deprecated in macOS 13.0: Use load(.isPlayable) instead
** BUILD SUCCEEDED **
build/Release/Build/Products/Release/OnCue.app: valid on disk
build/Release/Build/Products/Release/OnCue.app: satisfies its Designated Requirement
Signature=adhoc
TeamIdentifier=not set
Runtime Version=15.5.0
hdiutil: verify: checksum of "/Users/runner/work/_temp/dist/OnCue-0.1.0-1.dmg" is VALID
Made /Users/runner/work/_temp/dist/OnCue-0.1.0-1.dmg (3.2M)
total 6536
drwxr-xr-x   3 runner  staff       96 Nov 12 15:27 .
drwxr-xr-x  15 runner  staff      480 Nov 12 15:27 ..
-rw-r--r--@  1 runner  staff  3344780 Nov 12 15:27 OnCue-0.1.0-1.dmg
```
