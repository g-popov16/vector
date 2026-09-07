# VECTOR — personal performance system

## Product decisions

- Native iPhone app and Apple Watch companion; iPhone 17 Pro Max and Apple Watch Ultra 2 are the reference devices.
- iOS 26 / watchOS 26 minimum, using the stable APIs available in those SDKs. Confirm installed SDK/device versions in Xcode before signing.
- Balanced strength, cardiovascular training, sleep, and recovery.
- Apple Intelligence's on-device `SystemLanguageModel`; no cloud provider, account, subscription tier, or API key.
- Working name VECTOR. This is not a WHOOP or Bevel clone; use independently documented scoring and original visual identity.
- Flat graphite, bone-white text, acid-lime status accent, ice-blue sleep and restrained orange load. Native San Francisco and monospaced numeric labels. No gradients, glow, generic AI iconography, testimonials, or landing-page furniture.

## Experience

Five destinations: **Today**, **Train**, **Sleep**, **Journal**, **Coach**. Health Monitor sits under Today; calibration is available from the toolbar. The Watch focuses on fast workout capture with readable numbers and minimal interaction.

First run: explain on-device processing → request specific HealthKit types → import history → show source/freshness and missing data → calibrate maximum HR and sleep baseline → build recovery baseline. The example dataset is deliberately opt-in and prominently labeled.

Daily loop: inspect recovery and sleep → choose training → capture on Watch or log manually → review zones/load → log a handful of behaviors → plan bedtime. Weekly loop: review accumulated load, consistency and changes, then schedule the coming week.

## Feature coverage and delivery gates

“Source implemented” means code exists, not that the iOS/watchOS build or hardware behavior has been validated. This Mac currently has no Xcode or Apple platform SDKs.

| Requested feature | Current implementation | Remaining work / acceptance condition |
|---|---|---|
| Recovery 0–100 | Tested experimental baseline engine; native explanation view | Validate nightly sampling window and source selection against real history; freeze/version daily results; test model behavior longitudinally |
| Daily/per-workout strain 0–21 | Tested saturating load curve, HR zones and explicit observed coverage; native daily and workout views | Calibrate against representative workouts; validate source deduplication, paused sessions and sparse non-workout HR; daily score is currently observed lower-bound load |
| Sleep stages | HealthKit import, interval deduplication and chart source | Explicit preferred source, split noon-crossing samples, separate naps, daylight-saving/travel/shift-work cases |
| Sleep debt, efficiency, need, performance | Tested transparent heuristics; native planner | Validate sleep opportunity, debt decay, incomplete-week coverage and personal sleep need; current efficiency is observed-window efficiency |
| Activity library/manual logging | 61 activities, dated session-RPE log, editable existing logs and strength sets, saved locally | Richer activity metadata, opt-in HealthKit writeback for manual logs |
| Automatic activity detection | Imported Apple Health workouts appear without duplicate local creation | Independent motion-based detection, user confirmation, battery testing; Apple Workout reminders are not a generic third-party detection API |
| HR zone minutes and percentages | Tested zones and explicit unknown minutes; native workout detail; Watch live zone | Custom zone boundaries/HR reserve/threshold modes; pause-aware integration; device validation |
| Steps/calories/VO₂ max/trends | HealthKit totals, latest VO₂ max, HRV/RHR/sleep charts; up to 180 days imported | VO₂ max, step and calorie history charts, source priority checks, normalized 30/180-day change summaries |
| Generative personal coach | Apple Foundation Models source, availability states, bounded personal context, no cloud route | Run on phone; test refusal/locale/model-not-ready cases, prompt injection, numerical grounding and safe training advice |
| Sleep planner: peak/perform/get by | Persistent wake time and three estimated sleep budgets | Infer circadian regularity, account for naps and shift work; currently not an alarm |
| Real-time Strain Coach | Watch live observed strain and HR zone | Personal target selection, target haptics, mirrored phone session, pause-aware targets |
| Strength Trainer/muscular load | Exercise/reps/weight sets and session RPE workload | Set RPE/RIR, exercise library, rest timer, supersets, Watch editing and calibrated muscular contribution; do not equate tonnage to cardiovascular strain |
| Haptic alarm at fixed time | Not implemented | Smart-alarm runtime session plus scheduled system fallback; reboot, force-quit, battery, foreground and overnight validation |
| Sleep-goal/recovery-triggered alarm | Feasibility constrained | Delayed sleep staging and HRV cannot support guaranteed live target detection. Prototype supported motion/HR wake window; always show latest scheduled deadline. Do not promise wake-at-recovery |
| Weekly Plan / Performance Assessment | Persistent Monday-based calendar, scheduled sessions, linked completions, planned-vs-logged daily load, prior-week comparison; coach sees the current plan | Imported workout effort linkage, longer historical load/ramp metrics, sleep/recovery weekly assessment |
| Journal 160+ behaviors | 170 unique behaviors; daily yes/no/skip, selection, persistence; tested next-day association estimator | Covariate adjustment, uncertainty intervals, multiple-comparison control, quantity/time inputs; present results as associations |
| Health Monitor | Latest HRV/RHR/respiration/wrist temperature/oxygen/VO₂ max with sample time/source; 30/180-day charts and first/last seven-day comparisons with coverage counts | Source-specific ranges, outlier handling, preferred-source comparisons. Readings are not all live |
| Shareable PDF | Native paginated PDF source with latest data and available history, system share sheet | Device rendering, export lifecycle cleanup, protected-file handling and pagination review |
| Stress Monitor + breathing | Native two-minute guided breathing session | Calibrated momentary autonomic-load estimate with motion gating; on-demand measurement; not continuous emotional-stress inference |
| Healthspan / physiological age / pace of aging | Research gate; no invented age shown | Pick an independently supportable reference model, required input set, validation population and uncertainty. Age gate under 18. Apple Watch data alone must not be marketed as measured biological aging |

## Architecture

`VectorCore` is pure Swift, shared by iPhone and Watch. It owns deterministic scoring, zone integration, sleep intervals, journal association and training models. `Apps/iOS` owns SwiftUI, HealthKit import, local state, PDF rendering and Foundation Models. `Apps/Watch` owns workout session lifecycle and live display.

The prototype uses a versioned (v2, with legacy migration) protected JSON file in Application Support, excluded from backup. Before a large real-world rollout, migrate to versioned SwiftData models with a tested migration path. Keep HealthKit authoritative, maintain persistent anchored-query cursors per type, process deletions, record source UUIDs and revisions, and recompute affected days. Do not keep refetching 180 days in production.

Recovery input windows must be finalized before treating the score as stable. Current HRV/RHR aggregation is calendar-day based; production should use consistent, source-specific overnight/resting windows, separate daytime mindful measurements, avoid mixing source scales, and freeze the morning result while still allowing explained corrections.

Use WatchConnectivity for calibration, planned sessions and live UI mirroring; HealthKit sync for completed workouts. Handle unreachable phone, retries, duplicate deliveries and deletion. Add App Intents for Ultra Action button, WidgetKit complications, workout recovery after process termination, and accessibility sizing.

## Delivery sequence

1. **Foundation (this repository):** product plan, original native interface, shared tested engine, HealthKit source, local journal/training, local coach, Watch capture source, project generation.
2. **Device-ready vertical slice:** install Xcode, compile with full SDKs, sign to your Apple account, run on iPhone/Ultra 2, validate real imports and empty/partial permissions, fix lifecycle and layout issues, compare timestamps/totals with Apple Health.
3. **Reliable daily analytics:** anchored/background ingestion, chosen source and overnight windows, snapshots, deletion propagation, confidence/coverage, 30/180-day trends, reproducible exports.
4. **Training and planning:** durable weekly plan, rest/set workflow, muscular model, live strain targets, WatchConnectivity, Action button, workout recovery and auto-detection prototype.
5. **Sleep and behaviors:** circadian planner, alarm feasibility prototype with reliable fallback, adjusted journal associations, context-aware stress experiments.
6. **Longitudinal validation:** scoring calibration, healthspan model selection/age gating, accessibility and battery review, personal beta, then optional TestFlight distribution.

No premium feature paywalls are planned. The likely external requirement for broader distribution is Apple developer signing; cloud model costs are absent.

## Verification before personal beta

- Full Xcode build with warnings reviewed; phone and Watch installation.
- Permissions: no data, partial read access, revoked access, write denial, locked device.
- History: midnight/noon crossing, DST, time-zone travel, overlapping sleep sources, HR gaps and duplicate workouts.
- Watch: start, pause, resume, finish, Health sync, Bluetooth loss, app termination, low power, wrist down and long sessions.
- Coaching: model absent/downloading/disabled, bounded context, no invented values, no tool-action claims.
- Privacy: no network egress, protected persistence, delete/export flows, no biometric console logs.
- UI: VoiceOver, large text, reduced motion, one-handed operation and outdoor Watch contrast.
- No physiological-age, diagnostic or guaranteed alarm claim without its evidence gate.

## Primary references checked September 7, 2026

- [HealthKit data types](https://developer.apple.com/documentation/healthkit/data-types)
- [HealthKit read-permission privacy](https://developer.apple.com/documentation/HealthKit/authorizing-access-to-health-data)
- [Apple Watch heart-rate measurement behavior](https://support.apple.com/en-mide/120277)
- [Overnight vitals and regional availability](https://support.apple.com/en-ie/120142)
- [Workout builder](https://developer.apple.com/documentation/healthkit/hkliveworkoutbuilder)
- [Extended runtime sessions](https://developer.apple.com/documentation/watchkit/wkextendedruntimesession)
- [On-device system language model](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel)
- [Language model session](https://developer.apple.com/documentation/FoundationModels/LanguageModelSession)
- [Foundation Models acceptable use](https://developer.apple.com/support/terms/acceptable-use-requirements-for-the-foundation-models-framework/)
- [WHOOP feature reference](https://www.whoop.com/us/en/thelocker/10-whoop-features-you-need-to-know/)

These establish platform capability, not scientific validation of VECTOR’s experimental formulas.
