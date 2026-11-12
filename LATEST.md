# CI results for af4058a

- Commit: af4058a3786a8e02d1a771e7613c01e40fb8f3e9
- Run: https://github.com/nishan6/oncue/actions/runs/43157890542
- Date (UTC): 2026-11-12T04:56:34Z

| Step | Result |
| --- | --- |
| Generate project | success (project changed: true) |
| Package tests | failure |
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
Test Case '-[OnCueCoreTests.ModelTests testSecondsPositionsParseAndFormat]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.ModelTests testSectionsAndEnds]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.ModelTests testStarterShow]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.ModelTests testTimecodeHelpers]' passed (0.000 seconds).
Test Suite 'ModelTests' passed at 2026-11-12 04:55:54.631.
	 Executed 9 tests, with 0 failures (0 unexpected) in 0.002 (0.002) seconds
Test Case '-[OnCueCoreTests.PersistenceTests testCorruptFileOnDiskIsNotModified]' passed (0.007 seconds).
Test Case '-[OnCueCoreTests.PersistenceTests testEmptyFileGivesClearError]' passed (0.001 seconds).
Test Case '-[OnCueCoreTests.PersistenceTests testEmptyObjectIsAnEmptyShow]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.PersistenceTests testEncodedFileCarriesCurrentSchemaVersion]' passed (0.001 seconds).
Test Case '-[OnCueCoreTests.PersistenceTests testEveryFieldSurvivesRoundTrip]' passed (0.001 seconds).
Test Case '-[OnCueCoreTests.PersistenceTests testFutureSchemaFileIsLeftUntouched]' passed (0.008 seconds).
Test Case '-[OnCueCoreTests.PersistenceTests testFutureSchemaIsRefusedWithClearError]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.PersistenceTests testGoldenFileResavesAsCurrentSchemaAndReopens]' passed (0.001 seconds).
Test Case '-[OnCueCoreTests.PersistenceTests testGoldenSchema0FileOpens]' passed (0.001 seconds).
Test Case '-[OnCueCoreTests.PersistenceTests testJSONArrayIsNotAShow]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.PersistenceTests testMissingFieldsGetDefaults]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.PersistenceTests testMissingFileGivesError]' passed (0.008 seconds).
Test Case '-[OnCueCoreTests.PersistenceTests testNonJSONGivesClearError]' passed (0.000 seconds).
Test Case '-[OnCueCoreTests.PersistenceTests testSaveCloseReopenOnDisk]' passed (0.008 seconds).
Test Case '-[OnCueCoreTests.PersistenceTests testStarterShowRoundTrips]' passed (0.001 seconds).
Test Case '-[OnCueCoreTests.PersistenceTests testUnknownEnumValuesFallBackSafely]' passed (0.001 seconds).
Test Case '-[OnCueCoreTests.PersistenceTests testWrongValueTypeNamesTheField]' passed (0.000 seconds).
Test Suite 'PersistenceTests' passed at 2026-11-12 04:55:54.670.
	 Executed 17 tests, with 0 failures (0 unexpected) in 0.038 (0.039) seconds
/Users/runner/work/oncue/oncue/Packages/OnCueCore/Tests/OnCueCoreTests/ShowControlTests.swift:234: error: -[OnCueCoreTests.ShowControlTests testAnalysisMatchesScriptedShotsToCuts] : XCTAssertEqualWithAccuracy failed: ("-0.1499999761581421") is not equal to ("-0.15000000000000002") +/- ("1e-09")
Test Case '-[OnCueCoreTests.ShowControlTests testAnalysisMatchesScriptedShotsToCuts]' failed (0.364 seconds).
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
Test Suite 'ShowControlTests' failed at 2026-11-12 04:55:55.040.
	 Executed 14 tests, with 1 failure (0 unexpected) in 0.369 (0.369) seconds
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
Test Suite 'TimelineTests' passed at 2026-11-12 04:55:55.049.
	 Executed 11 tests, with 0 failures (0 unexpected) in 0.008 (0.009) seconds
Test Suite 'OnCueCorePackageTests.xctest' failed at 2026-11-12 04:55:55.049.
	 Executed 89 tests, with 1 failure (0 unexpected) in 3.168 (3.172) seconds
Test Suite 'All tests' failed at 2026-11-12 04:55:55.049.
	 Executed 89 tests, with 1 failure (0 unexpected) in 3.168 (3.173) seconds
✔ Test run with 0 tests passed after 0.001 seconds.
```
## Build result
```
** BUILD FAILED **
/Users/runner/work/oncue/oncue/OnCue/Workspace/LiveView.swift:590:21: error: cannot find 'model' in scope
```
## Warnings (0)
```
```
## Smoke test
```
```
