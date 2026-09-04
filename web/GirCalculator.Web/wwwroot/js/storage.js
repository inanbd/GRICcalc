// Patient records, kept in this browser and nowhere else.
//
// localStorage rather than cookies on purpose: a cookie is attached to every
// request, which would send patient data to the server on each page load. This
// stays on the device.
import { FluidRoute, RateUnit } from './gir.js';

const KEY = 'griccalc.patients.v1';
const SELECTED_KEY = 'griccalc.selected.v1';

let nextId = 0;

const newId = (prefix) => `${prefix}-${nextId++}`;

export function newFluid({
  name = '',
  dextrosePercent = 10,
  route = FluidRoute.intravenous,
} = {}) {
  const feed = route === FluidRoute.enteral;
  return {
    id: newId('fluid'),
    name,
    dextrosePercent,
    // Feeds are ordered as a volume every few hours; drips are ordered by rate.
    rateUnit: feed ? RateUnit.mlPerFeed : RateUnit.mlPerHour,
    rateValue: 0,
    route,
    feedIntervalHours: 3,
    // A feed's carbohydrate is an estimate, so it stays out of the GIR until
    // it is deliberately switched on.
    countsTowardGir: !feed,
  };
}

export function blankPatient() {
  return {
    id: newId('patient'),
    name: '',
    weightGrams: null,
    fluids: [newFluid({ name: 'D10W', dextrosePercent: 10 })],
  };
}

function readFluid(raw) {
  if (!raw || typeof raw !== 'object') return null;
  if (typeof raw.id !== 'string' || raw.id === '') return null;
  const route =
    raw.route === FluidRoute.enteral
      ? FluidRoute.enteral
      : FluidRoute.intravenous;
  const unit = Object.values(RateUnit).includes(raw.rateUnit)
    ? raw.rateUnit
    : RateUnit.mlPerHour;
  return {
    id: raw.id,
    name: typeof raw.name === 'string' ? raw.name : '',
    dextrosePercent: toNumber(raw.dextrosePercent) ?? 0,
    rateUnit: unit,
    rateValue: toNumber(raw.rateValue) ?? 0,
    route,
    feedIntervalHours: toNumber(raw.feedIntervalHours) ?? 3,
    countsTowardGir:
      typeof raw.countsTowardGir === 'boolean'
        ? raw.countsTowardGir
        : route === FluidRoute.intravenous,
  };
}

function readPatient(raw) {
  if (!raw || typeof raw !== 'object') return null;
  if (typeof raw.id !== 'string' || raw.id === '') return null;
  const weight = toNumber(raw.weightGrams);
  return {
    id: raw.id,
    name: typeof raw.name === 'string' ? raw.name : '',
    weightGrams: weight !== null && weight > 0 ? weight : null,
    fluids: Array.isArray(raw.fluids)
      ? raw.fluids.map(readFluid).filter(Boolean)
      : [],
  };
}

function toNumber(value) {
  const parsed = typeof value === 'string' ? Number(value) : value;
  return typeof parsed === 'number' && Number.isFinite(parsed) ? parsed : null;
}

/** Restarts id generation past anything stored, so ids cannot collide. */
function seedIdCounter(patients) {
  const consider = (id) => {
    const dash = String(id).lastIndexOf('-');
    if (dash === -1) return;
    const suffix = Number(String(id).slice(dash + 1));
    if (Number.isInteger(suffix) && suffix >= nextId) nextId = suffix + 1;
  };
  for (const patient of patients) {
    consider(patient.id);
    for (const fluid of patient.fluids) consider(fluid.id);
  }
}

export function load() {
  let patients = [];
  let selectedId = null;
  try {
    const raw = window.localStorage.getItem(KEY);
    if (raw) {
      const decoded = JSON.parse(raw);
      if (Array.isArray(decoded)) {
        // A record that cannot be read is dropped rather than taking the rest
        // of the list with it.
        patients = decoded.map(readPatient).filter(Boolean);
      }
    }
    selectedId = window.localStorage.getItem(SELECTED_KEY);
  } catch (e) {
    patients = [];
  }

  seedIdCounter(patients);
  if (patients.length === 0) patients = [blankPatient()];
  if (!patients.some((p) => p.id === selectedId)) selectedId = patients[0].id;
  return { patients, selectedId };
}

export function save(patients, selectedId) {
  try {
    window.localStorage.setItem(KEY, JSON.stringify(patients));
    if (selectedId) window.localStorage.setItem(SELECTED_KEY, selectedId);
  } catch (e) {
    // Storage unavailable or full. The page keeps working for this session.
  }
}
