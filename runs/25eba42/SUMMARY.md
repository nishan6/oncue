# CI results for 25eba42

- Commit: 25eba42c5e9ecd64f19ab847a4cd341f51d03fa7
- Run: https://github.com/nishan6/oncue/actions/runs/43388071895
- Date (UTC): 2026-11-13T07:55:08Z

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
Test Suite 'TimelineTests' passed at 2026-11-13 07:46:50.986.
	 Executed 11 tests, with 0 failures (0 unexpected) in 0.007 (0.007) seconds
Test Case '-[OnCueCoreTests.TourTests testLoadLogsFromFolder]' passed (0.016 seconds).
Test Case '-[OnCueCoreTests.TourTests testNightsCompared]' passed (0.003 seconds).
Test Case '-[OnCueCoreTests.TourTests testOldLogsWithoutTourFieldsStillOpen]' passed (0.015 seconds).
Test Suite 'TourTests' passed at 2026-11-13 07:46:51.021.
	 Executed 3 tests, with 0 failures (0 unexpected) in 0.035 (0.035) seconds
Test Case '-[OnCueCoreTests.TriggerLearnTests testLearnedInputMatchesItsEvent]' passed (0.000 seconds).
Test Suite 'TriggerLearnTests' passed at 2026-11-13 07:46:51.022.
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
Test Suite 'TriggerRouteTests' passed at 2026-11-13 07:46:51.025.
	 Executed 11 tests, with 0 failures (0 unexpected) in 0.003 (0.003) seconds
Test Case '-[OnCueCoreTests.UpcomingCallTests testCallsAndPlayerCuesInOrder]' passed (0.000 seconds).
Test Suite 'UpcomingCallTests' passed at 2026-11-13 07:46:51.025.
	 Executed 1 test, with 0 failures (0 unexpected) in 0.000 (0.000) seconds
Test Case '-[OnCueCoreTests.UpdateCheckTests testDMGNames]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.UpdateCheckTests testNeverChecksDuringLiveMode]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.UpdateCheckTests testNoOfferWhenSameOlderSkippedDraftOrWithoutDMG]' passed (0.001 seconds).
Test Case '-[OnCueCoreTests.UpdateCheckTests testOffersANewerRelease]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.UpdateCheckTests testProfileKeepsUpdateAndAccessibilitySettings]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.UpdateCheckTests testVersionsCompareNumerically]' passed (0.000 seconds).
Test Suite 'UpdateCheckTests' passed at 2026-11-13 07:46:51.027.
	 Executed 6 tests, with 0 failures (0 unexpected) in 0.002 (0.002) seconds
Test Case '-[OnCueCoreTests.VersionTests testBackupFolder]' passed (0.016 seconds).
Test Case '-[OnCueCoreTests.VersionTests testSaveRestoreAndLimits]' passed (0.075 seconds).
Test Suite 'VersionTests' passed at 2026-11-13 07:46:51.119.
	 Executed 2 tests, with 0 failures (0 unexpected) in 0.091 (0.091) seconds
Test Case '-[OnCueCoreTests.WaveBProtocolTests testPanasonic]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.WaveBProtocolTests testRolandV160Replies]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.WaveBProtocolTests testRolandV60Tally]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.WaveBProtocolTests testRossTalk]' passed (0.000 seconds).
Test Suite 'WaveBProtocolTests' passed at 2026-11-13 07:46:51.119.
	 Executed 4 tests, with 0 failures (0 unexpected) in 0.001 (0.001) seconds
Test Suite 'OnCueCorePackageTests.xctest' passed at 2026-11-13 07:46:51.119.
	 Executed 278 tests, with 0 failures (0 unexpected) in 9.754 (9.770) seconds
Test Suite 'All tests' passed at 2026-11-13 07:46:51.120.
	 Executed 278 tests, with 0 failures (0 unexpected) in 9.754 (9.771) seconds
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
2026-11-13 07:49:41.697 appintentsmetadataprocessor[9448:30314] warning: Metadata extraction skipped. No AppIntents.framework dependency found.
```
## Smoke test
```
[smoke] app launched (pid 9540)
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
/Users/runner/work/oncue/oncue/OnCue/Workspace/MediaPlayer.swift:134:36: warning: 'isPlayable' was deprecated in macOS 13.0: Use load(.isPlayable) instead
/Users/runner/work/oncue/oncue/OnCue/Workspace/MediaPoolView.swift:150:69: warning: 'duration' was deprecated in macOS 13.0: Use load(.duration) instead
** BUILD SUCCEEDED **
build/Release/Build/Products/Release/OnCue.app: valid on disk
build/Release/Build/Products/Release/OnCue.app: satisfies its Designated Requirement
Signature=adhoc
TeamIdentifier=not set
Runtime Version=15.5.0
Architectures: x86_64 arm64
hdiutil: verify: checksum of "/Users/runner/work/_temp/dist/OnCue-0.1.0-132.dmg" is VALID
Made /Users/runner/work/_temp/dist/OnCue-0.1.0-132.dmg ( 10M)
total 20928
drwxr-xr-x   3 runner  staff        96 Nov 13 07:54 .
drwxr-xr-x  15 runner  staff       480 Nov 13 07:54 ..
-rw-r--r--@  1 runner  staff  10713168 Nov 13 07:55 OnCue-0.1.0-132.dmg
```
