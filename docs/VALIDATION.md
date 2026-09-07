# Validation record — September 7, 2026

## Passed

- `swift build`: VectorCore compiled with Swift 6.3.3 on macOS.
- `sh scripts/verify-core.sh`: all eight shared analytics test bodies passed. Covers baseline minimum, duplicate dates, missing signals, fatigue response, score bounds, nonlinear strain aggregation, HR gaps, zone boundaries, overlapping sleep, sleep debt/planning, next-day journal matching, evidence thresholds, catalogs and workload validation.
- Swift frontend parsing of all iOS and Watch source files.
- `xcodegen generate`: generated Vector.xcodeproj and platform Info.plist files.
- `plutil -lint`: project file, both Info.plists and both entitlements passed.
- Visual inspection of the design concept board. It is an illustrative reference with fictional data, not a rendered native app.

## Not passed / not available

- `swift test` cannot run in this environment: `no such module 'XCTest'`. The same test bodies passed through the standalone adapter; retain XCTest for Xcode environments.
- Full native build and SDK type checking: Xcode is absent (`xcode-select -p` points to `/Library/Developer/CommandLineTools`).
- Simulator/physical-device UI tests, HealthKit permission/import behavior, Watch background lifecycle and saving, Apple Intelligence generation, PDF rendering and accessibility.
- Scientific validation of recovery/strain/sleep/stress/healthspan estimates. Prototype formulas must not be described as validated.

Do not infer shipping readiness from source parsing or the concept board. The device-ready gate in PRODUCT_PLAN.md remains open.
