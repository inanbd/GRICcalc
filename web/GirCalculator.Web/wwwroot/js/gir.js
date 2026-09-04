// Glucose infusion rate calculations.
//
// A direct port of the Flutter app's lib/logic/gir_calculator.dart, kept
// deliberately faithful so the two agree figure for figure. Everything here is
// pure: it runs in the browser and never talks to the server.

export const RateUnit = Object.freeze({
  mlPerHour: 'mlPerHour',
  mlPerKgPerDay: 'mlPerKgPerDay',
  mlPerFeed: 'mlPerFeed',
});

export const RateUnitLabel = Object.freeze({
  mlPerHour: 'mL/hr',
  mlPerKgPerDay: 'mL/kg/day',
  mlPerFeed: 'mL/feed',
});

export const FluidRoute = Object.freeze({
  intravenous: 'intravenous',
  enteral: 'enteral',
});

/** Concentrations above this generally need central rather than peripheral access. */
export const peripheralDextroseLimit = 12.5;

/** Feed intervals that get written on a chart, in hours. */
export const feedIntervals = Object.freeze([1, 2, 3, 4, 6, 8, 12, 24]);

/** Formats an interval the way it is prescribed: 3 -> "q3h". */
export function feedIntervalLabel(hours) {
  if (!(hours > 0)) return 'q?h';
  const value = Number.isInteger(hours) ? String(hours) : String(hours);
  return `q${value}h`;
}

export const GirBand = Object.freeze({
  none: {
    key: 'none',
    label: 'No glucose',
    description: 'No dextrose-containing fluid is running.',
  },
  low: {
    key: 'low',
    label: 'Below maintenance',
    description:
      'Lower than the usual neonatal maintenance range of 4-8 mg/kg/min.',
  },
  maintenance: {
    key: 'maintenance',
    label: 'Maintenance range',
    description:
      'Within the usual neonatal maintenance range of 4-8 mg/kg/min.',
  },
  elevated: {
    key: 'elevated',
    label: 'Elevated',
    description:
      'Above maintenance. Commonly used when treating hypoglycaemia.',
  },
  high: {
    key: 'high',
    label: 'High',
    description:
      'At or above 12 mg/kg/min. Persistent need at this level warrants a ' +
      'work-up for hyperinsulinism and review of access and concentration.',
  },
});

/** Classifies a glucose infusion rate against usual neonatal practice. */
export function girBandFor(gir) {
  if (!Number.isFinite(gir) || gir <= 0) return GirBand.none;
  if (gir < 4) return GirBand.low;
  if (gir < 8) return GirBand.maintenance;
  if (gir < 12) return GirBand.elevated;
  return GirBand.high;
}

/**
 * Keeps a stray NaN, infinity or negative out of the totals.
 *
 * The keyboard cannot produce a negative, but stored JSON could, and a
 * negative rate would quietly subtract from a total that a clinician reads as
 * what the baby is receiving. Nothing here can be less than zero.
 */
function sanitise(value) {
  return Number.isFinite(value) && value > 0 ? value : 0;
}

/**
 * Converts a rate into mL/hr for a baby of weightKg.
 *
 * A bolus feed is averaged over the day: 20 mL every 3 hours is 8 feeds,
 * 160 mL, and so 6.67 mL/hr.
 */
export function toMlPerHour(value, unit, weightKg, intervalHours = 3) {
  switch (unit) {
    case RateUnit.mlPerHour:
      return value;
    case RateUnit.mlPerKgPerDay:
      return (value * weightKg) / 24;
    case RateUnit.mlPerFeed:
      return intervalHours > 0 ? value / intervalHours : 0;
    default:
      return 0;
  }
}

/** Converts a rate into mL/kg/day for a baby of weightKg. */
export function toMlPerKgPerDay(value, unit, weightKg, intervalHours = 3) {
  if (weightKg <= 0) return 0;
  switch (unit) {
    case RateUnit.mlPerHour:
      return (value * 24) / weightKg;
    case RateUnit.mlPerKgPerDay:
      return value;
    case RateUnit.mlPerFeed:
      return intervalHours > 0 ? (value * (24 / intervalHours)) / weightKg : 0;
    default:
      return 0;
  }
}

/**
 * Restates a line's rate in another unit, so switching units leaves it running
 * at the same speed.
 */
export function convertRate(fluid, unit, weightKg) {
  if (unit === fluid.rateUnit) return fluid.rateValue;
  const mlPerHour = toMlPerHour(
    fluid.rateValue,
    fluid.rateUnit,
    weightKg,
    fluid.feedIntervalHours,
  );
  switch (unit) {
    case RateUnit.mlPerHour:
      return mlPerHour;
    case RateUnit.mlPerKgPerDay:
      return weightKg > 0 ? (mlPerHour * 24) / weightKg : 0;
    case RateUnit.mlPerFeed:
      return mlPerHour * fluid.feedIntervalHours;
    default:
      return 0;
  }
}

/**
 * Glucose infusion rate in mg/kg/min for one line.
 *
 * A `%` solution carries that many grams per 100 mL, so:
 *
 *   mg/kg/min = mL/hr x (% / 100 g/mL) x 1000 mg/g / 60 min/hr / kg
 *             = mL/hr x % / (6 x kg)
 */
export function girFor({ mlPerHour, dextrosePercent, weightKg }) {
  if (weightKg <= 0 || mlPerHour <= 0 || dextrosePercent <= 0) return 0;
  return (mlPerHour * dextrosePercent) / (6 * weightKg);
}

/** Feeds in 24 hours, or null when the line is not fed in boluses. */
export function feedsPerDay(fluid) {
  if (fluid.rateUnit !== RateUnit.mlPerFeed) return null;
  if (!(fluid.feedIntervalHours > 0)) return null;
  return 24 / fluid.feedIntervalHours;
}

export function isFeed(fluid) {
  return fluid.route === FluidRoute.enteral;
}

/** An empty summary, for a weight that has not been entered yet. */
export function emptySummary() {
  return {
    weightKg: 0,
    isValid: false,
    fluids: [],
    totalGir: 0,
    ivGir: 0,
    enteralGir: 0,
    countedEnteralGir: 0,
    totalMlPerHour: 0,
    totalMlPerKgPerDay: 0,
    ivMlPerKgPerDay: 0,
    enteralMlPerKgPerDay: 0,
    totalGlucoseGramsPerDay: 0,
    meanDextrosePercent: null,
    hasFeeds: false,
    countsFeedsInGir: false,
    linesAbovePeripheralLimit: [],
    band: GirBand.none,
  };
}

/**
 * Runs the full calculation for a weight in grams and every line given.
 *
 * Returns an empty summary when the weight is missing or non-positive:
 * without a weight none of the per-kilogram figures mean anything.
 */
export function summarise({ weightGrams, fluids }) {
  if (
    weightGrams === null ||
    weightGrams === undefined ||
    !Number.isFinite(weightGrams) ||
    weightGrams <= 0
  ) {
    return emptySummary();
  }

  const weightKg = weightGrams / 1000;

  let ivGir = 0;
  let enteralGir = 0;
  let countedEnteralGir = 0;
  let totalMlPerHour = 0;
  let ivMlPerHour = 0;
  let enteralMlPerHour = 0;
  let totalGlucoseGramsPerDay = 0;
  let ivVolumePerDay = 0;
  let ivGlucoseGramsPerDay = 0;

  const partials = [];
  for (const fluid of fluids) {
    const mlPerHour = sanitise(
      toMlPerHour(
        fluid.rateValue,
        fluid.rateUnit,
        weightKg,
        fluid.feedIntervalHours,
      ),
    );
    const mlPerKgPerDay = sanitise(
      toMlPerKgPerDay(
        fluid.rateValue,
        fluid.rateUnit,
        weightKg,
        fluid.feedIntervalHours,
      ),
    );
    const gir = sanitise(
      girFor({
        mlPerHour,
        dextrosePercent: fluid.dextrosePercent,
        weightKg,
      }),
    );
    const glucoseGramsPerDay = sanitise(
      (mlPerHour * 24 * fluid.dextrosePercent) / 100,
    );

    // Every route adds to the day's fluid; only opted-in carbohydrate adds to
    // the GIR, which is the whole point of separating the two.
    totalMlPerHour += mlPerHour;
    totalGlucoseGramsPerDay += glucoseGramsPerDay;
    if (isFeed(fluid)) {
      enteralGir += gir;
      enteralMlPerHour += mlPerHour;
      if (fluid.countsTowardGir) countedEnteralGir += gir;
    } else {
      ivGir += gir;
      ivMlPerHour += mlPerHour;
      ivVolumePerDay += mlPerHour * 24;
      ivGlucoseGramsPerDay += glucoseGramsPerDay;
    }

    partials.push({ fluid, mlPerHour, mlPerKgPerDay, gir, glucoseGramsPerDay });
  }

  const totalGir = ivGir + countedEnteralGir;

  const results = partials.map((p) => {
    const counted = !isFeed(p.fluid) || Boolean(p.fluid.countsTowardGir);
    return {
      fluid: p.fluid,
      mlPerHour: p.mlPerHour,
      mlPerKgPerDay: p.mlPerKgPerDay,
      gir: p.gir,
      glucoseGramsPerDay: p.glucoseGramsPerDay,
      // Measured against what is actually counted, so an uncounted feed shows
      // no slice rather than a misleading one.
      girShare: totalGir > 0 && counted ? p.gir / totalGir : 0,
      countsTowardGir: counted,
      feedsPerDay: feedsPerDay(p.fluid),
      isFeed: isFeed(p.fluid),
    };
  });

  const totalMlPerDay = totalMlPerHour * 24;

  return {
    weightKg,
    isValid: true,
    fluids: results,
    totalGir,
    ivGir,
    enteralGir,
    countedEnteralGir,
    totalMlPerHour,
    totalMlPerKgPerDay: sanitise(totalMlPerDay / weightKg),
    ivMlPerKgPerDay: sanitise((ivMlPerHour * 24) / weightKg),
    enteralMlPerKgPerDay: sanitise((enteralMlPerHour * 24) / weightKg),
    totalGlucoseGramsPerDay,
    // Feeds are left out: the figure exists to be checked against what a
    // peripheral line will take.
    meanDextrosePercent:
      ivVolumePerDay > 0
        ? sanitise((ivGlucoseGramsPerDay / ivVolumePerDay) * 100)
        : null,
    hasFeeds: results.some((r) => r.isFeed),
    countsFeedsInGir: results.some(
      (r) => r.isFeed && r.countsTowardGir && r.gir > 0,
    ),
    // Feeds excluded: the limit is about what a cannula tolerates, and milk
    // does not go through one.
    linesAbovePeripheralLimit: results.filter(
      (r) =>
        !r.isFeed &&
        r.fluid.dextrosePercent > peripheralDextroseLimit &&
        r.mlPerHour > 0,
    ),
    band: girBandFor(totalGir),
  };
}
