# CI results for 9f559a2

- Commit: 9f559a25afb6d1feea808f1c2904c57c42af25a4
- Run: https://github.com/nishan6/oncue/actions/runs/43188504540
- Date (UTC): 2026-11-12T09:13:27Z

| Step | Result |
| --- | --- |
| Generate project | success (project changed: false) |
| Package tests | success |
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
	 Executed 17 tests, with 0 failures (0 unexpected) in 0.021 (0.022) seconds
Test Case '-[OnCueCoreTests.PreShowCheckTests testATEMThatAnswersAndOneThatDoesnt]' passed (1.502 seconds).
Test Case '-[OnCueCoreTests.PreShowCheckTests testProblemsAreFound]' passed (0.020 seconds).
Test Case '-[OnCueCoreTests.PreShowCheckTests testPTZOverTCP]' passed (2.011 seconds).
Test Case '-[OnCueCoreTests.PreShowCheckTests testSampleShowOnTheSimulator]' passed (0.006 seconds).
Test Suite 'PreShowCheckTests' passed at 2026-11-12 09:07:39.300.
	 Executed 4 tests, with 0 failures (0 unexpected) in 3.539 (3.539) seconds
Test Case '-[OnCueCoreTests.RundownTimingTests testAppliesOnlyWhenTimed]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.RundownTimingTests testDeadlineAcrossMidnight]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.RundownTimingTests testOverrunShowsNegativeRemaining]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.RundownTimingTests testOverUnderAndHardOut]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.RundownTimingTests testRunsFromTheLog]' passed (0.000 seconds).
Test Suite 'RundownTimingTests' passed at 2026-11-12 09:07:39.301.
	 Executed 5 tests, with 0 failures (0 unexpected) in 0.001 (0.001) seconds
Test Case '-[OnCueCoreTests.SetupEditingTests testOutputsSwitchersAndTheirTracks]' passed (0.000 seconds).
Test Suite 'SetupEditingTests' passed at 2026-11-12 09:07:39.302.
	 Executed 1 test, with 0 failures (0 unexpected) in 0.000 (0.001) seconds
Test Case '-[OnCueCoreTests.ShowControlTests testAnalysisMatchesScriptedShotsToCuts]' passed (0.004 seconds).
Test Case '-[OnCueCoreTests.ShowControlTests testAuxOutputSetsTheAux]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.ShowControlTests testCameraDownMovesOnlyTheRequestedUpcomingShots]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.ShowControlTests testControlStopHaltsTheTransport]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.ShowControlTests testControlTrackLoadsTheNextItem]' passed (0.001 seconds).
Test Case '-[OnCueCoreTests.ShowControlTests testCuesFireOnceWhenThePlayheadPassesThem]' passed (0.001 seconds).
Test Case '-[OnCueCoreTests.ShowControlTests testDisplayModeSendsOSCButNotFX]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.ShowControlTests testFreeModeHoldsTheScriptAndSendsNothing]' passed (0.001 seconds).
Test Case '-[OnCueCoreTests.ShowControlTests testLoopRepeatsTheSectionUntilReleased]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.ShowControlTests testMirroringOutputFollowsTheMainCut]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.ShowControlTests testPanicDropsEveryOutputToDisplay]' passed (0.001 seconds).
Test Case '-[OnCueCoreTests.ShowControlTests testSeparateOutputWithItsOwnTrackAndMode]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.ShowControlTests testSubSwitcherRoutesThroughItsFeed]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.ShowControlTests testVarietyHintsPreferCamerasOffAirLongest]' passed (0.000 seconds).
Test Suite 'ShowControlTests' passed at 2026-11-12 09:07:39.312.
	 Executed 14 tests, with 0 failures (0 unexpected) in 0.010 (0.011) seconds
Test Case '-[OnCueCoreTests.TimelineTests testCameraColourDefaultsByNumberAndCanBeChosen]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.TimelineTests testCameraColourRoundTripsAndIsOptionalInOldFiles]' passed (0.001 seconds).
Test Case '-[OnCueCoreTests.TimelineTests testLiveCursorSteppingAndJumping]' passed (0.002 seconds).
Test Case '-[OnCueCoreTests.TimelineTests testMovingAShotOnTheTimelineReordersTheShotList]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.TimelineTests testOrderItemsGiveEachShotOneStep]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.TimelineTests testPlannedLengthExtendsTheEnd]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.TimelineTests testRunLength]' passed (0.001 seconds).
Test Case '-[OnCueCoreTests.TimelineTests testSampleShowHasEveryTrackKind]' passed (0.002 seconds).
Test Case '-[OnCueCoreTests.TimelineTests testShotSpansRunToTheNextShotAndTheSongEnd]' passed (0.001 seconds).
Test Case '-[OnCueCoreTests.TimelineTests testSnap]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.TimelineTests testTrackCuesAreCreatedOnTheRightTrack]' passed (0.001 seconds).
Test Suite 'TimelineTests' passed at 2026-11-12 09:07:39.321.
	 Executed 11 tests, with 0 failures (0 unexpected) in 0.008 (0.009) seconds
Test Case '-[OnCueCoreTests.TourTests testLoadLogsFromFolder]' passed (0.025 seconds).
Test Case '-[OnCueCoreTests.TourTests testNightsCompared]' passed (0.004 seconds).
Test Case '-[OnCueCoreTests.TourTests testOldLogsWithoutTourFieldsStillOpen]' passed (0.016 seconds).
Test Suite 'TourTests' passed at 2026-11-12 09:07:39.366.
	 Executed 3 tests, with 0 failures (0 unexpected) in 0.044 (0.044) seconds
Test Case '-[OnCueCoreTests.VersionTests testBackupFolder]' passed (0.013 seconds).
Test Case '-[OnCueCoreTests.VersionTests testSaveRestoreAndLimits]' passed (0.054 seconds).
Test Suite 'VersionTests' passed at 2026-11-12 09:07:39.433.
	 Executed 2 tests, with 0 failures (0 unexpected) in 0.067 (0.068) seconds
Test Suite 'OnCueCorePackageTests.xctest' passed at 2026-11-12 09:07:39.433.
	 Executed 136 tests, with 0 failures (0 unexpected) in 7.937 (7.946) seconds
Test Suite 'All tests' passed at 2026-11-12 09:07:39.434.
	 Executed 136 tests, with 0 failures (0 unexpected) in 7.937 (7.948) seconds
✔ Test run with 0 tests passed after 0.001 seconds.
```
## Build result
```
** BUILD SUCCEEDED **
```
## Warnings (       5)
```
/Users/runner/work/oncue/oncue/OnCue/Workspace/MediaPlayer.swift:134:36: warning: 'isPlayable' was deprecated in macOS 13.0: Use load(.isPlayable) instead
/Users/runner/work/oncue/oncue/Packages/OnCueCore/Sources/OnCueCore/Media/ItemMedia.swift:44:22: warning: 'tracks(withMediaType:)' was deprecated in macOS 13.0: Use loadTracks(withMediaType:) instead
/Users/runner/work/oncue/oncue/Packages/OnCueCore/Sources/OnCueCore/Media/ItemMedia.swift:83:47: warning: 'duration' was deprecated in macOS 13.0: Use load(.duration) instead
/Users/runner/work/oncue/oncue/Packages/OnCueCore/Sources/OnCueCore/Media/ItemMedia.swift:84:33: warning: 'tracks(withMediaType:)' was deprecated in macOS 13.0: Use loadTracks(withMediaType:) instead
2026-11-12 09:09:53.026 appintentsmetadataprocessor[5595:19455] warning: Metadata extraction skipped. No AppIntents.framework dependency found.
```
## Smoke test
```
[smoke] app launched (pid 5659)
[smoke] machine profile created at /Users/runner/work/_temp/smoke/profile/MachineProfile.json
[smoke] new show opened (type com.nishanpani.oncue.show, windows: 1)
[smoke] saved to /Users/runner/work/_temp/smoke/smoke.oncue
[smoke] window closed
[smoke] saved file verified: format 1, 1 item(s), 4 camera(s)
[smoke] reopened smoke.oncue (windows: 1)
[smoke] PASS: create, save, close and reopen all succeeded
```
## DMG
```
/Users/runner/work/oncue/oncue/Packages/OnCueCore/Sources/OnCueCore/Media/ItemMedia.swift:83:47: warning: 'duration' was deprecated in macOS 13.0: Use load(.duration) instead
/Users/runner/work/oncue/oncue/Packages/OnCueCore/Sources/OnCueCore/Media/ItemMedia.swift:84:33: warning: 'tracks(withMediaType:)' was deprecated in macOS 13.0: Use loadTracks(withMediaType:) instead
/Users/runner/work/oncue/oncue/OnCue/Workspace/MediaPlayer.swift:134:36: warning: 'isPlayable' was deprecated in macOS 13.0: Use load(.isPlayable) instead
** BUILD SUCCEEDED **
build/Release/Build/Products/Release/OnCue.app: valid on disk
build/Release/Build/Products/Release/OnCue.app: satisfies its Designated Requirement
Signature=adhoc
TeamIdentifier=not set
Runtime Version=15.5.0
hdiutil: verify: checksum of "/Users/runner/work/_temp/dist/OnCue-0.1.0-1.dmg" is VALID
Made /Users/runner/work/_temp/dist/OnCue-0.1.0-1.dmg (2.7M)
total 5560
drwxr-xr-x   3 runner  staff       96 Nov 12 09:13 .
drwxr-xr-x  15 runner  staff      480 Nov 12 09:13 ..
-rw-r--r--@  1 runner  staff  2844547 Nov 12 09:13 OnCue-0.1.0-1.dmg
```
