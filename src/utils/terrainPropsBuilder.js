import { TERRAIN_TYPES } from './voxelBuilder';
import { VoxelBatcher } from './voxelBatcher';

/**
 * Seeded random for consistent prop placement
 */
function seededRandom(seed) {
  const x = Math.sin(seed) * 10000;
  return x - Math.floor(x);
}

/**
 * Populate terrain with ambient props for 16x16 grid.
 * Uses VoxelBatcher for InstancedMesh rendering (~20-30 draw calls
 * instead of ~4,000+ individual meshes).
 * Run ONCE on island creation.
 */
export function populateTerrainProps(scene, terrainGrid, islandSeed = 12345) {
  if (!terrainGrid || terrainGrid.length === 0) return;

  const batcher = new VoxelBatcher();
  const rows = terrainGrid.length;
  const cols = terrainGrid[0].length;
  const cellSize = 0.5;
  const offsetX = (cols * cellSize) / 2;
  const offsetZ = (rows * cellSize) / 2;

  for (let row = 0; row < rows; row++) {
    for (let col = 0; col < cols; col++) {
      const terrainType = terrainGrid[row][col];
      const x = col * cellSize - offsetX + cellSize / 2;
      const z = row * cellSize - offsetZ + cellSize / 2;
      const tileIndex = row * cols + col;
      const seed = islandSeed + tileIndex;

      switch (terrainType) {
        case TERRAIN_TYPES.forest:
          addForestProps(batcher, x, z, seed);
          break;
        case TERRAIN_TYPES.plains:
          addPlainsProps(batcher, x, z, seed);
          break;
        case TERRAIN_TYPES.wetlands:
          addWetlandsProps(batcher, x, z, seed);
          break;
        case TERRAIN_TYPES.barren:
          addBarrenProps(batcher, x, z, seed);
          break;
        default:
          break;
      }
    }
  }

  // Farmhouse (central)
  addFarmhouse(batcher);

  // Flush all batched instances into InstancedMeshes
  batcher.flush(scene);
}

// ============= FOREST PROPS =============

function addForestProps(batcher, x, z, seed) {
  const rng1 = seededRandom(seed);
  const rng2 = seededRandom(seed + 1);
  const rng3 = seededRandom(seed + 2);

  // Trees (2-3 per tile)
  const treeCount = 2 + (rng1 > 0.6 ? 1 : 0);
  for (let i = 0; i < treeCount; i++) {
    const ox = (seededRandom(seed + i * 10) - 0.5) * 0.35;
    const oz = (seededRandom(seed + i * 10 + 1) - 0.5) * 0.35;
    const type = seededRandom(seed + i * 10 + 2) > 0.5 ? 'pine' : 'oak';
    addTree(batcher, x + ox, z + oz, type, seed + i * 10);
  }

  // Bushes (2-4 per tile)
  const bushCount = 2 + Math.floor(rng2 * 2);
  for (let i = 0; i < bushCount; i++) {
    const bx = x + (seededRandom(seed + 100 + i) - 0.5) * 0.35;
    const bz = z + (seededRandom(seed + 200 + i) - 0.5) * 0.35;
    batcher.addSphere(bx, 0.08, bz, '#3a7d3a', 0.15, 4, 4, { scaleY: 0.6 });
  }

  // Rocks (50% chance)
  if (rng3 > 0.5) {
    addRockCluster(batcher, x + (rng3 - 0.5) * 0.3, z + (seededRandom(seed + 3) - 0.5) * 0.3, seed + 4);
  }
}

function addTree(batcher, x, z, type, seed) {
  if (type === 'pine') {
    // Trunk
    batcher.addBox(x, 0.25, z, '#654321', 0.08, 0.5, 0.08);
    // Three tier cone leaves
    const tiers = [
      { y: 0.5, r: 0.25, h: 0.2, c: '#1a5f3d' },
      { y: 0.6, r: 0.17, h: 0.2, c: '#2d7a4a' },
      { y: 0.7, r: 0.09, h: 0.2, c: '#3a9d5d' }
    ];
    tiers.forEach((t) => {
      batcher.addCone(x, t.y, z, t.c, t.r, t.h, 6);
    });
  } else {
    // Oak trunk
    batcher.addBox(x, 0.2, z, '#5d4e37', 0.12, 0.4, 0.12);
    // Oak canopy (sphere cluster)
    const canopy = [
      [0, 0.35, 0], [0.1, 0.35, 0.1], [-0.1, 0.35, 0.1],
      [0.1, 0.35, -0.1], [-0.1, 0.35, -0.1],
      [0, 0.45, 0], [0.08, 0.45, 0.08], [-0.08, 0.45, -0.08]
    ];
    canopy.forEach(([ox, oy, oz]) => {
      batcher.addSphere(x + ox, oy, z + oz, '#2d5a3d', 0.15, 4, 4, { scaleY: 0.9 });
    });
  }
}

function addRockCluster(batcher, x, z, seed) {
  const count = 3 + Math.floor(seededRandom(seed) * 2);
  for (let i = 0; i < count; i++) {
    const ox = (seededRandom(seed + i * 10) - 0.5) * 0.2;
    const oz = (seededRandom(seed + i * 10 + 1) - 0.5) * 0.2;
    const w = 0.12 + seededRandom(seed + i * 10 + 3) * 0.08;
    const h = 0.08 + seededRandom(seed + i * 10 + 4) * 0.06;
    const d = 0.12 + seededRandom(seed + i * 10 + 5) * 0.08;
    batcher.addBox(x + ox, 0.05, z + oz, '#888888', w, h, d);
  }
}

// ============= PLAINS PROPS =============

function addPlainsProps(batcher, x, z, seed) {
  const rng = seededRandom(seed);

  // Wheat stalks (8-12 per tile)
  const wheatCount = 8 + Math.floor(rng * 4);
  const wheatColors = ['#eab308', '#ca8a04', '#fbbf24'];
  for (let i = 0; i < wheatCount; i++) {
    const wx = x - 0.2 + (i % 4) * 0.1;
    const wz = z - 0.2 + Math.floor(i / 4) * 0.1;
    const c = wheatColors[Math.floor(seededRandom(seed + i * 5) * 3)];
    batcher.addBox(wx, 0.125, wz, c, 0.03, 0.25, 0.03);
  }

  // Hay bales
  if (rng > 0.3) {
    const hayCount = 1 + (rng > 0.7 ? 1 : 0) + (rng > 0.85 ? 1 : 0);
    for (let i = 0; i < hayCount; i++) {
      const hx = x + (seededRandom(seed + 1000 + i) - 0.5) * 0.3;
      const hz = z + (seededRandom(seed + 1001 + i) - 0.5) * 0.3;
      batcher.addBox(hx, 0.08, hz, '#d4a017', 0.2, 0.1, 0.1);
    }
  }
}

// ============= WETLANDS PROPS =============

function addWetlandsProps(batcher, x, z, seed) {
  const rng1 = seededRandom(seed);
  const rng2 = seededRandom(seed + 1);

  // Reeds (6-10 per tile)
  const reedCount = 6 + Math.floor(rng1 * 4);
  const reedColors = ['#22d3ee', '#0891b2', '#15803d'];
  for (let i = 0; i < reedCount; i++) {
    const rx = x + (seededRandom(seed + i * 5) - 0.5) * 0.35;
    const rz = z + (seededRandom(seed + i * 5 + 1) - 0.5) * 0.35;
    const lean = (seededRandom(seed + i * 5 + 2) - 0.5) * 0.1;
    const c = reedColors[Math.floor(seededRandom(seed + i * 5 + 2) * 3)];
    batcher.addBox(rx + lean * 0.1, 0.15, rz, c, 0.02, 0.3, 0.02, { rotZ: lean * 0.3 });
  }

  // Shallow water patches
  if (rng2 > 0.4) {
    const waterCount = 2 + (rng2 > 0.7 ? 1 : 0);
    for (let i = 0; i < waterCount; i++) {
      const wx = x + (seededRandom(seed + 500 + i) - 0.5) * 0.3;
      const wz = z + (seededRandom(seed + 501 + i) - 0.5) * 0.3;
      batcher.addBox(wx, 0.02, wz, '#0891b2', 0.15, 0.05, 0.15, { transparent: true, opacity: 0.6 });
    }
  }
}

// ============= BARREN PROPS =============

function addBarrenProps(batcher, x, z, seed) {
  const rng = seededRandom(seed);

  // Rock clusters
  if (rng > 0.3) {
    addRockCluster(batcher, x, z, seed + 100);
  }

  // Dead trees (33% chance)
  if (rng > 0.67) {
    batcher.addBox(x + 0.08, 0.18, z, '#4a4a4a', 0.06, 0.35, 0.06, { rotZ: 0.2 });
  }
}

// ============= FARMHOUSE (Central) =============

function addFarmhouse(batcher) {
  // Main body
  batcher.addBox(0, 0.09, 0, '#a0826d', 0.3, 0.18, 0.2);
  // Roof
  batcher.addCone(0, 0.25, 0, '#6b5344', 0.18, 0.12, 4);
  // Door
  batcher.addBox(0, 0.06, 0.11, '#3a3a3a', 0.06, 0.12, 0.02);
  // Windows
  batcher.addBox(-0.08, 0.12, 0.11, '#87ceeb', 0.03, 0.03, 0.02);
  batcher.addBox(0.08, 0.12, 0.11, '#87ceeb', 0.03, 0.03, 0.02);
  // Fence posts
  [[-0.25, -0.2], [0.25, -0.2], [-0.25, 0.2], [0.25, 0.2]].forEach(([fx, fz]) => {
    batcher.addBox(fx, 0.08, fz, '#5d4e37', 0.04, 0.15, 0.04);
  });
}
