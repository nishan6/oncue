# CI results for 85a0ef0

- Commit: 85a0ef02b598be0ed7dd2113fd0020186f24faa3
- Run: https://github.com/nishan6/oncue/actions/runs/43333163787
- Date (UTC): 2026-11-13T00:03:40Z

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
Test Suite 'SourcesTests' passed at 2026-11-12 23:59:00.850.
	 Executed 3 tests, with 0 failures (0 unexpected) in 0.001 (0.001) seconds
Test Case '-[OnCueCoreTests.TempoMapTests testTicksBeatsSeconds]' passed (0.000 seconds).
Test Suite 'TempoMapTests' passed at 2026-11-12 23:59:00.850.
	 Executed 1 test, with 0 failures (0 unexpected) in 0.000 (0.000) seconds
Test Case '-[OnCueCoreTests.TempoTests testDetectsTempoAndFirstBeat]' passed (0.943 seconds).
Test Case '-[OnCueCoreTests.TempoTests testSilenceHasNoTempo]' passed (0.071 seconds).
Test Suite 'TempoTests' passed at 2026-11-12 23:59:01.865.
	 Executed 2 tests, with 0 failures (0 unexpected) in 1.014 (1.015) seconds
Test Case '-[OnCueCoreTests.TimecodeTests testDropFrameKnownValues]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.TimecodeTests testDropFrameRoundTripsEveryFrameOfAnHour]' passed (0.197 seconds).
Test Case '-[OnCueCoreTests.TimecodeTests testNonDropFrame]' passed (0.000 seconds).
Test Suite 'TimecodeTests' passed at 2026-11-12 23:59:02.062.
	 Executed 3 tests, with 0 failures (0 unexpected) in 0.197 (0.197) seconds
Test Case '-[OnCueCoreTests.TimelineTests testCameraColourDefaultsByNumberAndCanBeChosen]' passed (0.001 seconds).
Test Case '-[OnCueCoreTests.TimelineTests testCameraColourRoundTripsAndIsOptionalInOldFiles]' passed (0.001 seconds).
Test Case '-[OnCueCoreTests.TimelineTests testLiveCursorSteppingAndJumping]' passed (0.002 seconds).
Test Case '-[OnCueCoreTests.TimelineTests testMovingAShotOnTheTimelineReordersTheShotList]' passed (0.001 seconds).
Test Case '-[OnCueCoreTests.TimelineTests testOrderItemsGiveEachShotOneStep]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.TimelineTests testPlannedLengthExtendsTheEnd]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.TimelineTests testRunLength]' passed (0.002 seconds).
Test Case '-[OnCueCoreTests.TimelineTests testSampleShowHasEveryTrackKind]' passed (0.005 seconds).
Test Case '-[OnCueCoreTests.TimelineTests testShotSpansRunToTheNextShotAndTheSongEnd]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.TimelineTests testSnap]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.TimelineTests testTrackCuesAreCreatedOnTheRightTrack]' passed (0.000 seconds).
Test Suite 'TimelineTests' passed at 2026-11-12 23:59:02.075.
	 Executed 11 tests, with 0 failures (0 unexpected) in 0.013 (0.013) seconds
Test Case '-[OnCueCoreTests.TourTests testLoadLogsFromFolder]' passed (0.032 seconds).
Test Case '-[OnCueCoreTests.TourTests testNightsCompared]' passed (0.006 seconds).
Test Case '-[OnCueCoreTests.TourTests testOldLogsWithoutTourFieldsStillOpen]' passed (0.020 seconds).
Test Suite 'TourTests' passed at 2026-11-12 23:59:02.134.
	 Executed 3 tests, with 0 failures (0 unexpected) in 0.058 (0.059) seconds
Test Case '-[OnCueCoreTests.TriggerLearnTests testLearnedInputMatchesItsEvent]' passed (0.000 seconds).
Test Suite 'TriggerLearnTests' passed at 2026-11-12 23:59:02.135.
	 Executed 1 test, with 0 failures (0 unexpected) in 0.000 (0.001) seconds
Test Case '-[OnCueCoreTests.TriggerRouteTests testArtNetFiresOnceAsTheLevelRises]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.TriggerRouteTests testArtNetParser]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.TriggerRouteTests testCCFiresOnceAsItCrosses]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.TriggerRouteTests testDisabledRoutesNeverFire]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.TriggerRouteTests testMSCParser]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.TriggerRouteTests testNoteOnOnlyAndChannels]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.TriggerRouteTests testOSCExactAndWildcard]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.TriggerRouteTests testProgramChangeAndMSC]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.TriggerRouteTests testResolveSongFromValue]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.TriggerRouteTests testRoutesRoundTrip]' passed (0.002 seconds).
Test Case '-[OnCueCoreTests.TriggerRouteTests testValidation]' passed (0.000 seconds).
Test Suite 'TriggerRouteTests' passed at 2026-11-12 23:59:02.139.
	 Executed 11 tests, with 0 failures (0 unexpected) in 0.004 (0.004) seconds
Test Case '-[OnCueCoreTests.UpcomingCallTests testCallsAndPlayerCuesInOrder]' passed (0.000 seconds).
Test Suite 'UpcomingCallTests' passed at 2026-11-12 23:59:02.139.
	 Executed 1 test, with 0 failures (0 unexpected) in 0.000 (0.000) seconds
Test Case '-[OnCueCoreTests.VersionTests testBackupFolder]' passed (0.021 seconds).
Test Case '-[OnCueCoreTests.VersionTests testSaveRestoreAndLimits]' passed (0.080 seconds).
Test Suite 'VersionTests' passed at 2026-11-12 23:59:02.240.
	 Executed 2 tests, with 0 failures (0 unexpected) in 0.100 (0.101) seconds
Test Suite 'OnCueCorePackageTests.xctest' failed at 2026-11-12 23:59:02.240.
	 Executed 218 tests, with 1 failure (0 unexpected) in 10.603 (10.615) seconds
Test Suite 'All tests' failed at 2026-11-12 23:59:02.240.
	 Executed 218 tests, with 1 failure (0 unexpected) in 10.603 (10.618) seconds
✔ Test run with 0 tests passed after 0.001 seconds.
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
