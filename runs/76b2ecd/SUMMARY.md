# CI results for 76b2ecd

- Commit: 76b2ecdc6b18604f63413a5e1c6bf25148540265
- Run: https://github.com/nishan6/oncue/actions/runs/43330716555
- Date (UTC): 2026-11-12T23:51:13Z

| Step | Result |
| --- | --- |
| Generate project | success (project changed: true) |
| Package tests | success |
| App build | success |
| Launch smoke test | success |
| Screenshots | success |
| DMG | cancelled |

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
Test Suite 'ShotVocabularyTests' passed at 2026-11-12 23:41:04.305.
	 Executed 7 tests, with 0 failures (0 unexpected) in 0.011 (0.011) seconds
Test Case '-[OnCueCoreTests.ShowControlTests testAnalysisMatchesScriptedShotsToCuts]' passed (0.012 seconds).
Test Case '-[OnCueCoreTests.ShowControlTests testAuxOutputSetsTheAux]' passed (0.007 seconds).
Test Case '-[OnCueCoreTests.ShowControlTests testCameraDownMovesOnlyTheRequestedUpcomingShots]' passed (0.001 seconds).
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
Test Suite 'ShowControlTests' passed at 2026-11-12 23:41:04.330.
	 Executed 14 tests, with 0 failures (0 unexpected) in 0.024 (0.025) seconds
Test Case '-[OnCueCoreTests.TempoMapTests testTicksBeatsSeconds]' passed (0.000 seconds).
Test Suite 'TempoMapTests' passed at 2026-11-12 23:41:04.330.
	 Executed 1 test, with 0 failures (0 unexpected) in 0.000 (0.000) seconds
Test Case '-[OnCueCoreTests.TempoTests testDetectsTempoAndFirstBeat]' passed (0.872 seconds).
Test Case '-[OnCueCoreTests.TempoTests testSilenceHasNoTempo]' passed (0.086 seconds).
Test Suite 'TempoTests' passed at 2026-11-12 23:41:05.289.
	 Executed 2 tests, with 0 failures (0 unexpected) in 0.959 (0.959) seconds
Test Case '-[OnCueCoreTests.TimecodeTests testDropFrameKnownValues]' passed (0.001 seconds).
Test Case '-[OnCueCoreTests.TimecodeTests testDropFrameRoundTripsEveryFrameOfAnHour]' passed (0.246 seconds).
Test Case '-[OnCueCoreTests.TimecodeTests testNonDropFrame]' passed (0.000 seconds).
Test Suite 'TimecodeTests' passed at 2026-11-12 23:41:05.537.
	 Executed 3 tests, with 0 failures (0 unexpected) in 0.248 (0.248) seconds
Test Case '-[OnCueCoreTests.TimelineTests testCameraColourDefaultsByNumberAndCanBeChosen]' passed (0.006 seconds).
Test Case '-[OnCueCoreTests.TimelineTests testCameraColourRoundTripsAndIsOptionalInOldFiles]' passed (0.003 seconds).
Test Case '-[OnCueCoreTests.TimelineTests testLiveCursorSteppingAndJumping]' passed (0.004 seconds).
Test Case '-[OnCueCoreTests.TimelineTests testMovingAShotOnTheTimelineReordersTheShotList]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.TimelineTests testOrderItemsGiveEachShotOneStep]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.TimelineTests testPlannedLengthExtendsTheEnd]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.TimelineTests testRunLength]' passed (0.003 seconds).
Test Case '-[OnCueCoreTests.TimelineTests testSampleShowHasEveryTrackKind]' passed (0.004 seconds).
Test Case '-[OnCueCoreTests.TimelineTests testShotSpansRunToTheNextShotAndTheSongEnd]' passed (0.001 seconds).
Test Case '-[OnCueCoreTests.TimelineTests testSnap]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.TimelineTests testTrackCuesAreCreatedOnTheRightTrack]' passed (0.001 seconds).
Test Suite 'TimelineTests' passed at 2026-11-12 23:41:05.558.
	 Executed 11 tests, with 0 failures (0 unexpected) in 0.021 (0.022) seconds
Test Case '-[OnCueCoreTests.TourTests testLoadLogsFromFolder]' passed (0.031 seconds).
Test Case '-[OnCueCoreTests.TourTests testNightsCompared]' passed (0.004 seconds).
Test Case '-[OnCueCoreTests.TourTests testOldLogsWithoutTourFieldsStillOpen]' passed (0.017 seconds).
Test Suite 'TourTests' passed at 2026-11-12 23:41:05.612.
	 Executed 3 tests, with 0 failures (0 unexpected) in 0.053 (0.053) seconds
Test Case '-[OnCueCoreTests.UpcomingCallTests testCallsAndPlayerCuesInOrder]' passed (0.000 seconds).
Test Suite 'UpcomingCallTests' passed at 2026-11-12 23:41:05.612.
	 Executed 1 test, with 0 failures (0 unexpected) in 0.000 (0.000) seconds
Test Case '-[OnCueCoreTests.VersionTests testBackupFolder]' passed (0.024 seconds).
Test Case '-[OnCueCoreTests.VersionTests testSaveRestoreAndLimits]' passed (0.111 seconds).
Test Suite 'VersionTests' passed at 2026-11-12 23:41:05.747.
	 Executed 2 tests, with 0 failures (0 unexpected) in 0.135 (0.135) seconds
Test Suite 'OnCueCorePackageTests.xctest' passed at 2026-11-12 23:41:05.747.
	 Executed 194 tests, with 0 failures (0 unexpected) in 10.902 (10.916) seconds
Test Suite 'All tests' passed at 2026-11-12 23:41:05.748.
	 Executed 194 tests, with 0 failures (0 unexpected) in 10.902 (10.919) seconds
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
2026-11-12 23:45:54.667 appintentsmetadataprocessor[10024:31521] warning: Metadata extraction skipped. No AppIntents.framework dependency found.
```
## Smoke test
```
[smoke] app launched (pid 10043)
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
OnCue 0.1.0 (1), signing identity: -
```
