# CI results for 6c6c63f

- Commit: 6c6c63f049d1ec2d3b320ea3b10cd0e28faea1ab
- Run: https://github.com/nishan6/oncue/actions/runs/43259237905
- Date (UTC): 2026-11-12T16:41:29Z

| Step | Result |
| --- | --- |
| Generate project | success (project changed: true) |
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
Test Suite 'ShotVocabularyTests' passed at 2026-11-12 16:30:47.864.
	 Executed 7 tests, with 0 failures (0 unexpected) in 0.004 (0.004) seconds
Test Case '-[OnCueCoreTests.ShowControlTests testAnalysisMatchesScriptedShotsToCuts]' passed (0.003 seconds).
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
Test Case '-[OnCueCoreTests.ShowControlTests testSubSwitcherRoutesThroughItsFeed]' passed (0.001 seconds).
Test Case '-[OnCueCoreTests.ShowControlTests testVarietyHintsPreferCamerasOffAirLongest]' passed (0.000 seconds).
Test Suite 'ShowControlTests' passed at 2026-11-12 16:30:47.873.
	 Executed 14 tests, with 0 failures (0 unexpected) in 0.008 (0.009) seconds
Test Case '-[OnCueCoreTests.TempoMapTests testTicksBeatsSeconds]' passed (0.000 seconds).
Test Suite 'TempoMapTests' passed at 2026-11-12 16:30:47.873.
	 Executed 1 test, with 0 failures (0 unexpected) in 0.000 (0.000) seconds
Test Case '-[OnCueCoreTests.TempoTests testDetectsTempoAndFirstBeat]' passed (1.150 seconds).
Test Case '-[OnCueCoreTests.TempoTests testSilenceHasNoTempo]' passed (0.072 seconds).
Test Suite 'TempoTests' passed at 2026-11-12 16:30:49.096.
	 Executed 2 tests, with 0 failures (0 unexpected) in 1.222 (1.222) seconds
Test Case '-[OnCueCoreTests.TimecodeTests testDropFrameKnownValues]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.TimecodeTests testDropFrameRoundTripsEveryFrameOfAnHour]' passed (0.213 seconds).
Test Case '-[OnCueCoreTests.TimecodeTests testNonDropFrame]' passed (0.000 seconds).
Test Suite 'TimecodeTests' passed at 2026-11-12 16:30:49.309.
	 Executed 3 tests, with 0 failures (0 unexpected) in 0.213 (0.214) seconds
Test Case '-[OnCueCoreTests.TimelineTests testCameraColourDefaultsByNumberAndCanBeChosen]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.TimelineTests testCameraColourRoundTripsAndIsOptionalInOldFiles]' passed (0.002 seconds).
Test Case '-[OnCueCoreTests.TimelineTests testLiveCursorSteppingAndJumping]' passed (0.003 seconds).
Test Case '-[OnCueCoreTests.TimelineTests testMovingAShotOnTheTimelineReordersTheShotList]' passed (0.001 seconds).
Test Case '-[OnCueCoreTests.TimelineTests testOrderItemsGiveEachShotOneStep]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.TimelineTests testPlannedLengthExtendsTheEnd]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.TimelineTests testRunLength]' passed (0.002 seconds).
Test Case '-[OnCueCoreTests.TimelineTests testSampleShowHasEveryTrackKind]' passed (0.002 seconds).
Test Case '-[OnCueCoreTests.TimelineTests testShotSpansRunToTheNextShotAndTheSongEnd]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.TimelineTests testSnap]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.TimelineTests testTrackCuesAreCreatedOnTheRightTrack]' passed (0.001 seconds).
Test Suite 'TimelineTests' passed at 2026-11-12 16:30:49.322.
	 Executed 11 tests, with 0 failures (0 unexpected) in 0.012 (0.012) seconds
Test Case '-[OnCueCoreTests.TourTests testLoadLogsFromFolder]' passed (0.023 seconds).
Test Case '-[OnCueCoreTests.TourTests testNightsCompared]' passed (0.004 seconds).
Test Case '-[OnCueCoreTests.TourTests testOldLogsWithoutTourFieldsStillOpen]' passed (0.018 seconds).
Test Suite 'TourTests' passed at 2026-11-12 16:30:49.367.
	 Executed 3 tests, with 0 failures (0 unexpected) in 0.045 (0.045) seconds
Test Case '-[OnCueCoreTests.UpcomingCallTests testCallsAndPlayerCuesInOrder]' passed (0.000 seconds).
Test Suite 'UpcomingCallTests' passed at 2026-11-12 16:30:49.368.
	 Executed 1 test, with 0 failures (0 unexpected) in 0.000 (0.000) seconds
Test Case '-[OnCueCoreTests.VersionTests testBackupFolder]' passed (0.020 seconds).
Test Case '-[OnCueCoreTests.VersionTests testSaveRestoreAndLimits]' passed (0.086 seconds).
Test Suite 'VersionTests' passed at 2026-11-12 16:30:49.474.
	 Executed 2 tests, with 0 failures (0 unexpected) in 0.106 (0.107) seconds
Test Suite 'OnCueCorePackageTests.xctest' passed at 2026-11-12 16:30:49.474.
	 Executed 194 tests, with 0 failures (0 unexpected) in 10.471 (10.483) seconds
Test Suite 'All tests' passed at 2026-11-12 16:30:49.475.
	 Executed 194 tests, with 0 failures (0 unexpected) in 10.471 (10.486) seconds
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
2026-11-12 16:35:40.276 appintentsmetadataprocessor[9484:29853] warning: Metadata extraction skipped. No AppIntents.framework dependency found.
```
## Smoke test
```
[smoke] app launched (pid 9501)
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
Made /Users/runner/work/_temp/dist/OnCue-0.1.0-1.dmg (3.6M)
total 7368
drwxr-xr-x   3 runner  staff       96 Nov 12 16:41 .
drwxr-xr-x  15 runner  staff      480 Nov 12 16:41 ..
-rw-r--r--@  1 runner  staff  3769626 Nov 12 16:41 OnCue-0.1.0-1.dmg
```
