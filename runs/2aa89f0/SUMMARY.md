# CI results for 2aa89f0

- Commit: 2aa89f0de6d8ca6a28926108fe5eedb17fa8c380
- Run: https://github.com/nishan6/oncue/actions/runs/43191256914
- Date (UTC): 2026-11-12T09:37:39Z

| Step | Result |
| --- | --- |
| Generate project | success (project changed: false) |
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
	 Executed 4 tests, with 0 failures (0 unexpected) in 3.625 (3.625) seconds
Test Case '-[OnCueCoreTests.RundownTimingTests testAppliesOnlyWhenTimed]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.RundownTimingTests testDeadlineAcrossMidnight]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.RundownTimingTests testOverrunShowsNegativeRemaining]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.RundownTimingTests testOverUnderAndHardOut]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.RundownTimingTests testRunsFromTheLog]' passed (0.000 seconds).
Test Suite 'RundownTimingTests' passed at 2026-11-12 09:36:14.293.
	 Executed 5 tests, with 0 failures (0 unexpected) in 0.001 (0.001) seconds
Test Case '-[OnCueCoreTests.SetupEditingTests testOutputsSwitchersAndTheirTracks]' passed (0.000 seconds).
Test Suite 'SetupEditingTests' passed at 2026-11-12 09:36:14.293.
	 Executed 1 test, with 0 failures (0 unexpected) in 0.000 (0.001) seconds
Test Case '-[OnCueCoreTests.ShowControlTests testAnalysisMatchesScriptedShotsToCuts]' passed (0.003 seconds).
Test Case '-[OnCueCoreTests.ShowControlTests testAuxOutputSetsTheAux]' passed (0.001 seconds).
Test Case '-[OnCueCoreTests.ShowControlTests testCameraDownMovesOnlyTheRequestedUpcomingShots]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.ShowControlTests testControlStopHaltsTheTransport]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.ShowControlTests testControlTrackLoadsTheNextItem]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.ShowControlTests testCuesFireOnceWhenThePlayheadPassesThem]' passed (0.001 seconds).
Test Case '-[OnCueCoreTests.ShowControlTests testDisplayModeSendsOSCButNotFX]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.ShowControlTests testFreeModeHoldsTheScriptAndSendsNothing]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.ShowControlTests testLoopRepeatsTheSectionUntilReleased]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.ShowControlTests testMirroringOutputFollowsTheMainCut]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.ShowControlTests testPanicDropsEveryOutputToDisplay]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.ShowControlTests testSeparateOutputWithItsOwnTrackAndMode]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.ShowControlTests testSubSwitcherRoutesThroughItsFeed]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.ShowControlTests testVarietyHintsPreferCamerasOffAirLongest]' passed (0.000 seconds).
Test Suite 'ShowControlTests' passed at 2026-11-12 09:36:14.302.
	 Executed 14 tests, with 0 failures (0 unexpected) in 0.008 (0.009) seconds
/Users/runner/work/oncue/oncue/Packages/OnCueCore/Tests/OnCueCoreTests/MediaTests.swift:81: error: -[OnCueCoreTests.TempoTests testDetectsTempoAndFirstBeat] : XCTAssertEqualWithAccuracy failed: ("0.07761904761904764") is not equal to ("0.0") +/- ("0.03") - 128.0 BPM phase
/Users/runner/work/oncue/oncue/Packages/OnCueCore/Tests/OnCueCoreTests/MediaTests.swift:81: error: -[OnCueCoreTests.TempoTests testDetectsTempoAndFirstBeat] : XCTAssertEqualWithAccuracy failed: ("-0.10457815310032059") is not equal to ("0.0") +/- ("0.03") - 174.0 BPM phase
Test Case '-[OnCueCoreTests.TempoTests testDetectsTempoAndFirstBeat]' failed (1.117 seconds).
Test Case '-[OnCueCoreTests.TempoTests testSilenceHasNoTempo]' passed (0.067 seconds).
Test Suite 'TempoTests' failed at 2026-11-12 09:36:15.486.
	 Executed 2 tests, with 2 failures (0 unexpected) in 1.184 (1.184) seconds
Test Case '-[OnCueCoreTests.TimelineTests testCameraColourDefaultsByNumberAndCanBeChosen]' passed (0.001 seconds).
Test Case '-[OnCueCoreTests.TimelineTests testCameraColourRoundTripsAndIsOptionalInOldFiles]' passed (0.002 seconds).
Test Case '-[OnCueCoreTests.TimelineTests testLiveCursorSteppingAndJumping]' passed (0.004 seconds).
Test Case '-[OnCueCoreTests.TimelineTests testMovingAShotOnTheTimelineReordersTheShotList]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.TimelineTests testOrderItemsGiveEachShotOneStep]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.TimelineTests testPlannedLengthExtendsTheEnd]' passed (0.001 seconds).
Test Case '-[OnCueCoreTests.TimelineTests testRunLength]' passed (0.002 seconds).
Test Case '-[OnCueCoreTests.TimelineTests testSampleShowHasEveryTrackKind]' passed (0.001 seconds).
Test Case '-[OnCueCoreTests.TimelineTests testShotSpansRunToTheNextShotAndTheSongEnd]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.TimelineTests testSnap]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.TimelineTests testTrackCuesAreCreatedOnTheRightTrack]' passed (0.000 seconds).
Test Suite 'TimelineTests' passed at 2026-11-12 09:36:15.500.
	 Executed 11 tests, with 0 failures (0 unexpected) in 0.013 (0.014) seconds
Test Case '-[OnCueCoreTests.TourTests testLoadLogsFromFolder]' passed (0.025 seconds).
Test Case '-[OnCueCoreTests.TourTests testNightsCompared]' passed (0.004 seconds).
Test Case '-[OnCueCoreTests.TourTests testOldLogsWithoutTourFieldsStillOpen]' passed (0.023 seconds).
Test Suite 'TourTests' passed at 2026-11-12 09:36:15.552.
	 Executed 3 tests, with 0 failures (0 unexpected) in 0.052 (0.053) seconds
Test Case '-[OnCueCoreTests.VersionTests testBackupFolder]' passed (0.026 seconds).
Test Case '-[OnCueCoreTests.VersionTests testSaveRestoreAndLimits]' passed (0.081 seconds).
Test Suite 'VersionTests' passed at 2026-11-12 09:36:15.660.
	 Executed 2 tests, with 0 failures (0 unexpected) in 0.108 (0.108) seconds
Test Suite 'OnCueCorePackageTests.xctest' failed at 2026-11-12 09:36:15.660.
	 Executed 138 tests, with 2 failures (0 unexpected) in 9.517 (9.527) seconds
Test Suite 'All tests' failed at 2026-11-12 09:36:15.660.
	 Executed 138 tests, with 2 failures (0 unexpected) in 9.517 (9.531) seconds
✔ Test run with 0 tests passed after 0.001 seconds.
```
## Build result
```
** BUILD FAILED **
/Users/runner/work/oncue/oncue/OnCue/Workspace/MediaPlayer.swift:263:47: error: 'TempoEstimate' initializer is inaccessible due to 'internal' protection level
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
