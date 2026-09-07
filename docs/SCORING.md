# VECTOR scoring v0.1

All models here are independently chosen prototype heuristics. They are not reverse-engineered WHOOP/Bevel scores and are not clinical assessments.

## Recovery

Require at least 14 unique prior days of positive finite HRV and resting HR, within 28 calendar days. Current-day HRV, resting HR and sleep must exist; missing required values yield no score. Historical duplicate days count once.

Compute clipped z-scores (−2…2) for log(HRV), resting HR and respiratory rate. Standard-deviation floors are 0.12 log units, 3 bpm and 0.5 breaths/min to prevent a nearly constant baseline from amplifying noise.

`score = clamp(70 + 12 × z(log HRV) − 8 × z(RHR) + 25 × (min(sleep/need, 1) − 1) − 5 × max(z(respiration), 0), 0, 100)`

Respiration penalty is omitted and disclosed when fewer than 14 valid reference days or no current value exist. A baseline day with full sleep scores 70 by design. Coefficients, floors and thresholds need longitudinal validation. Score versioning, source selection and fixed overnight windows remain release requirements.

## Cardiovascular load and strain

Zones use percent of editable maximum HR: below 50%, 50–60%, 60–70%, 70–80%, 80–90%, and 90%+. Their per-minute weights are 0, 0.5, 1, 2, 3 and 5.

`strain = 21 × (1 − exp(−weightedMinutes/100))`

Add weighted minutes before transforming; never add strain scores. Only measured intervals count. A heart-rate sample may carry forward for at most 15 seconds; longer gaps remain unknown. Zone percentages use observed time, and observed coverage uses full elapsed time. This deliberately undercounts sparse daily data and must be labeled. Current importer needs paused-workout interval exclusions and duplicate-source selection before production use.

## Sleep

Merge overlapping intervals; awake takes precedence over sleep, specific stages over unspecified. The current precedence between conflicting specific stages is deterministic rather than a validated source preference. Prefer one device/source in the production importer.

Efficiency = asleep time / first-to-last observed segment window. It is not necessarily time in bed, because many sources do not supply true bed opportunity. Performance = min(100%, asleep/estimated need).

Debt = max(0, sum(baseline − actual)) over the last seven **available** nights. Missing nights are not treated as zero sleep. This is a simple prototype; complete calendar coverage and a validated debt-decay approach are planned.

Need = baseline + up to 1 h debt repayment + up to 45 min load allowance, clamped to 6–10 h. Peak, Perform and Get by budget 100%, 90% and 80% of need plus 20 min latency. This is not a personalized circadian model or an alarm implementation.

## Strength and workload

Session workload = minutes × RPE (1–10), in arbitrary units. Set volume = reps × kilograms. The app keeps these separate from cardiac strain pending a defensible muscular-load model. Kilograms lifted are not a directly comparable physiological load across exercises or people.

## Journal associations

Match behavior date D to recovery on D+1 in the local calendar. Ignore skipped answers and missing recovery. Require ≥30 matched dates, ≥10 exposed and ≥10 unexposed. Show mean recovery difference. This is an unadjusted association without causal interpretation, confidence intervals, covariate adjustment or multiple-testing correction. Those are required before stronger impact claims.
