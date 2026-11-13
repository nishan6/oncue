# CI results for 7bfa12c

- Commit: 7bfa12ca321feda2f38b7239ab652436a2c35b69
- Run: https://github.com/nishan6/oncue/actions/runs/43361020295
- Date (UTC): 2026-11-13T03:52:52Z

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
Test Suite 'TallyStateTests' passed at 2026-11-13 03:46:14.568.
	 Executed 3 tests, with 0 failures (0 unexpected) in 0.000 (0.001) seconds
Test Case '-[OnCueCoreTests.TempoMapTests testTicksBeatsSeconds]' passed (0.000 seconds).
Test Suite 'TempoMapTests' passed at 2026-11-13 03:46:14.568.
	 Executed 1 test, with 0 failures (0 unexpected) in 0.000 (0.000) seconds
Test Case '-[OnCueCoreTests.TempoTests testDetectsTempoAndFirstBeat]' passed (0.715 seconds).
Test Case '-[OnCueCoreTests.TempoTests testSilenceHasNoTempo]' passed (0.053 seconds).
Test Suite 'TempoTests' passed at 2026-11-13 03:46:15.336.
	 Executed 2 tests, with 0 failures (0 unexpected) in 0.768 (0.768) seconds
Test Case '-[OnCueCoreTests.TimecodeTests testDropFrameKnownValues]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.TimecodeTests testDropFrameRoundTripsEveryFrameOfAnHour]' passed (0.175 seconds).
Test Case '-[OnCueCoreTests.TimecodeTests testNonDropFrame]' passed (0.000 seconds).
Test Suite 'TimecodeTests' passed at 2026-11-13 03:46:15.512.
	 Executed 3 tests, with 0 failures (0 unexpected) in 0.176 (0.176) seconds
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
Test Suite 'TimelineTests' passed at 2026-11-13 03:46:15.520.
	 Executed 11 tests, with 0 failures (0 unexpected) in 0.007 (0.008) seconds
Test Case '-[OnCueCoreTests.TourTests testLoadLogsFromFolder]' passed (0.016 seconds).
Test Case '-[OnCueCoreTests.TourTests testNightsCompared]' passed (0.003 seconds).
Test Case '-[OnCueCoreTests.TourTests testOldLogsWithoutTourFieldsStillOpen]' passed (0.015 seconds).
Test Suite 'TourTests' passed at 2026-11-13 03:46:15.554.
	 Executed 3 tests, with 0 failures (0 unexpected) in 0.035 (0.035) seconds
Test Case '-[OnCueCoreTests.TriggerLearnTests testLearnedInputMatchesItsEvent]' passed (0.000 seconds).
Test Suite 'TriggerLearnTests' passed at 2026-11-13 03:46:15.555.
	 Executed 1 test, with 0 failures (0 unexpected) in 0.000 (0.000) seconds
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
Test Suite 'TriggerRouteTests' passed at 2026-11-13 03:46:15.558.
	 Executed 11 tests, with 0 failures (0 unexpected) in 0.003 (0.003) seconds
Test Case '-[OnCueCoreTests.UpcomingCallTests testCallsAndPlayerCuesInOrder]' passed (0.000 seconds).
Test Suite 'UpcomingCallTests' passed at 2026-11-13 03:46:15.558.
	 Executed 1 test, with 0 failures (0 unexpected) in 0.000 (0.000) seconds
Test Case '-[OnCueCoreTests.VersionTests testBackupFolder]' passed (0.014 seconds).
Test Case '-[OnCueCoreTests.VersionTests testSaveRestoreAndLimits]' passed (0.073 seconds).
Test Suite 'VersionTests' passed at 2026-11-13 03:46:15.646.
	 Executed 2 tests, with 0 failures (0 unexpected) in 0.087 (0.087) seconds
Test Suite 'OnCueCorePackageTests.xctest' failed at 2026-11-13 03:46:15.646.
	 Executed 244 tests, with 1 failure (0 unexpected) in 9.646 (9.658) seconds
Test Suite 'All tests' failed at 2026-11-13 03:46:15.646.
	 Executed 244 tests, with 1 failure (0 unexpected) in 9.646 (9.661) seconds
✔ Test run with 0 tests passed after 0.001 seconds.
```
## Build result
```
** BUILD SUCCEEDED **
```
## Warnings (       7)
```
/Users/runner/work/oncue/oncue/OnCue/Workspace/MediaPlayer.swift:134:36: warning: 'isPlayable' was deprecated in macOS 13.0: Use load(.isPlayable) instead
/Users/runner/work/oncue/oncue/OnCue/Workspace/MediaPoolView.swift:150:69: warning: 'duration' was deprecated in macOS 13.0: Use load(.duration) instead
/Users/runner/work/oncue/oncue/Packages/OnCueCore/Sources/OnCueCore/Media/ItemMedia.swift:44:22: warning: 'tracks(withMediaType:)' was deprecated in macOS 13.0: Use loadTracks(withMediaType:) instead
/Users/runner/work/oncue/oncue/Packages/OnCueCore/Sources/OnCueCore/Media/ItemMedia.swift:83:47: warning: 'duration' was deprecated in macOS 13.0: Use load(.duration) instead
/Users/runner/work/oncue/oncue/Packages/OnCueCore/Sources/OnCueCore/Media/ItemMedia.swift:84:33: warning: 'tracks(withMediaType:)' was deprecated in macOS 13.0: Use loadTracks(withMediaType:) instead
/Users/runner/work/oncue/oncue/Packages/OnCueCore/Sources/OnCueCore/Media/TempoDetector.swift:8:33: warning: 'tracks(withMediaType:)' was deprecated in macOS 13.0: Use loadTracks(withMediaType:) instead
2026-11-13 03:48:41.673 appintentsmetadataprocessor[6097:21015] warning: Metadata extraction skipped. No AppIntents.framework dependency found.
```
## Smoke test
```
[smoke] app launched (pid 6113)
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
/Users/runner/work/oncue/oncue/Packages/OnCueCore/Sources/OnCueCore/Media/TempoDetector.swift:8:33: warning: 'tracks(withMediaType:)' was deprecated in macOS 13.0: Use loadTracks(withMediaType:) instead
/Users/runner/work/oncue/oncue/OnCue/Workspace/MediaPlayer.swift:134:36: warning: 'isPlayable' was deprecated in macOS 13.0: Use load(.isPlayable) instead
/Users/runner/work/oncue/oncue/OnCue/Workspace/MediaPoolView.swift:150:69: warning: 'duration' was deprecated in macOS 13.0: Use load(.duration) instead
** BUILD SUCCEEDED **
build/Release/Build/Products/Release/OnCue.app: valid on disk
build/Release/Build/Products/Release/OnCue.app: satisfies its Designated Requirement
Signature=adhoc
TeamIdentifier=not set
Runtime Version=15.5.0
hdiutil: verify: checksum of "/Users/runner/work/_temp/dist/OnCue-0.1.0-1.dmg" is VALID
Made /Users/runner/work/_temp/dist/OnCue-0.1.0-1.dmg (4.3M)
total 8768
drwxr-xr-x   3 runner  staff       96 Nov 13 03:52 .
drwxr-xr-x  15 runner  staff      480 Nov 13 03:52 ..
-rw-r--r--@  1 runner  staff  4489173 Nov 13 03:52 OnCue-0.1.0-1.dmg
```
