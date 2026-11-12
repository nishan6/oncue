# CI results for efffc65

- Commit: efffc65f1170a12cfbe753435200959259f090f5
- Run: https://github.com/nishan6/oncue/actions/runs/43182691984
- Date (UTC): 2026-11-12T08:26:48Z

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
Test Case '-[OnCueCoreTests.PersistenceTests testStarterShowRoundTrips]' passed (0.001 seconds).
Test Case '-[OnCueCoreTests.PersistenceTests testUnknownEnumValuesFallBackSafely]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.PersistenceTests testWrongValueTypeNamesTheField]' passed (0.000 seconds).
Test Suite 'PersistenceTests' passed at 2026-11-12 08:25:40.444.
	 Executed 17 tests, with 0 failures (0 unexpected) in 0.014 (0.014) seconds
Test Case '-[OnCueCoreTests.PreShowCheckTests testATEMThatAnswersAndOneThatDoesnt]' passed (1.462 seconds).
Test Case '-[OnCueCoreTests.PreShowCheckTests testProblemsAreFound]' passed (0.016 seconds).
Test Case '-[OnCueCoreTests.PreShowCheckTests testPTZOverTCP]' passed (2.119 seconds).
Test Case '-[OnCueCoreTests.PreShowCheckTests testSampleShowOnTheSimulator]' passed (0.014 seconds).
Test Suite 'PreShowCheckTests' passed at 2026-11-12 08:25:44.055.
	 Executed 4 tests, with 0 failures (0 unexpected) in 3.610 (3.611) seconds
Test Case '-[OnCueCoreTests.RundownTimingTests testAppliesOnlyWhenTimed]' passed (0.001 seconds).
Test Case '-[OnCueCoreTests.RundownTimingTests testDeadlineAcrossMidnight]' passed (0.001 seconds).
Test Case '-[OnCueCoreTests.RundownTimingTests testOverrunShowsNegativeRemaining]' passed (0.001 seconds).
Test Case '-[OnCueCoreTests.RundownTimingTests testOverUnderAndHardOut]' passed (0.001 seconds).
Test Case '-[OnCueCoreTests.RundownTimingTests testRunsFromTheLog]' passed (0.001 seconds).
Test Suite 'RundownTimingTests' passed at 2026-11-12 08:25:44.060.
	 Executed 5 tests, with 0 failures (0 unexpected) in 0.004 (0.005) seconds
Test Case '-[OnCueCoreTests.SetupEditingTests testOutputsSwitchersAndTheirTracks]' passed (0.001 seconds).
Test Suite 'SetupEditingTests' passed at 2026-11-12 08:25:44.062.
	 Executed 1 test, with 0 failures (0 unexpected) in 0.001 (0.002) seconds
Test Case '-[OnCueCoreTests.ShowControlTests testAnalysisMatchesScriptedShotsToCuts]' passed (0.009 seconds).
Test Case '-[OnCueCoreTests.ShowControlTests testAuxOutputSetsTheAux]' passed (0.000 seconds).
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
Test Suite 'ShowControlTests' passed at 2026-11-12 08:25:44.076.
	 Executed 14 tests, with 0 failures (0 unexpected) in 0.014 (0.014) seconds
Test Case '-[OnCueCoreTests.TimelineTests testCameraColourDefaultsByNumberAndCanBeChosen]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.TimelineTests testCameraColourRoundTripsAndIsOptionalInOldFiles]' passed (0.001 seconds).
Test Case '-[OnCueCoreTests.TimelineTests testLiveCursorSteppingAndJumping]' passed (0.002 seconds).
Test Case '-[OnCueCoreTests.TimelineTests testMovingAShotOnTheTimelineReordersTheShotList]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.TimelineTests testOrderItemsGiveEachShotOneStep]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.TimelineTests testPlannedLengthExtendsTheEnd]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.TimelineTests testRunLength]' passed (0.001 seconds).
Test Case '-[OnCueCoreTests.TimelineTests testSampleShowHasEveryTrackKind]' passed (0.001 seconds).
Test Case '-[OnCueCoreTests.TimelineTests testShotSpansRunToTheNextShotAndTheSongEnd]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.TimelineTests testSnap]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.TimelineTests testTrackCuesAreCreatedOnTheRightTrack]' passed (0.000 seconds).
Test Suite 'TimelineTests' passed at 2026-11-12 08:25:44.084.
	 Executed 11 tests, with 0 failures (0 unexpected) in 0.007 (0.008) seconds
Test Case '-[OnCueCoreTests.TourTests testLoadLogsFromFolder]' passed (0.020 seconds).
Test Case '-[OnCueCoreTests.TourTests testNightsCompared]' passed (0.004 seconds).
Test Case '-[OnCueCoreTests.TourTests testOldLogsWithoutTourFieldsStillOpen]' passed (0.017 seconds).
Test Suite 'TourTests' passed at 2026-11-12 08:25:44.125.
	 Executed 3 tests, with 0 failures (0 unexpected) in 0.041 (0.041) seconds
Test Suite 'OnCueCorePackageTests.xctest' passed at 2026-11-12 08:25:44.125.
	 Executed 126 tests, with 0 failures (0 unexpected) in 7.334 (7.343) seconds
Test Suite 'All tests' passed at 2026-11-12 08:25:44.125.
	 Executed 126 tests, with 0 failures (0 unexpected) in 7.334 (7.345) seconds
✔ Test run with 0 tests passed after 0.001 seconds.
```
## Build result
```
** BUILD FAILED **
/Users/runner/work/oncue/oncue/OnCue/App/ScreenshotRun.swift:164:24: error: cannot find 'ImageRenderer' in scope
/Users/runner/work/oncue/oncue/OnCue/Workspace/CameraPlotView.swift:315:41: error: ambiguous use of 'cos'
```
## Warnings (0)
```
```
## Smoke test
```
```
