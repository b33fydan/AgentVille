// ============= CROP GROWTH VISUALIZATION =============
// Crops visually grow over the course of a season (7 days).
// Creates a separate group of crop meshes that scale with game day.
// Neglected zones (no agent) grow slower.

import * as THREE from 'three';
import { useGameStore } from '../store/gameStore';
import { useAgentStore } from '../store/agentStore';

const CROP_COLORS = {
  seed: '#6b7280',      // Gray-green (tiny)
  sprout: '#22c55e',    // Green
  growing: '#84cc16',   // Yellow-green
  mature: '#eab308',    // Golden
  stubble: '#92643a'    // Brown (post-harvest)
};

let cropGroup = null;
let lastDay = -1;

/**
 * Initialize crop system. Call once during scene setup.
 * @param {THREE.Scene} scene
 * @param {Array} terrainGrid - 16x16 terrain grid
 */
export function initCrops(scene, terrainGrid) {
  cropGroup = new THREE.Group();
  cropGroup.userData.type = 'crops';
  scene.add(cropGroup);
  rebuildCrops(terrainGrid);
}

/**
 * Update crops based on current day. Call each frame (throttled internally).
 * @param {Array} terrainGrid
 */
export function updateCrops(terrainGrid) {
  const day = useGameStore.getState().day;
  if (day === lastDay) return; // Only rebuild on day change
  lastDay = day;
  rebuildCrops(terrainGrid);
}

/**
 * Dispose crop meshes.
 * @param {THREE.Scene} scene
 */
export function disposeCrops(scene) {
  if (cropGroup) {
    scene.remove(cropGroup);
    cropGroup = null;
  }
  lastDay = -1;
}

function rebuildCrops(terrainGrid) {
  if (!cropGroup || !terrainGrid || terrainGrid.length === 0) return;

  // Clear old crops
  while (cropGroup.children.length > 0) {
    cropGroup.remove(cropGroup.children[0]);
  }

  const day = useGameStore.getState().day;
  const agents = useAgentStore.getState().agents;
  const assignedZones = new Set(agents.filter((a) => a.assignedZone).map((a) => a.assignedZone));

  const rows = terrainGrid.length;
  const cols = terrainGrid[0].length;
  const cellSize = 0.5;
  const offsetX = (cols * cellSize) / 2;
  const offsetZ = (rows * cellSize) / 2;

  // Growth stage based on day (1-7)
  // Day 1-2: seed, Day 3-4: sprout, Day 5-6: grown, Day 7: mature/harvest
  const baseStage = day <= 2 ? 0 : day <= 4 ? 1 : day <= 6 ? 2 : 3;

  const sharedGeo = new THREE.BoxGeometry(0.025, 0.1, 0.025);
  const rng = (seed) => {
    const x = Math.sin(seed) * 10000;
    return x - Math.floor(x);
  };

  for (let row = 0; row < rows; row++) {
    for (let col = 0; col < cols; col++) {
      const type = terrainGrid[row][col];
      if (type !== 'plains') continue;

      const x = col * cellSize - offsetX + cellSize / 2;
      const z = row * cellSize - offsetZ + cellSize / 2;
      const seed = 54321 + row * cols + col;

      // Zones with assigned agents grow faster
      const hasWorker = assignedZones.has('plains');
      const stage = hasWorker ? baseStage : Math.max(0, baseStage - 1);

      const stalkCount = stage === 0 ? 2 : stage === 1 ? 4 : stage === 2 ? 7 : 10;
      const stalkHeight = stage === 0 ? 0.04 : stage === 1 ? 0.1 : stage === 2 ? 0.2 : 0.3;
      const color = stage === 0 ? CROP_COLORS.seed :
        stage === 1 ? CROP_COLORS.sprout :
        stage === 2 ? CROP_COLORS.growing : CROP_COLORS.mature;

      const mat = new THREE.MeshStandardMaterial({ color, roughness: 0.7 });

      for (let i = 0; i < stalkCount; i++) {
        const ox = (rng(seed + i * 7) - 0.5) * 0.3;
        const oz = (rng(seed + i * 7 + 1) - 0.5) * 0.3;
        const lean = (rng(seed + i * 7 + 2) - 0.5) * 0.15;

        const stalk = new THREE.Mesh(sharedGeo, mat);
        stalk.position.set(x + ox, stalkHeight / 2 + 0.01, z + oz);
        stalk.scale.set(1, stalkHeight / 0.1, 1);
        stalk.rotation.z = lean;
        stalk.castShadow = true;
        cropGroup.add(stalk);
      }
    }
  }
}
