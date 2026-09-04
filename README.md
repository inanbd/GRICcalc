# NICU GIR Calculator

A Flutter app for working out the **glucose infusion rate (GIR)** and fluid
totals for a neonate running several infusions at once.

Enter the baby's weight in grams, add a line for each fluid, and the app keeps a
running total of:

- **Total GIR** in mg/kg/min
- **Total rate** in mL/hr
- **Total fluid** in mL/kg/day

## What it does

- **Multiple fluid lines.** Each line has its own dextrose concentration and
  rate, and shows what it contributes on its own. A stacked bar breaks the total
  GIR down by line, so it is obvious which infusion is carrying the glucose.
- **Either rate unit.** A line can be entered in mL/hr (how the pump is
  programmed) or mL/kg/day (how the order is often written). Switching the unit
  converts the value, so the line keeps running at the same speed.
- **One-tap presets** for the fluids that come up most: D5W through D25W, TPN,
  lipid, saline, and breast milk.
- **Practice flags** when a line runs above 12.5% dextrose (usually central
  access) or the total GIR reaches 12 mg/kg/min.
- **Phone and desktop layouts.** On a phone the totals stay pinned to the bottom
  of the screen while you edit, and tap to expand; on a wide screen they sit in
  their own column. Light and dark themes both supported.

## How it calculates

A dextrose solution labelled `%` carries that many grams per 100 mL. Converting
grams to milligrams and hours to minutes gives:

```
GIR (mg/kg/min) = (rate mL/hr × dextrose %) ÷ (6 × weight kg)
mL/kg/day       = (rate mL/hr × 24) ÷ weight kg
mL/hr           = (mL/kg/day × weight kg) ÷ 24
```

Worked example: D10W at 4 mL/hr in a 1250 g baby is
`(4 × 10) ÷ (6 × 1.25) = 5.33 mg/kg/min`, delivering 76.8 mL/kg/day and 9.6 g of
dextrose a day.

Totals are the sum of every line. Mean dextrose is the volume-weighted
concentration of everything running.

The calculator adds up whatever lines you enter. GIR conventionally refers to
intravenous glucose, so include enteral feeds only if your unit counts them
toward total glucose delivery.

## Running it

```bash
flutter pub get
flutter run              # or: flutter run -d chrome
```

## Tests

```bash
flutter test
```

Covers the calculation layer (conversions, totals, banding, edge cases such as a
missing weight) and the screen itself (entering a weight and fluids, adding
lines, switching rate units, and the safety flags).

## Layout

```
lib/
  logic/gir_calculator.dart   calculations and banding, no Flutter UI
  logic/formatting.dart       number formatting and lenient parsing
  models/fluid_input.dart     a fluid line, rate units, presets
  screens/                    the calculator screen
  widgets/                    weight card, fluid card, results panel, totals bar
  theme.dart                  colour scheme and status colours
```

## Disclaimer

For use by clinicians as a calculation aid only. Check every figure against your
unit's protocol and an independent calculation before acting on it.
