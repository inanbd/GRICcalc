// Calculation tests for the browser engine, mirroring the Flutter app's
// calculation_validation_test.dart. Run with: node --test web/tests
import test from 'node:test';
import assert from 'node:assert/strict';

const {
  FluidRoute,
  RateUnit,
  GirBand,
  convertRate,
  feedIntervalLabel,
  girBandFor,
  girFor,
  summarise,
  toMlPerHour,
  toMlPerKgPerDay,
} = await import('../GirCalculator.Web/wwwroot/js/gir.js');

/**
 * The same calculation built up from units rather than from the app's
 * simplified form, so agreement between the two is a real check:
 *   g/mL = percent/100; mg/hr = mL/hr x g/mL x 1000; mg/min = mg/hr / 60.
 */
const referenceGirFromRate = (percent, mlPerHour, kg) =>
  (percent * mlPerHour * 1000) / (kg * 60 * 100);

/** A second, separately derived route: GIR = mL/kg/day x % / 144. */
const referenceGirFromDailyVolume = (percent, mlPerKgPerDay) =>
  (mlPerKgPerDay * percent) / 144;

const iv = (percent, mlPerHour, id = 'iv') => ({
  id,
  name: 'IV',
  dextrosePercent: percent,
  rateUnit: RateUnit.mlPerHour,
  rateValue: mlPerHour,
  route: FluidRoute.intravenous,
  feedIntervalHours: 3,
  countsTowardGir: true,
});

const feed = (percent, volumeMl, everyHours, { id = 'feed', counts = false } = {}) => ({
  id,
  name: 'Feed',
  dextrosePercent: percent,
  rateUnit: RateUnit.mlPerFeed,
  rateValue: volumeMl,
  route: FluidRoute.enteral,
  feedIntervalHours: everyHours,
  countsTowardGir: counts,
});

const close = (actual, expected, epsilon = 1e-9, message = '') =>
  assert.ok(
    Math.abs(actual - expected) <= epsilon,
    `${message} expected ${expected}, got ${actual}`,
  );

const weightsGrams = [400, 600, 850, 1000, 1250, 1500, 2000, 2500, 3200, 4100, 5000];
const concentrations = [2.5, 5, 7.5, 10, 12.5, 15, 20, 25, 50];
const hourlyRates = [0.1, 0.5, 1, 2.4, 4, 7.5, 12, 20];

test('agrees with the unit-derived formula across the grid', () => {
  for (const grams of weightsGrams) {
    const kg = grams / 1000;
    for (const percent of concentrations) {
      for (const rate of hourlyRates) {
        close(
          girFor({ mlPerHour: rate, dextrosePercent: percent, weightKg: kg }),
          referenceGirFromRate(percent, rate, kg),
          1e-9,
          `${percent}% at ${rate} mL/hr in ${grams} g:`,
        );
      }
    }
  }
});

test('agrees with the daily-volume derivation too', () => {
  for (const grams of weightsGrams) {
    for (const percent of concentrations) {
      for (const perKgPerDay of [40, 60, 80, 100, 120, 150, 180]) {
        const summary = summarise({
          weightGrams: grams,
          fluids: [
            {
              ...iv(percent, 0),
              rateUnit: RateUnit.mlPerKgPerDay,
              rateValue: perKgPerDay,
            },
          ],
        });
        close(
          summary.totalGir,
          referenceGirFromDailyVolume(percent, perKgPerDay),
          1e-9,
          `${percent}% at ${perKgPerDay} mL/kg/day in ${grams} g:`,
        );
      }
    }
  }
});

test('D10W at 100 mL/kg/day is 6.94 mg/kg/min at any weight', () => {
  for (const grams of weightsGrams) {
    const summary = summarise({
      weightGrams: grams,
      fluids: [
        { ...iv(10, 0), rateUnit: RateUnit.mlPerKgPerDay, rateValue: 100 },
      ],
    });
    close(summary.totalGir, 6.944444444, 1e-6, `${grams} g:`);
  }
});

test('matches the worked figures published by infantfeeds.com', () => {
  // 2000 g, D5W at 1 mL/hr, plus a continuous feed at 1 mL/hr of a 7.2%
  // formula with a 1% carbohydrate modular. Reported there as 0.42/0.68/1.1.
  const summary = summarise({
    weightGrams: 2000,
    fluids: [
      iv(5, 1),
      {
        id: 'feed',
        name: 'Similac Pro-Total Comfort RTF 20 kcal + 1% D',
        dextrosePercent: 8.2,
        rateUnit: RateUnit.mlPerHour,
        rateValue: 1,
        route: FluidRoute.enteral,
        feedIntervalHours: 3,
        countsTowardGir: true,
      },
    ],
  });
  assert.equal(summary.ivGir.toFixed(2), '0.42');
  assert.equal(summary.enteralGir.toFixed(2), '0.68');
  assert.equal(summary.totalGir.toFixed(1), '1.1');
});

test('a 1 kg baby on D10W at 6 mL/hr sits at 10 mg/kg/min', () => {
  close(girFor({ mlPerHour: 6, dextrosePercent: 10, weightKg: 1 }), 10, 1e-12);
});

test('20 mL every 3 hours is 8 feeds, 160 mL, 6.67 mL/hr', () => {
  close(toMlPerHour(20, RateUnit.mlPerFeed, 1.5, 3), 20 / 3, 1e-9);
  close(toMlPerKgPerDay(20, RateUnit.mlPerFeed, 1.5, 3), 160 / 1.5, 1e-9);
  const summary = summarise({ weightGrams: 1500, fluids: [feed(7, 20, 3)] });
  close(summary.fluids[0].feedsPerDay, 8, 1e-12);
});

test("feeds add to the day's fluid but not to the GIR by default", () => {
  const summary = summarise({
    weightGrams: 1500,
    fluids: [iv(10, 4, 'a'), feed(7, 20, 3)],
  });
  close(summary.ivGir, 40 / 9, 1e-9);
  close(summary.totalGir, 40 / 9, 1e-9);
  close(summary.enteralGir, (20 / 3) * 7 / 9, 1e-9);
  assert.equal(summary.countedEnteralGir, 0);
  assert.equal(summary.countsFeedsInGir, false);
  close(summary.totalMlPerKgPerDay, (4 + 20 / 3) * 24 / 1.5, 1e-9);
  close(summary.ivMlPerKgPerDay, 64, 1e-9);
  close(summary.enteralMlPerKgPerDay, 160 / 1.5, 1e-9);
});

test('switching a feed on adds it to the total GIR', () => {
  const summary = summarise({
    weightGrams: 1500,
    fluids: [iv(10, 4, 'a'), feed(7, 20, 3, { counts: true })],
  });
  close(summary.totalGir, 40 / 9 + (20 / 3) * 7 / 9, 1e-9);
  assert.equal(summary.countsFeedsInGir, true);
  // Counting it does not change the fluid totals.
  close(summary.totalMlPerKgPerDay, (4 + 20 / 3) * 24 / 1.5, 1e-9);
});

test('an uncounted feed takes no slice of the contribution bar', () => {
  const summary = summarise({
    weightGrams: 1500,
    fluids: [iv(10, 4, 'a'), feed(7, 20, 3)],
  });
  close(summary.fluids[0].girShare, 1, 1e-9);
  assert.equal(summary.fluids[1].girShare, 0);
});

test('totals never drift from the sum of their parts', () => {
  const summary = summarise({
    weightGrams: 1750,
    fluids: [
      iv(10, 3.2, 'a'),
      iv(12.5, 1.1, 'b'),
      iv(0, 2, 'c'),
      feed(7, 18, 3, { id: 'd', counts: true }),
      feed(8.3, 12, 4, { id: 'e' }),
    ],
  });
  const summedGir = summary.fluids
    .filter((r) => r.countsTowardGir)
    .reduce((acc, r) => acc + r.gir, 0);
  close(summary.totalGir, summedGir, 1e-12);
  close(summary.totalGir, summary.ivGir + summary.countedEnteralGir, 1e-12);

  const summedVolume = summary.fluids.reduce((acc, r) => acc + r.mlPerHour, 0);
  close(summary.totalMlPerHour, summedVolume, 1e-12);
  close(
    summary.totalMlPerKgPerDay,
    summary.ivMlPerKgPerDay + summary.enteralMlPerKgPerDay,
    1e-9,
  );
});

test('a rate converted away and back returns to itself', () => {
  for (const grams of weightsGrams) {
    const kg = grams / 1000;
    for (const rate of hourlyRates) {
      const line = iv(10, rate);
      const asDaily = convertRate(line, RateUnit.mlPerKgPerDay, kg);
      const daily = { ...line, rateUnit: RateUnit.mlPerKgPerDay, rateValue: asDaily };
      close(convertRate(daily, RateUnit.mlPerHour, kg), rate, 1e-9);
    }
  }
});

test('a feed converted to mL/hr keeps the same GIR and volume', () => {
  for (const interval of [1, 2, 3, 4, 6, 8, 12, 24]) {
    const kg = 1.6;
    const perFeed = feed(7, 24, interval, { counts: true });
    const hourly = convertRate(perFeed, RateUnit.mlPerHour, kg);
    const a = summarise({ weightGrams: kg * 1000, fluids: [perFeed] });
    const b = summarise({
      weightGrams: kg * 1000,
      fluids: [{ ...perFeed, rateUnit: RateUnit.mlPerHour, rateValue: hourly }],
    });
    close(b.totalGir, a.totalGir, 1e-9, `q${interval}h:`);
    close(b.totalMlPerKgPerDay, a.totalMlPerKgPerDay, 1e-9, `q${interval}h:`);
  }
});

test('feed volumes match volume x 24 / interval', () => {
  const kg = 1.4;
  for (const interval of [1, 2, 3, 4, 6, 8, 12, 24]) {
    for (const volume of [1, 5, 12.5, 20, 45, 80]) {
      const summary = summarise({
        weightGrams: kg * 1000,
        fluids: [feed(7, volume, interval)],
      });
      const expectedPerDay = volume * (24 / interval);
      close(summary.totalMlPerHour * 24, expectedPerDay, 1e-9);
      close(summary.enteralMlPerKgPerDay, expectedPerDay / kg, 1e-9);
    }
  }
});

test('a nonsense concentration contributes no glucose but real volume', () => {
  const summary = summarise({ weightGrams: 1200, fluids: [iv(-10, 5)] });
  assert.equal(summary.totalGir, 0);
  assert.equal(summary.totalGlucoseGramsPerDay, 0);
  assert.equal(summary.totalMlPerHour, 5);
});

test('a negative rate delivers nothing at all', () => {
  const summary = summarise({
    weightGrams: 1200,
    fluids: [iv(10, -5, 'b'), feed(-7, -20, 3, { id: 'c', counts: true })],
  });
  assert.equal(summary.totalGir, 0);
  assert.equal(summary.totalMlPerHour, 0);
  for (const line of summary.fluids) {
    assert.ok(line.gir >= 0);
    assert.ok(line.mlPerHour >= 0);
  }
});

test('survives non-finite inputs without producing NaN', () => {
  const summary = summarise({
    weightGrams: 1000,
    fluids: [
      iv(NaN, 4, 'a'),
      iv(10, Infinity, 'b'),
      feed(7, NaN, 3, { id: 'c', counts: true }),
      feed(7, 20, 0, { id: 'd', counts: true }),
    ],
  });
  assert.ok(Number.isFinite(summary.totalGir));
  assert.ok(Number.isFinite(summary.totalMlPerKgPerDay));
  for (const line of summary.fluids) {
    assert.ok(Number.isFinite(line.gir));
    assert.ok(Number.isFinite(line.girShare));
  }
});

test('a missing or impossible weight reports nothing at all', () => {
  for (const grams of [null, undefined, 0, -1, -2500, NaN, Infinity]) {
    const summary = summarise({
      weightGrams: grams,
      fluids: [iv(10, 4), feed(7, 20, 3)],
    });
    assert.equal(summary.isValid, false, `weight ${grams}`);
    assert.equal(summary.totalGir, 0, `weight ${grams}`);
    assert.equal(summary.fluids.length, 0, `weight ${grams}`);
  }
});

test('bands classify exactly at the boundaries', () => {
  assert.equal(girBandFor(3.9999), GirBand.low);
  assert.equal(girBandFor(4), GirBand.maintenance);
  assert.equal(girBandFor(7.9999), GirBand.maintenance);
  assert.equal(girBandFor(8), GirBand.elevated);
  assert.equal(girBandFor(11.9999), GirBand.elevated);
  assert.equal(girBandFor(12), GirBand.high);
  assert.equal(girBandFor(0), GirBand.none);
  assert.equal(girBandFor(-5), GirBand.none);
  assert.equal(girBandFor(NaN), GirBand.none);
});

test('mean dextrose describes the IV fluids, not the feeds', () => {
  const summary = summarise({
    weightGrams: 1500,
    fluids: [iv(10, 4, 'a'), feed(7, 20, 3)],
  });
  close(summary.meanDextrosePercent, 10, 1e-9);
});

test('the peripheral flag ignores feeds', () => {
  // The limit is about what a cannula tolerates; milk does not go through one.
  const feedOnly = summarise({ weightGrams: 1000, fluids: [feed(20, 20, 3)] });
  assert.equal(feedOnly.linesAbovePeripheralLimit.length, 0);

  const mixed = summarise({
    weightGrams: 1000,
    fluids: [iv(12.5, 2, 'at-limit'), iv(12.6, 2, 'over'), iv(25, 0, 'idle')],
  });
  assert.deepEqual(
    mixed.linesAbovePeripheralLimit.map((r) => r.fluid.id),
    ['over'],
  );
});

test('feed interval labels read the way they are prescribed', () => {
  assert.equal(feedIntervalLabel(3), 'q3h');
  assert.equal(feedIntervalLabel(1.5), 'q1.5h');
  assert.equal(feedIntervalLabel(0), 'q?h');
});
