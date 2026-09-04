// The fluids and feeds that can be added in one click, mirroring the app.
import { FluidRoute } from './gir.js';

export const infusionPresets = [
  { name: 'D5W', dextrosePercent: 5 },
  { name: 'D7.5W', dextrosePercent: 7.5 },
  { name: 'D10W', dextrosePercent: 10 },
  { name: 'D12.5W', dextrosePercent: 12.5 },
  { name: 'D15W', dextrosePercent: 15 },
  { name: 'D20W', dextrosePercent: 20 },
  { name: 'D25W', dextrosePercent: 25 },
  { name: 'TPN', dextrosePercent: 12.5 },
  { name: 'Lipid 20%', dextrosePercent: 0 },
  { name: 'NS', dextrosePercent: 0 },
].map((p) => ({ ...p, route: FluidRoute.intravenous }));

// Typical carbohydrate content in g per 100 mL. Starting points, not product
// data: fortification, batch and recipe all move them, so the value stays
// editable on every line. Figures follow the table published at
// infantfeeds.com/gir-calculator.
export const feedPresets = [
  { name: 'Breast milk', dextrosePercent: 7 },
  { name: 'BM + Prolacta', dextrosePercent: 7.6 },
  { name: 'BM + Similac HMF 22', dextrosePercent: 7.7 },
  { name: 'BM + Similac HMF 24', dextrosePercent: 8.3 },
  { name: 'BM + Enfamil HMF 22', dextrosePercent: 6.9 },
  { name: 'BM + Enfamil HMF 24', dextrosePercent: 6.8 },
  { name: 'Formula', dextrosePercent: 7.5 },
].map((p) => ({ ...p, route: FluidRoute.enteral }));

/** Distinct colours for the per-line contribution bar, reused cyclically. */
export const linePalette = [
  '#00696e',
  '#7b5ba6',
  '#b26a00',
  '#1b7f4b',
  '#9e4a6b',
  '#3f6bb0',
];

export const lineColor = (index) => linePalette[index % linePalette.length];
