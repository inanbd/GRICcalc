# NICU GIR Calculator

A Flutter app for working out the **glucose infusion rate (GIR)** and fluid
totals for a neonate running several infusions at once.

Enter the baby's weight in grams, add a line for each fluid, and the app keeps a
running total of:

- **Total GIR** in mg/kg/min
- **Total rate** in mL/hr
- **Total fluid** in mL/kg/day

## What it does

- **Print or copy the result.** Print produces a one-page report with the
  working written out line by line, so a reader can re-derive every figure.
  Copy puts the three GIR values on the clipboard, ready for a note.
- **Light, dark, or whatever the device is doing** - one tap in the app bar,
  remembered between sessions.
- **Several babies at once.** Each patient keeps their own weight and fluid
  list, and the strip across the top switches between them in one tap. Records
  are stored on the device, so the app reopens where it was left.
- **Nothing to save.** Every edit is written as it is typed. There is no save
  button to forget.
- **One tap adds a fluid.** The presets along the bottom create the line
  already named and at the right concentration, leaving only the rate to type.
- **Duplicate a patient** to carry a set of lines over to the next baby -
  useful for twins and for a unit's standard regimen.
- **Feeds, entered the way they are prescribed.** Add a feed as a volume every
  few hours - 20 mL q3h - and it counts towards the day's fluid. Its
  carbohydrate stays out of the GIR unless you switch it on for that line,
  because GIR conventionally means intravenous glucose.
- **Multiple fluid lines.** Each line has its own dextrose concentration and
  rate, and shows what it contributes on its own. A stacked bar breaks the total
  GIR down by line, so it is obvious which infusion is carrying the glucose.
- **Either rate unit.** A line can be entered in mL/hr (how the pump is
  programmed) or mL/kg/day (how the order is often written). Switching the unit
  converts the value, so the line keeps running at the same speed.
- **Presets** for the fluids that come up most: D5W through D25W, TPN, lipid,
  saline, and breast milk.
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

Totals are the sum of every line. Mean IV dextrose is the volume-weighted
concentration of the infusions, feeds excluded, so it can be checked against
what a peripheral line will take.

### Feeds

A feed ordered as a volume every few hours is averaged over the day:

```
feeds per day = 24 ÷ interval hours
mL/hr         = volume per feed ÷ interval hours
```

So 20 mL q3h is 8 feeds, 160 mL a day, and 6.67 mL/hr. That volume always
counts towards the day's fluid.

Its carbohydrate is a different matter. The results report **From IV fluids**
and **From feeds** separately, and only the IV figure is included in the total
until a feed is switched on with *Count towards GIR*. Enteral glucose is an
estimate: how much a baby absorbs is not the same as how much goes down the
tube, and composition varies with fortification and batch. The carbohydrate
percentage is editable on every line, and the presets are typical values from
[infantfeeds.com](https://infantfeeds.com/gir-calculator/) rather than product
data - check them against the label.

## Running it

```bash
flutter pub get
flutter run              # or: flutter run -d chrome
```

## Tests

```bash
flutter test
```

Around a hundred tests, weighted towards the arithmetic, since that is what
gets acted on:

- `calculation_validation_test.dart` checks the GIR against two independently
  derived formulations - one built up from units, one starting from a daily
  volume - across a grid of weights from 400 g to 5 kg, concentrations from
  2.5% to 50%, and rates from 0.1 to 20 mL/hr. It also pins the worked figures
  published by infantfeeds.com, asserts totals never drift from the sum of
  their parts, checks that unit conversions are lossless in both directions,
  and confirms no input - negative, zero, NaN or infinite - can produce a
  negative or non-finite result.
- The rest covers the patient store (auto-save, restoring records,
  duplicating, deleting, surviving corrupt storage), the report and copy text,
  and the screen itself (per-patient records, one-tap switching and adding,
  cursor placement, appearance, rate units, feeds counted in and out of the
  GIR, and the safety flags).

## Website

An ASP.NET Core Razor Pages version of the same calculator lives in
[`web/`](web/), with the same pages plus a contact form that emails the site
owner. The calculator there is client-side JavaScript ported from
`lib/logic/gir_calculator.dart`, so the site and the app agree figure for
figure; nothing typed into it reaches the server. See [web/README.md](web/README.md).

## Releases

Tagging publishes a GitHub Release with the Android APKs attached:

```bash
git tag v1.0.1
git push origin v1.0.1
```

The `Release` workflow formats, analyses and tests the project, builds one APK
per ABI plus a universal one, and uploads them with a `SHA256SUMS.txt`. It can
also be run by hand from the Actions tab against an existing tag.

Most devices want **arm64-v8a**; older 32-bit devices want **armeabi-v7a**;
emulators generally want **x86_64**. The universal APK works anywhere at roughly
triple the size.

## Signing releases

Without a keystore configured, release builds fall back to Android's **debug**
key. They install for sideloading, but the signature says nothing about who
built them, and a later properly signed build will not install over them.

To sign for real, create a keystore and keep it out of the repository:

```bash
keytool -genkey -v -keystore release.jks -keyalg RSA -keysize 2048 \
  -validity 10000 -alias griccalc
```

For local builds, write `android/key.properties` (already git-ignored):

```properties
storeFile=/absolute/path/to/release.jks
storePassword=...
keyAlias=griccalc
keyPassword=...
```

For CI, add these repository secrets instead - the workflow picks them up
automatically and the build signs itself:

| Secret | Value |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | `base64 -w0 release.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | keystore password |
| `ANDROID_KEY_ALIAS` | key alias, e.g. `griccalc` |
| `ANDROID_KEY_PASSWORD` | key password |

Keep the keystore and its passwords backed up somewhere safe. Losing them means
you can never ship an update that installs over an existing copy.

## Layout

```
lib/
  logic/gir_calculator.dart   calculations and banding, no Flutter UI
  logic/formatting.dart       number formatting and lenient parsing
  logic/patient_store.dart    the patient list, and auto-saving it
  logic/report.dart           the copy text and the printable PDF
  logic/settings_store.dart   the appearance choice
  models/fluid_input.dart     a fluid line, rate units, presets
  models/patient.dart         one baby's record
  screens/                    calculator, formula sheet, disclaimer
  widgets/                    patient strip and card, fluid card,
                              quick-add row, results panel, totals bar
  theme.dart                  colour scheme and status colours
```

Patient records live in `shared_preferences` as JSON, on the device only -
nothing is sent anywhere. A record that cannot be read back is dropped rather
than taking the rest of the list with it.

## Disclaimer

For use by clinicians as a calculation aid only. Check every figure against your
unit's protocol and an independent calculation before acting on it.
