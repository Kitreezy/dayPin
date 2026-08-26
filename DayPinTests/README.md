# DayPinTests — snapshot & layout regression suite

Guards the UI against silent visual regressions. Built on
[swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing) (SPM).

## Running

```bash
xcodebuild -scheme DayPin \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro Test' test
```

Or `⌘U` in Xcode.

## What is covered

| Suite | Guards |
|---|---|
| `CardCellSnapshotTests` | Text/Image/Link cells, empty comment, long text truncation, multi-select overlay |
| `ThemeSnapshotTests` | Cards across the palette extremes (violet / spring / vintage) + `accentContrast` resolving per interface style |
| `ComponentSnapshotTests` | `SkeletonView` resting colours |
| `EmptyCardCellLayoutTests` | Layout-only guard for the Lottie empty state (see below) |

Every snapshot is recorded in **both light and dark**, so a change that only
breaks one mode still fails.

## Determinism

`SnapshotCase` pins four ambient inputs in `setUp`, because each one would
otherwise make the same UI render differently between runs or machines:

1. **`createdAt`** — cells print it as `HH:mm`; fixtures use a fixed date
2. **Time zone** — forced to UTC, otherwise `09:41` becomes `12:41` three zones east
3. **Language** — forced to `en`, otherwise `L10n` follows the system locale
4. **Accent scheme** — forced to `.violet`, otherwise `DayPinDesign` colours drift

All four are restored in `tearDown`.

## Re-recording after an intentional design change

Delete the affected baselines and run the suite once — missing references are
recorded automatically (the run fails by design), then run again to confirm green:

```bash
rm -rf DayPinTests/__Snapshots__      # or just the files you changed
xcodebuild ... test                   # records, reports failure
xcodebuild ... test                   # passes
```

**Review the regenerated PNGs in the diff before committing.** A recorded
baseline is only as good as the UI it captured.

## Why EmptyCardCell has no snapshot

It hosts a Lottie animation that has not drawn its first frame by the time the
snapshot is taken — the reference captured a half-drawn shape that proved
nothing and would flake on any timing change. It is covered by
`EmptyCardCellLayoutTests` instead, which measures the cell's required height
against the estimate used in `TodayViewController.makeLayout()`. That is the
exact regression that once made UIKit break the animation view's height
constraint at runtime.

If the empty-state layout changes on purpose, update `layoutEstimatedHeight`
in that test to match the new value in `makeLayout()`.
