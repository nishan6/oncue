# CI results for b40d046

- Commit: b40d046529611d94a8e754e3a3efcacf9d52905f
- Run: https://github.com/nishan6/oncue/actions/runs/43254432453
- Date (UTC): 2026-11-12T16:27:52Z

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
Test Suite 'ShotVocabularyTests' passed at 2026-11-12 16:25:58.209.
	 Executed 7 tests, with 0 failures (0 unexpected) in 0.025 (0.026) seconds
Test Case '-[OnCueCoreTests.ShowControlTests testAnalysisMatchesScriptedShotsToCuts]' passed (0.046 seconds).
Test Case '-[OnCueCoreTests.ShowControlTests testAuxOutputSetsTheAux]' passed (0.035 seconds).
Test Case '-[OnCueCoreTests.ShowControlTests testCameraDownMovesOnlyTheRequestedUpcomingShots]' passed (0.001 seconds).
Test Case '-[OnCueCoreTests.ShowControlTests testControlStopHaltsTheTransport]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.ShowControlTests testControlTrackLoadsTheNextItem]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.ShowControlTests testCuesFireOnceWhenThePlayheadPassesThem]' passed (0.001 seconds).
Test Case '-[OnCueCoreTests.ShowControlTests testDisplayModeSendsOSCButNotFX]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.ShowControlTests testFreeModeHoldsTheScriptAndSendsNothing]' passed (0.001 seconds).
Test Case '-[OnCueCoreTests.ShowControlTests testLoopRepeatsTheSectionUntilReleased]' passed (0.001 seconds).
Test Case '-[OnCueCoreTests.ShowControlTests testMirroringOutputFollowsTheMainCut]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.ShowControlTests testPanicDropsEveryOutputToDisplay]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.ShowControlTests testSeparateOutputWithItsOwnTrackAndMode]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.ShowControlTests testSubSwitcherRoutesThroughItsFeed]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.ShowControlTests testVarietyHintsPreferCamerasOffAirLongest]' passed (0.000 seconds).
Test Suite 'ShowControlTests' passed at 2026-11-12 16:25:58.296.
	 Executed 14 tests, with 0 failures (0 unexpected) in 0.086 (0.087) seconds
Test Case '-[OnCueCoreTests.TempoMapTests testTicksBeatsSeconds]' passed (0.000 seconds).
Test Suite 'TempoMapTests' passed at 2026-11-12 16:25:58.296.
	 Executed 1 test, with 0 failures (0 unexpected) in 0.000 (0.000) seconds
Test Case '-[OnCueCoreTests.TempoTests testDetectsTempoAndFirstBeat]' passed (1.232 seconds).
Test Case '-[OnCueCoreTests.TempoTests testSilenceHasNoTempo]' passed (0.074 seconds).
Test Suite 'TempoTests' passed at 2026-11-12 16:25:59.603.
	 Executed 2 tests, with 0 failures (0 unexpected) in 1.307 (1.307) seconds
Test Case '-[OnCueCoreTests.TimecodeTests testDropFrameKnownValues]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.TimecodeTests testDropFrameRoundTripsEveryFrameOfAnHour]' passed (0.329 seconds).
Test Case '-[OnCueCoreTests.TimecodeTests testNonDropFrame]' passed (0.000 seconds).
Test Suite 'TimecodeTests' passed at 2026-11-12 16:25:59.933.
	 Executed 3 tests, with 0 failures (0 unexpected) in 0.329 (0.330) seconds
Test Case '-[OnCueCoreTests.TimelineTests testCameraColourDefaultsByNumberAndCanBeChosen]' passed (0.013 seconds).
Test Case '-[OnCueCoreTests.TimelineTests testCameraColourRoundTripsAndIsOptionalInOldFiles]' passed (0.003 seconds).
Test Case '-[OnCueCoreTests.TimelineTests testLiveCursorSteppingAndJumping]' passed (0.007 seconds).
Test Case '-[OnCueCoreTests.TimelineTests testMovingAShotOnTheTimelineReordersTheShotList]' passed (0.006 seconds).
Test Case '-[OnCueCoreTests.TimelineTests testOrderItemsGiveEachShotOneStep]' passed (0.001 seconds).
Test Case '-[OnCueCoreTests.TimelineTests testPlannedLengthExtendsTheEnd]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.TimelineTests testRunLength]' passed (0.002 seconds).
Test Case '-[OnCueCoreTests.TimelineTests testSampleShowHasEveryTrackKind]' passed (0.003 seconds).
Test Case '-[OnCueCoreTests.TimelineTests testShotSpansRunToTheNextShotAndTheSongEnd]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.TimelineTests testSnap]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.TimelineTests testTrackCuesAreCreatedOnTheRightTrack]' passed (0.000 seconds).
Test Suite 'TimelineTests' passed at 2026-11-12 16:25:59.971.
	 Executed 11 tests, with 0 failures (0 unexpected) in 0.038 (0.039) seconds
Test Case '-[OnCueCoreTests.TourTests testLoadLogsFromFolder]' passed (0.077 seconds).
Test Case '-[OnCueCoreTests.TourTests testNightsCompared]' passed (0.009 seconds).
Test Case '-[OnCueCoreTests.TourTests testOldLogsWithoutTourFieldsStillOpen]' passed (0.031 seconds).
Test Suite 'TourTests' passed at 2026-11-12 16:26:00.089.
	 Executed 3 tests, with 0 failures (0 unexpected) in 0.117 (0.118) seconds
Test Case '-[OnCueCoreTests.UpcomingCallTests testCallsAndPlayerCuesInOrder]' passed (0.000 seconds).
Test Suite 'UpcomingCallTests' passed at 2026-11-12 16:26:00.090.
	 Executed 1 test, with 0 failures (0 unexpected) in 0.000 (0.000) seconds
Test Case '-[OnCueCoreTests.VersionTests testBackupFolder]' passed (0.139 seconds).
Test Case '-[OnCueCoreTests.VersionTests testSaveRestoreAndLimits]' passed (0.132 seconds).
Test Suite 'VersionTests' passed at 2026-11-12 16:26:00.361.
	 Executed 2 tests, with 0 failures (0 unexpected) in 0.271 (0.271) seconds
Test Suite 'OnCueCorePackageTests.xctest' failed at 2026-11-12 16:26:00.361.
	 Executed 194 tests, with 1 failure (0 unexpected) in 14.405 (14.422) seconds
Test Suite 'All tests' failed at 2026-11-12 16:26:00.361.
	 Executed 194 tests, with 1 failure (0 unexpected) in 14.405 (14.425) seconds
✔ Test run with 0 tests passed after 0.001 seconds.
```
## Build result
```
** BUILD FAILED **
/Users/runner/work/oncue/oncue/OnCue/App/ScreenshotRun.swift:122:46: error: extra arguments at positions #1, #2 in call
/Users/runner/work/oncue/oncue/OnCue/App/ScreenshotRun.swift:122:47: error: missing argument for parameter 'from' in call
/Users/runner/work/oncue/oncue/OnCue/App/ScreenshotRun.swift:122:54: error: cannot infer contextual base in reference to member 'calls'
/Users/runner/work/oncue/oncue/OnCue/App/ScreenshotRun.swift:123:46: error: extra arguments at positions #1, #2 in call
/Users/runner/work/oncue/oncue/OnCue/App/ScreenshotRun.swift:123:47: error: missing argument for parameter 'from' in call
/Users/runner/work/oncue/oncue/OnCue/App/ScreenshotRun.swift:123:54: error: cannot infer contextual base in reference to member 'player'
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
