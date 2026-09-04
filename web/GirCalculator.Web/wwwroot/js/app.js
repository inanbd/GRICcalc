// The calculator page. Everything here runs in the browser: nothing typed on
// this page is ever sent to the server.
import {
  FluidRoute,
  RateUnit,
  RateUnitLabel,
  convertRate,
  feedIntervalLabel,
  feedIntervals,
  summarise,
} from './gir.js';
import { fixed, parseNumber, trimmed } from './format.js';
import { feedPresets, infusionPresets, lineColor } from './presets.js';
import { blankPatient, load, newFluid, save } from './storage.js';

const el = (id) => document.getElementById(id);

let patients = [];
let selectedId = null;
/** The line whose rate or volume field should take the cursor once rendered. */
let focusFluidId = null;

const selected = () =>
  patients.find((p) => p.id === selectedId) ?? patients[0];

const positionOf = (patient) =>
  patients.findIndex((p) => p.id === patient.id) + 1;

const displayName = (patient, position) =>
  patient.name.trim() === '' ? `Patient ${position}` : patient.name.trim();

function commit() {
  save(patients, selectedId);
  render();
}

/** Escapes text destined for innerHTML. Patient names are user input. */
function esc(text) {
  return String(text)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

/* ---------------------------------------------------------------- patients */

function renderPatientStrip() {
  const strip = el('patient-strip');
  strip.innerHTML = '';

  patients.forEach((patient, index) => {
    const chip = document.createElement('button');
    chip.type = 'button';
    chip.className = 'patient-chip';
    chip.setAttribute('aria-pressed', String(patient.id === selectedId));
    chip.innerHTML =
      `<span class="num">${index + 1}</span>` +
      `<span class="who"><span>${esc(displayName(patient, index + 1))}</span>` +
      `<small>${
        patient.weightGrams ? `${trimmed(patient.weightGrams, 0)} g` : 'no weight'
      }</small></span>`;
    chip.addEventListener('click', () => {
      selectedId = patient.id;
      commit();
    });
    strip.appendChild(chip);
  });

  const add = document.createElement('button');
  add.type = 'button';
  add.className = 'chip';
  add.innerHTML = '<span class="plus">+</span>Add patient';
  add.addEventListener('click', () => {
    const patient = blankPatient();
    patients.push(patient);
    selectedId = patient.id;
    commit();
  });
  strip.appendChild(add);
}

/* ------------------------------------------------------------------ fluids */

function fluidCard(fluid, index, result) {
  const card = document.createElement('div');
  card.className = 'fluid-card';
  const isFeed = fluid.route === FluidRoute.enteral;
  const perFeed = fluid.rateUnit === RateUnit.mlPerFeed;

  const head = document.createElement('div');
  head.className = 'fluid-head';
  const dot = document.createElement('span');
  dot.className = 'dot';
  // Set through the CSSOM: the page's CSP forbids inline style attributes.
  dot.style.background = lineColor(index);
  head.appendChild(dot);

  const name = document.createElement('input');
  name.type = 'text';
  name.value = fluid.name;
  name.placeholder = isFeed ? 'Feed' : 'Fluid';
  name.setAttribute('aria-label', 'Name');
  name.addEventListener('input', () => {
    fluid.name = name.value;
    save(patients, selectedId);
    renderPatientStrip();
  });
  head.appendChild(name);

  const remove = document.createElement('button');
  remove.type = 'button';
  remove.className = 'icon-btn';
  remove.title = 'Remove this line';
  remove.setAttribute('aria-label', `Remove ${fluid.name || 'line'}`);
  remove.textContent = '×';
  remove.addEventListener('click', () => {
    const patient = selected();
    patient.fluids = patient.fluids.filter((f) => f.id !== fluid.id);
    commit();
  });
  head.appendChild(remove);
  card.appendChild(head);

  const fields = document.createElement('div');
  fields.className = 'fluid-fields';

  fields.appendChild(
    numberField({
      label: isFeed ? 'Carb' : 'Dextrose',
      suffix: '%',
      value: fluid.dextrosePercent,
      onInput: (value) => {
        fluid.dextrosePercent = value ?? 0;
        save(patients, selectedId);
        renderResults();
        renderFluidReadouts();
      },
    }),
  );

  const rateField = numberField({
    label: perFeed ? 'Volume' : 'Rate',
    suffix: perFeed ? 'mL' : RateUnitLabel[fluid.rateUnit],
    value: fluid.rateValue,
    onInput: (value) => {
      fluid.rateValue = value ?? 0;
      save(patients, selectedId);
      renderResults();
      renderFluidReadouts();
    },
  });
  fields.appendChild(rateField);

  if (perFeed) {
    const wrap = document.createElement('div');
    wrap.innerHTML = '<label for="every-' + fluid.id + '">Every</label>';
    const select = document.createElement('select');
    select.id = 'every-' + fluid.id;
    const options = [...new Set([...feedIntervals, fluid.feedIntervalHours])]
      .filter((h) => h > 0)
      .sort((a, b) => a - b);
    for (const hours of options) {
      const option = document.createElement('option');
      option.value = String(hours);
      option.textContent = feedIntervalLabel(hours);
      option.selected = hours === fluid.feedIntervalHours;
      select.appendChild(option);
    }
    select.addEventListener('change', () => {
      fluid.feedIntervalHours = Number(select.value);
      commit();
    });
    wrap.appendChild(select);
    fields.appendChild(wrap);
  }
  card.appendChild(fields);

  const units = document.createElement('div');
  units.className = 'unit-row';
  const available = isFeed
    ? [RateUnit.mlPerFeed, RateUnit.mlPerHour, RateUnit.mlPerKgPerDay]
    : [RateUnit.mlPerHour, RateUnit.mlPerKgPerDay];
  const shortLabel = {
    [RateUnit.mlPerFeed]: 'Per feed',
    [RateUnit.mlPerHour]: 'mL/hr',
    [RateUnit.mlPerKgPerDay]: 'mL/kg/day',
  };
  for (const unit of available) {
    const button = document.createElement('button');
    button.type = 'button';
    button.className = 'seg';
    button.textContent = shortLabel[unit];
    button.setAttribute('aria-pressed', String(unit === fluid.rateUnit));
    button.addEventListener('click', () => {
      if (unit === fluid.rateUnit) return;
      const weightKg = (selected().weightGrams ?? 0) / 1000;
      // Carry the equivalent rate across, so the line keeps delivering the
      // same amount in the new unit.
      const converted = weightKg > 0 ? convertRate(fluid, unit, weightKg) : fluid.rateValue;
      fluid.rateUnit = unit;
      fluid.rateValue = Math.round(converted * 100) / 100;
      commit();
    });
    units.appendChild(button);
  }
  card.appendChild(units);

  if (isFeed) {
    const row = document.createElement('div');
    row.className = 'switch-row';
    const box = document.createElement('input');
    box.type = 'checkbox';
    box.id = 'gir-' + fluid.id;
    box.checked = Boolean(fluid.countsTowardGir);
    box.addEventListener('change', () => {
      fluid.countsTowardGir = box.checked;
      commit();
    });
    const label = document.createElement('label');
    label.setAttribute('for', box.id);
    label.textContent = 'Count towards GIR';
    row.append(box, label);
    card.appendChild(row);
  }

  const readout = document.createElement('div');
  readout.className = 'readout';
  readout.dataset.readoutFor = fluid.id;
  card.appendChild(readout);
  if (result) paintReadout(readout, result);

  if (fluid.id === focusFluidId) {
    const input = rateField.querySelector('input');
    // After this frame, so the field exists to receive focus. Selecting the
    // placeholder means the first keystroke replaces it.
    window.requestAnimationFrame(() => {
      input.focus();
      input.select();
    });
    focusFluidId = null;
  }

  return card;
}

function numberField({ label, suffix, value, onInput }) {
  const wrap = document.createElement('div');
  const id = 'f' + Math.random().toString(36).slice(2, 9);
  wrap.innerHTML = `<label for="${id}">${esc(label)}${
    suffix ? ` (${esc(suffix)})` : ''
  }</label>`;
  const input = document.createElement('input');
  input.type = 'text';
  input.inputMode = 'decimal';
  input.id = id;
  input.value = trimmed(value, 2);
  input.addEventListener('input', () => onInput(parseNumber(input.value)));
  wrap.appendChild(input);
  return wrap;
}

function paintReadout(node, result) {
  const stats = [];
  stats.push({
    label: result.countsTowardGir ? 'GIR' : 'GIR (not counted)',
    value: `${fixed(result.gir, 2)} mg/kg/min`,
  });
  if (result.feedsPerDay !== null) {
    stats.push({ label: 'Feeds', value: `${trimmed(result.feedsPerDay, 1)}/day` });
  }
  if (result.fluid.rateUnit === RateUnit.mlPerHour) {
    stats.push({
      label: 'Daily',
      value: `${trimmed(result.mlPerKgPerDay, 1)} mL/kg/day`,
    });
  } else {
    stats.push({ label: 'Rate', value: `${trimmed(result.mlPerHour, 2)} mL/hr` });
  }
  if (result.fluid.rateUnit === RateUnit.mlPerFeed) {
    stats.push({
      label: 'Volume',
      value: `${trimmed(result.mlPerHour * 24, 1)} mL/day`,
    });
  }
  stats.push({
    label: 'Glucose',
    value: `${trimmed(result.glucoseGramsPerDay, 2)} g/day`,
  });

  node.className = 'readout' + (result.countsTowardGir ? '' : ' muted');
  node.innerHTML = stats
    .map(
      (s) =>
        `<div class="stat"><span>${esc(s.label)}</span><b>${esc(s.value)}</b></div>`,
    )
    .join('');
}

function renderFluidReadouts() {
  const summary = currentSummary();
  for (const result of summary.fluids) {
    const node = document.querySelector(`[data-readout-for="${result.fluid.id}"]`);
    if (node) paintReadout(node, result);
  }
}

function renderFluids() {
  const patient = selected();
  const list = el('fluid-list');
  const summary = currentSummary();
  const byId = new Map(summary.fluids.map((r) => [r.fluid.id, r]));

  list.innerHTML = '';
  el('line-count').textContent =
    `${patient.fluids.length} ${patient.fluids.length === 1 ? 'line' : 'lines'}`;

  if (patient.fluids.length === 0) {
    const empty = document.createElement('p');
    empty.className = 'note';
    empty.textContent = 'No lines yet - add one below.';
    list.appendChild(empty);
    return;
  }

  patient.fluids.forEach((fluid, index) => {
    list.appendChild(fluidCard(fluid, index, byId.get(fluid.id)));
  });
}

function renderQuickAdd() {
  const build = (node, presets) => {
    node.innerHTML = '';
    for (const preset of presets) {
      const chip = document.createElement('button');
      chip.type = 'button';
      chip.className = 'chip';
      chip.innerHTML = `<span class="plus">+</span>${esc(preset.name)}`;
      chip.addEventListener('click', () => addFluid(preset));
      node.appendChild(chip);
    }
  };
  build(el('add-fluids'), infusionPresets);
  build(el('add-feeds'), feedPresets);

  el('add-custom').onclick = () =>
    addFluid({ name: '', dextrosePercent: 10, route: FluidRoute.intravenous });
}

function addFluid(preset) {
  const patient = selected();
  const fluid = newFluid(preset);
  patient.fluids.push(fluid);
  focusFluidId = fluid.id;
  commit();
}

/* ----------------------------------------------------------------- results */

function currentSummary() {
  const patient = selected();
  return summarise({
    weightGrams: patient.weightGrams,
    fluids: patient.fluids,
  });
}

const bandColor = {
  none: 'var(--neutral)',
  low: 'var(--caution)',
  maintenance: 'var(--good)',
  elevated: 'var(--caution)',
  high: 'var(--alert)',
};

function renderResults() {
  const summary = currentSummary();
  const panel = el('results');

  if (!summary.isValid) {
    panel.innerHTML =
      '<div class="card"><p class="empty">Enter the baby\'s weight to see totals.</p></div>';
    return;
  }

  const colour = bandColor[summary.band.key];
  const rows = [];

  rows.push(`
    <div class="card">
      <div class="eyebrow">Total GIR</div>
      <div><span class="gir-value" data-tint="text">${fixed(summary.totalGir, 2)}</span><span class="gir-unit">mg/kg/min</span></div>
      <span class="band-pill" data-tint="pill">${esc(summary.band.label)}</span>
      <p class="note mt-xs">${esc(summary.band.description)}</p>
      ${
        summary.hasFeeds
          ? `<hr class="divider">
             <div class="split-row"><span aria-hidden="true">+</span><span class="label">From IV fluids</span><b>${fixed(summary.ivGir, 2)}</b><span class="note">mg/kg/min</span></div>
             <div class="split-row${summary.countsFeedsInGir ? '' : ' excluded'}"><span aria-hidden="true">${summary.countsFeedsInGir ? '+' : '-'}</span><span class="label">From feeds</span><b>${fixed(summary.enteralGir, 2)}</b><span class="note">mg/kg/min</span></div>
             <p class="note mt-sm">${
               summary.countsFeedsInGir
                 ? 'Feeds are included above. Enteral glucose is an estimate: check the carbohydrate against the product.'
                 : 'Feeds are shown but not added in, the usual convention. Switch a feed on to include it.'
             }</p>`
          : ''
      }
    </div>`);

  const contributing = summary.fluids.filter((r) => r.gir > 0);
  if (summary.totalGir > 0 && summary.fluids.length > 1 && contributing.length > 0) {
    const segments = summary.fluids
      .map((r, i) => ({ r, i }))
      .filter(({ r }) => r.girShare > 0)
      .map(
        ({ r, i }) =>
          `<span data-bar-color="${lineColor(i)}" data-bar-width="${(r.girShare * 100).toFixed(3)}"></span>`,
      )
      .join('');
    const legend = summary.fluids
      .map((r, i) => ({ r, i }))
      .filter(({ r }) => r.gir > 0)
      .map(
        ({ r, i }) =>
          `<div class="legend-item"><span class="dot" data-bar-color="${lineColor(i)}"></span>
           <span class="name">${esc(r.fluid.name.trim() || `Line ${i + 1}`)}</span>
           <span class="val">${fixed(r.gir, 2)} (${Math.round(r.girShare * 100)}%)</span></div>`,
      )
      .join('');
    rows.push(`
      <div class="card">
        <h2 class="card-title">GIR by line</h2>
        <div class="bar">${segments}</div>
        <div class="legend">${legend}</div>
      </div>`);
  }

  const cell = (label, value, unit, sub = false) =>
    `<tr class="${sub ? 'sub' : ''}"><td class="label">${esc(label)}</td><td class="value">${esc(value)}</td><td class="unit">${esc(unit)}</td></tr>`;

  rows.push(`
    <div class="card">
      <h2 class="card-title">Fluids</h2>
      <table class="totals">
        ${cell('Total rate', trimmed(summary.totalMlPerHour, 2), 'mL/hr')}
        ${cell('Total fluid', trimmed(summary.totalMlPerKgPerDay, 1), 'mL/kg/day')}
        ${
          summary.hasFeeds
            ? cell('of which IV', trimmed(summary.ivMlPerKgPerDay, 1), 'mL/kg/day', true) +
              cell('of which feeds', trimmed(summary.enteralMlPerKgPerDay, 1), 'mL/kg/day', true)
            : ''
        }
        ${cell('Total volume', trimmed(summary.totalMlPerHour * 24, 1), 'mL/day')}
        ${cell('Carbohydrate', trimmed(summary.totalGlucoseGramsPerDay, 2), 'g/day')}
        ${cell(
          summary.hasFeeds ? 'Mean IV dextrose' : 'Mean dextrose',
          summary.meanDextrosePercent === null ? '--' : trimmed(summary.meanDextrosePercent, 1),
          '%',
        )}
        <tr class="rule">${''}</tr>
        ${cell('Dosing weight', trimmed(summary.weightKg, 3), 'kg')}
      </table>
      <div class="button-row">
        <button type="button" class="btn" id="copy-gir">Copy GIR values</button>
        <button type="button" class="btn btn-primary" id="print-report">Print</button>
      </div>
    </div>`);

  const flags = [];
  for (const line of summary.linesAbovePeripheralLimit) {
    flags.push(
      `<div class="flag caution"><span aria-hidden="true">!</span><span>${esc(
        line.fluid.name.trim() || 'A fluid',
      )} runs above 12.5% dextrose, which usually needs central access.</span></div>`,
    );
  }
  if (summary.band.key === 'high') {
    flags.push(
      '<div class="flag alert"><span aria-hidden="true">!</span><span>A sustained GIR at or above 12 mg/kg/min suggests reviewing for hyperinsulinism and confirming the concentration and access.</span></div>',
    );
  }
  if (flags.length) rows.push(flags.join(''));

  panel.innerHTML = rows.join('');
  applyTints(panel, colour);

  el('copy-gir').addEventListener('click', () => copyValues(summary));
  el('print-report').addEventListener('click', () => window.print());
}

/**
 * Paints the colours the markup could not carry.
 *
 * The page's Content-Security-Policy forbids inline style attributes, so the
 * template marks what needs tinting and the values are assigned here through
 * the CSSOM, which the policy does allow.
 */
function applyTints(root, colour) {
  const text = root.querySelector('[data-tint="text"]');
  if (text) text.style.color = colour;

  const pill = root.querySelector('[data-tint="pill"]');
  if (pill) {
    pill.style.color = colour;
    pill.style.borderColor = colour;
    pill.style.background = `color-mix(in srgb, ${colour} 12%, transparent)`;
  }

  for (const node of root.querySelectorAll('[data-bar-color]')) {
    node.style.background = node.dataset.barColor;
    if (node.dataset.barWidth) node.style.width = `${node.dataset.barWidth}%`;
  }
}

export function girSummaryText(summary) {
  return (
    `IV GIR: ${fixed(summary.ivGir, 2)} mg/kg/min\n` +
    `Enteral GIR: ${fixed(summary.enteralGir, 2)} mg/kg/min\n` +
    `Total GIR: ${fixed(summary.totalGir, 2)} mg/kg/min`
  );
}

async function copyValues(summary) {
  const text = girSummaryText(summary);
  try {
    await navigator.clipboard.writeText(text);
    toast('GIR values copied.');
  } catch (e) {
    // Clipboard permission denied, or an insecure origin. Fall back to a
    // selection the reader can copy by hand rather than failing silently.
    window.prompt('Copy these values:', text);
  }
}

let toastTimer = null;
function toast(message) {
  const node = el('toast');
  node.textContent = message;
  node.classList.add('show');
  window.clearTimeout(toastTimer);
  toastTimer = window.setTimeout(() => node.classList.remove('show'), 2200);
}

/* ------------------------------------------------------------------ header */

function renderPatientCard() {
  const patient = selected();
  const position = positionOf(patient);

  const name = el('patient-name');
  if (document.activeElement !== name) name.value = patient.name;
  name.placeholder = `Patient ${position}`;

  const weight = el('patient-weight');
  if (document.activeElement !== weight) {
    weight.value = patient.weightGrams === null ? '' : trimmed(patient.weightGrams, 1);
  }

  const hint = el('weight-hint');
  if (patient.weightGrams && patient.weightGrams > 0) {
    hint.textContent = `= ${trimmed(patient.weightGrams / 1000, 3)} kg`;
    hint.classList.remove('field-error');
  } else if (weight.value.trim() !== '') {
    hint.textContent = 'Enter a weight greater than 0';
    hint.classList.add('field-error');
  } else {
    hint.textContent = 'Dosing weight in grams';
    hint.classList.remove('field-error');
  }

  el('print-name').textContent = displayName(patient, position);
}

function render() {
  renderPatientStrip();
  renderPatientCard();
  renderFluids();
  renderResults();
}

/* -------------------------------------------------------------------- init */

export function start() {
  const state = load();
  patients = state.patients;
  selectedId = state.selectedId;

  el('patient-name').addEventListener('input', (event) => {
    selected().name = event.target.value;
    save(patients, selectedId);
    renderPatientStrip();
    renderPatientCard();
  });

  el('patient-weight').addEventListener('input', (event) => {
    selected().weightGrams = parseNumber(event.target.value);
    save(patients, selectedId);
    renderPatientStrip();
    renderPatientCard();
    renderFluids();
    renderResults();
  });

  el('duplicate-patient').addEventListener('click', () => {
    const source = selected();
    const copy = {
      ...blankPatient(),
      name: source.name.trim() === '' ? '' : `${source.name.trim()} (copy)`,
      weightGrams: source.weightGrams,
      fluids: source.fluids.map((f) => ({ ...newFluid(f), ...f, id: newFluid(f).id })),
    };
    patients.push(copy);
    selectedId = copy.id;
    commit();
  });

  el('clear-patient').addEventListener('click', () => {
    const patient = selected();
    patient.name = '';
    patient.weightGrams = null;
    patient.fluids = [newFluid({ name: 'D10W', dextrosePercent: 10 })];
    commit();
  });

  el('delete-patient').addEventListener('click', () => {
    const patient = selected();
    const position = positionOf(patient);
    if (!window.confirm(`Delete ${displayName(patient, position)}?`)) return;
    const index = patients.findIndex((p) => p.id === patient.id);
    patients = patients.filter((p) => p.id !== patient.id);
    if (patients.length === 0) patients = [blankPatient()];
    selectedId = patients[Math.min(index, patients.length - 1)].id;
    commit();
  });

  renderQuickAdd();
  render();
}
