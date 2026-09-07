# Validation record — September 7, 2026

## Passed

- `swift build`: VectorCore compiled with Swift 6.3.3 on macOS.
- `sh scripts/verify-core.sh`: all 13 shared analytics and persistence test bodies passed. Covers baseline minimum, duplicate dates, missing signals, fatigue response, score bounds, nonlinear strain aggregation, HR gaps, zone boundaries, overlapping sleep, sleep debt/planning, next-day journal matching, evidence thresholds, catalogs and workload validation. Additional checks cover Monday-based weeks across DST, duplicate/future logs, completion integrity after edits/deletions, legacy JSON migration and round-trip persistence, and daily-weighted trend coverage.
- Swift frontend parsing of all iOS and Watch source files.
- `xcodegen generate`: generated Vector.xcodeproj and platform Info.plist files.
- `plutil -lint`: project file, both Info.plists and both entitlements passed.
- Visual inspection of the design concept board. It is an illustrative reference with fictional data, not a rendered native app.

## Local environment limits and remaining verification

- `swift test` cannot run in this environment: `no such module 'XCTest'`. The same test bodies passed through the standalone adapter; retain XCTest for Xcode environments.
- Local native builds remain unavailable: Xcode is absent (`xcode-select -p` points to `/Library/Developer/CommandLineTools`). Full SDK build is now verified in CI.
- Simulator/physical-device UI tests, HealthKit permission/import behavior, Watch background lifecycle and saving, Apple Intelligence generation, PDF rendering and accessibility.
- Scientific validation of recovery/strain/sleep/stress/healthspan estimates. Prototype formulas must not be described as validated.

Do not infer shipping readiness from source parsing or the concept board. The device-ready gate in PRODUCT_PLAN.md remains open.

## CI

[Native build run 34115219398](https://github.com/g-popov16/vector/actions/runs/34115219398) passed on source commit `0b15e27`: 13 XCTest tests and a full unsigned iPhone/embedded Watch simulator build on `macos-26`. The first SDK run found a CGFloat type ambiguity in the PDF renderer, which was corrected before this successful run. This does not test hardware sensors, live model availability, signing, installation or rendered UI.
