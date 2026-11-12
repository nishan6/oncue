# CI results for 94c85dc

- Commit: 94c85dcb6ec982ac1a78668aa034b0c6cfae74d4
- Run: https://github.com/nishan6/oncue/actions/runs/43183293129
- Date (UTC): 2026-11-12T08:34:45Z

| Step | Result |
| --- | --- |
| Generate project | success (project changed: true) |
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
Test Case '-[OnCueCoreTests.PersistenceTests testStarterShowRoundTrips]' passed (0.003 seconds).
Test Case '-[OnCueCoreTests.PersistenceTests testUnknownEnumValuesFallBackSafely]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.PersistenceTests testWrongValueTypeNamesTheField]' passed (0.000 seconds).
Test Suite 'PersistenceTests' passed at 2026-11-12 08:31:27.054.
	 Executed 17 tests, with 0 failures (0 unexpected) in 0.023 (0.024) seconds
Test Case '-[OnCueCoreTests.PreShowCheckTests testATEMThatAnswersAndOneThatDoesnt]' passed (1.529 seconds).
Test Case '-[OnCueCoreTests.PreShowCheckTests testProblemsAreFound]' passed (0.016 seconds).
Test Case '-[OnCueCoreTests.PreShowCheckTests testPTZOverTCP]' passed (2.102 seconds).
Test Case '-[OnCueCoreTests.PreShowCheckTests testSampleShowOnTheSimulator]' passed (0.006 seconds).
Test Suite 'PreShowCheckTests' passed at 2026-11-12 08:31:30.708.
	 Executed 4 tests, with 0 failures (0 unexpected) in 3.653 (3.654) seconds
Test Case '-[OnCueCoreTests.RundownTimingTests testAppliesOnlyWhenTimed]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.RundownTimingTests testDeadlineAcrossMidnight]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.RundownTimingTests testOverrunShowsNegativeRemaining]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.RundownTimingTests testOverUnderAndHardOut]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.RundownTimingTests testRunsFromTheLog]' passed (0.000 seconds).
Test Suite 'RundownTimingTests' passed at 2026-11-12 08:31:30.709.
	 Executed 5 tests, with 0 failures (0 unexpected) in 0.001 (0.001) seconds
Test Case '-[OnCueCoreTests.SetupEditingTests testOutputsSwitchersAndTheirTracks]' passed (0.001 seconds).
Test Suite 'SetupEditingTests' passed at 2026-11-12 08:31:30.710.
	 Executed 1 test, with 0 failures (0 unexpected) in 0.001 (0.001) seconds
Test Case '-[OnCueCoreTests.ShowControlTests testAnalysisMatchesScriptedShotsToCuts]' passed (0.004 seconds).
Test Case '-[OnCueCoreTests.ShowControlTests testAuxOutputSetsTheAux]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.ShowControlTests testCameraDownMovesOnlyTheRequestedUpcomingShots]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.ShowControlTests testControlStopHaltsTheTransport]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.ShowControlTests testControlTrackLoadsTheNextItem]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.ShowControlTests testCuesFireOnceWhenThePlayheadPassesThem]' passed (0.001 seconds).
Test Case '-[OnCueCoreTests.ShowControlTests testDisplayModeSendsOSCButNotFX]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.ShowControlTests testFreeModeHoldsTheScriptAndSendsNothing]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.ShowControlTests testLoopRepeatsTheSectionUntilReleased]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.ShowControlTests testMirroringOutputFollowsTheMainCut]' passed (0.001 seconds).
Test Case '-[OnCueCoreTests.ShowControlTests testPanicDropsEveryOutputToDisplay]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.ShowControlTests testSeparateOutputWithItsOwnTrackAndMode]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.ShowControlTests testSubSwitcherRoutesThroughItsFeed]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.ShowControlTests testVarietyHintsPreferCamerasOffAirLongest]' passed (0.001 seconds).
Test Suite 'ShowControlTests' passed at 2026-11-12 08:31:30.720.
	 Executed 14 tests, with 0 failures (0 unexpected) in 0.010 (0.011) seconds
Test Case '-[OnCueCoreTests.TimelineTests testCameraColourDefaultsByNumberAndCanBeChosen]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.TimelineTests testCameraColourRoundTripsAndIsOptionalInOldFiles]' passed (0.004 seconds).
Test Case '-[OnCueCoreTests.TimelineTests testLiveCursorSteppingAndJumping]' passed (0.003 seconds).
Test Case '-[OnCueCoreTests.TimelineTests testMovingAShotOnTheTimelineReordersTheShotList]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.TimelineTests testOrderItemsGiveEachShotOneStep]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.TimelineTests testPlannedLengthExtendsTheEnd]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.TimelineTests testRunLength]' passed (0.001 seconds).
Test Case '-[OnCueCoreTests.TimelineTests testSampleShowHasEveryTrackKind]' passed (0.001 seconds).
Test Case '-[OnCueCoreTests.TimelineTests testShotSpansRunToTheNextShotAndTheSongEnd]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.TimelineTests testSnap]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.TimelineTests testTrackCuesAreCreatedOnTheRightTrack]' passed (0.000 seconds).
Test Suite 'TimelineTests' passed at 2026-11-12 08:31:30.732.
	 Executed 11 tests, with 0 failures (0 unexpected) in 0.012 (0.012) seconds
Test Case '-[OnCueCoreTests.TourTests testLoadLogsFromFolder]' passed (0.019 seconds).
Test Case '-[OnCueCoreTests.TourTests testNightsCompared]' passed (0.004 seconds).
Test Case '-[OnCueCoreTests.TourTests testOldLogsWithoutTourFieldsStillOpen]' passed (0.019 seconds).
Test Suite 'TourTests' passed at 2026-11-12 08:31:30.774.
	 Executed 3 tests, with 0 failures (0 unexpected) in 0.041 (0.041) seconds
Test Suite 'OnCueCorePackageTests.xctest' passed at 2026-11-12 08:31:30.774.
	 Executed 128 tests, with 0 failures (0 unexpected) in 7.407 (7.415) seconds
Test Suite 'All tests' passed at 2026-11-12 08:31:30.774.
	 Executed 128 tests, with 0 failures (0 unexpected) in 7.407 (7.420) seconds
✔ Test run with 0 tests passed after 0.001 seconds.
```
## Build result
```
** BUILD SUCCEEDED **
```
## Warnings (       1)
```
2026-11-12 08:34:16.372 appintentsmetadataprocessor[5881:20352] warning: Metadata extraction skipped. No AppIntents.framework dependency found.
```
## Smoke test
```
[smoke] app launched (pid 5900)
[smoke] machine profile created at /Users/runner/work/_temp/smoke/profile/MachineProfile.json
[smoke] new show opened (type com.nishanpani.oncue.show, windows: 1)
[smoke] saved to /Users/runner/work/_temp/smoke/smoke.oncue
[smoke] window closed
[smoke] saved file verified: format 1, 1 item(s), 4 camera(s)
[smoke] reopened smoke.oncue (windows: 1)
[smoke] PASS: create, save, close and reopen all succeeded
```
