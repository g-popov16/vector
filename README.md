# VECTOR

Native iPhone + Apple Watch fitness app foundation for iPhone 17 Pro Max and Ultra 2. SwiftUI, HealthKit, on-device Apple Intelligence, and an independently documented Swift analytics library. No cloud AI or external package dependency in the app.

**Status:** prototype with 13 passing XCTest tests and a successful full iPhone + embedded Watch simulator build in [GitHub Actions](https://github.com/g-popov16/vector/actions/runs/34115219398). It is not a finished or device-validated app. This development Mac has Command Line Tools but no Xcode; native compilation runs in CI. UI and physical-device testing remain pending. See the complete [feature plan](docs/PRODUCT_PLAN.md) and [formula specification](docs/SCORING.md).

## Open and run

1. Install Xcode with iOS/watchOS SDKs compatible with your devices. Open it once and install the requested components.
2. Select it: `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`.
3. Open `Vector.xcodeproj`. Select your signing team for both app targets and change bundle IDs if needed. Keep the Watch companion ID aligned.
4. Select the **Vector** scheme and your iPhone. Build/run; install the companion on the paired Watch.
5. Connect Apple Health, review permissions, and calibrate maximum HR. Alternatively choose **Explore with demo data**.

The project can be regenerated with `xcodegen generate` from `project.yml`; XcodeGen was installed during setup. Local package sources remain independent of generated project files.

## Verify

```sh
swift build
sh scripts/verify-core.sh
# With full Xcode installed:
swift test
xcodebuild -project Vector.xcodeproj -scheme Vector -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build
```

The standalone runner executes the same 13 test bodies as XCTest and parses native Swift source. It is not a replacement for SDK type checking or device tests.

## Files

- `Sources/VectorCore`: recovery, strain/zones, sleep, journal associations and catalogs.
- `Tests/VectorCoreTests`: deterministic edge-case tests.
- `Apps/iOS`: native screens, protected local storage, HealthKit, Foundation Models coach and paginated PDF export.
- `Apps/Watch`: native live workout capture via `HKWorkoutSession` / `HKLiveWorkoutBuilder`.
- `docs/PRODUCT_PLAN.md`: every requested capability, status, constraints and implementation order.

Demo values are fictional and isolated from journal writes. Manual training is local; Watch workouts save to Apple Health. HealthKit reads cannot distinguish denied access from missing data. The current import is foreground-based and refreshes on app activation; background ingestion and anchored incremental synchronization are planned.

## Planning and trends

Train → Weekly plan supports dated sessions, target effort, notes, linked completed logs and planned/actual workload comparisons. Existing training logs can be edited; deleting a log clears its plan completion. Sleep target and wake time persist locally. Health Monitor supports 30/180-day charts for all six imported vitals, comparing daily means at the start and end with explicit sample coverage.

Local-state schema v2 migrates earlier files without losing journal or training entries. Unreadable or newer-format files are preserved rather than overwritten. `.github/workflows/build.yml` runs core tests and an unsigned native build on GitHub’s macOS runner.
