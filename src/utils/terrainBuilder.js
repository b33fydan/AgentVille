import { VOXEL_SIZE, VOXEL_HALF, COLORS, getTerrainColor, TERRAIN_TYPES } from './voxelBuilder';
import * as THREE from 'three';

// ============= Seeded Random Number Generator =============
// Deterministic RNG so the same seed produces the same island
class SeededRandom {
  constructor(seed) {
    this.seed = seed;
  }

  next() {
    this.seed = (this.seed * 9301 + 49297) % 233280;
    return this.seed / 233280;
  }

  nextInt(max) {
    return Math.floor(this.next() * max);
  }

  choice(array) {
    if (!array || array.length === 0) return null;
    return array[this.nextInt(array.length)];
  }
}

// ============= Terrain Grid Generation =============

/**
 * Generates a 16x16 grid of terrain types with elevation data
 * Uses seeded RNG for reproducibility
 * @param {number} seed - Random seed (default: Date.now() % 1000000)
 * @returns {array} 16x16 2D array of terrain types
 */
export function generateTerrainGrid(seed = Date.now() % 1000000) {
  const rng = new SeededRandom(seed);
  const size = 16;
  const terrainArray = Object.values(TERRAIN_TYPES);
  const grid = [];

  // Create 16x16 grid with seeded randomization
  for (let row = 0; row < size; row++) {
    const gridRow = [];
    for (let col = 0; col < size; col++) {
      const terrainType = rng.choice(terrainArray);
      gridRow.push(terrainType);
    }
    grid.push(gridRow);
  }

  return grid;
}

// ============= Elevation & Color Lookup =============

const ELEVATION_MAP = {
  forest: { base: 0.15, variance: 0.2 },
  plains: { base: 0.0, variance: 0.1 },
  wetlands: { base: -0.1, variance: 0.15 },
  barren: { base: 0.05, variance: 0.15 }
};

const COLOR_PALETTES = {
  forest: ['#15803d', '#166534', '#14532d', '#22c55e'],
  plains: ['#ca8a04', '#a16207', '#eab308', '#d4a017'],
  wetlands: ['#0891b2', '#0e7490', '#155e75', '#22d3ee'],
  barren: ['#78716c', '#57534e', '#a8a29e', '#6b7280']
};

// ============= Terrain Scene Building =============

/**
 * Converts a 16x16 terrain grid into Three.js InstancedMeshes
 * Ground cubes: 0.5×0.25×0.5 with terrain-based elevation
 * Cliff layers: 3 levels beneath island for depth
 * @param {array} terrainGrid - 16x16 grid of terrain types
 * @param {number} cellSize - Size of each cell (default: 0.5)
 * @returns {THREE.Group} Group containing instanced ground + cliffs
 */
export function buildTerrainScene(terrainGrid, cellSize = 0.5) {
  const terrainGroup = new THREE.Group();

  if (!terrainGrid || terrainGrid.length === 0) {
    console.warn('Empty terrain grid');
    return terrainGroup;
  }

  const rows = terrainGrid.length; // 16
  const cols = terrainGrid[0].length; // 16
  const gridWidth = cols * cellSize;
  const gridHeight = rows * cellSize;

  // Center grid at (0, 0)
  const offsetX = gridWidth / 2;
  const offsetZ = gridHeight / 2;

  // ===== GROUND CUBES WITH INSTANCED MESH =====
  const groundGeometry = new THREE.BoxGeometry(cellSize, 0.25, cellSize);
  const dummy = new THREE.Object3D();

  // First pass: collect all ground cube positions
  const groundPositions = [];
  const rng = new SeededRandom(12345);

  for (let row = 0; row < rows; row++) {
    for (let col = 0; col < cols; col++) {
      const terrainType = terrainGrid[row][col];
      const elevation = ELEVATION_MAP[terrainType] || ELEVATION_MAP.plains;
      const colorPalette = COLOR_PALETTES[terrainType] || COLOR_PALETTES.plains;

      // Randomize height within variance
      const randomElevation = rng.next() * elevation.variance;
      const finalHeight = elevation.base + randomElevation;

      // Randomize color per cube for organic feel
      const colorIndex = rng.nextInt(colorPalette.length);
      const color = colorPalette[colorIndex];

      // Position: centered grid
      const x = col * cellSize - offsetX + cellSize / 2;
      const y = finalHeight;
      const z = row * cellSize - offsetZ + cellSize / 2;

      groundPositions.push({ x, y, z, color, terrainType });
    }
  }

  // Second pass: group by color and create InstancedMesh per color
  const colorGroups = {};
  groundPositions.forEach((pos) => {
    if (!colorGroups[pos.color]) {
      colorGroups[pos.color] = [];
    }
    colorGroups[pos.color].push(pos);
  });

  // Create InstancedMesh for each color group
  Object.entries(colorGroups).forEach(([color, positions]) => {
    const count = positions.length;
    const instancedMesh = new THREE.InstancedMesh(
      groundGeometry,
      new THREE.MeshStandardMaterial({
        color,
        metalness: 0.1,
        roughness: 0.8
      }),
      count
    );
    instancedMesh.castShadow = true;
    instancedMesh.receiveShadow = true;

    // Set transforms for each instance
    positions.forEach((pos, idx) => {
      dummy.position.set(pos.x, pos.y, pos.z);
      dummy.updateMatrix();
      instancedMesh.setMatrixAt(idx, dummy.matrix);
    });

    instancedMesh.instanceMatrix.needsUpdate = true;
    terrainGroup.add(instancedMesh);
  });

  // ===== CLIFF LAYERS BENEATH =====
  createCliffLayers(terrainGroup, terrainGrid, cellSize, offsetX, offsetZ);

  return terrainGroup;
}

/**
 * Creates 3 cliff/earth layers beneath the main island
 * Layer 1: Island edges, Y=-0.25, 20% skip
 * Layer 2: Inset 1, Y=-0.5, 30% skip
 * Layer 3: Inset 2, Y=-0.75–1.0, 40% skip (stone)
 */
function createCliffLayers(terrainGroup, terrainGrid, cellSize, offsetX, offsetZ) {
  const rows = terrainGrid.length;
  const cols = terrainGrid[0].length;
  const rng = new SeededRandom(54321);

  const dummy = new THREE.Object3D();
  const cliffGeometry = new THREE.BoxGeometry(cellSize, 0.25, cellSize);

  // Layer 1: Edges with dirt color
  const layer1Positions = [];
  for (let row = 0; row < rows; row++) {
    for (let col = 0; col < cols; col++) {
      const isEdge = row === 0 || row === rows - 1 || col === 0 || col === cols - 1;
      if (isEdge && rng.next() > 0.2) {
        const x = col * cellSize - offsetX + cellSize / 2;
        const y = -0.25;
        const z = row * cellSize - offsetZ + cellSize / 2;
        layer1Positions.push({ x, y, z });
      }
    }
  }

  if (layer1Positions.length > 0) {
    const layer1Mesh = new THREE.InstancedMesh(
      cliffGeometry,
      new THREE.MeshStandardMaterial({ color: '#8b7355', roughness: 0.9 }),
      layer1Positions.length
    );
    layer1Mesh.castShadow = true;
    layer1Mesh.receiveShadow = true;

    layer1Positions.forEach((pos, idx) => {
      dummy.position.set(pos.x, pos.y, pos.z);
      dummy.updateMatrix();
      layer1Mesh.setMatrixAt(idx, dummy.matrix);
    });

    layer1Mesh.instanceMatrix.needsUpdate = true;
    terrainGroup.add(layer1Mesh);
  }

  // Layer 2: Inset 1, darker brown
  const layer2Positions = [];
  for (let row = 1; row < rows - 1; row++) {
    for (let col = 1; col < cols - 1; col++) {
      const isInsetEdge = row === 1 || row === rows - 2 || col === 1 || col === cols - 2;
      if (isInsetEdge && rng.next() > 0.3) {
        const x = col * cellSize - offsetX + cellSize / 2;
        const y = -0.5;
        const z = row * cellSize - offsetZ + cellSize / 2;
        layer2Positions.push({ x, y, z });
      }
    }
  }

  if (layer2Positions.length > 0) {
    const layer2Mesh = new THREE.InstancedMesh(
      cliffGeometry,
      new THREE.MeshStandardMaterial({ color: '#6b5344', roughness: 0.95 }),
      layer2Positions.length
    );
    layer2Mesh.castShadow = true;
    layer2Mesh.receiveShadow = true;

    layer2Positions.forEach((pos, idx) => {
      dummy.position.set(pos.x, pos.y, pos.z);
      dummy.updateMatrix();
      layer2Mesh.setMatrixAt(idx, dummy.matrix);
    });

    layer2Mesh.instanceMatrix.needsUpdate = true;
    terrainGroup.add(layer2Mesh);
  }

  // Layer 3: Inset 2, stone color
  const layer3Positions = [];
  for (let row = 2; row < rows - 2; row++) {
    for (let col = 2; col < cols - 2; col++) {
      const isInsetEdge = row === 2 || row === rows - 3 || col === 2 || col === cols - 3;
      if (isInsetEdge && rng.next() > 0.4) {
        const x = col * cellSize - offsetX + cellSize / 2;
        const y = -0.75 - rng.next() * 0.25;
        const z = row * cellSize - offsetZ + cellSize / 2;
        layer3Positions.push({ x, y, z });
      }
    }
  }

  if (layer3Positions.length > 0) {
    const layer3Mesh = new THREE.InstancedMesh(
      cliffGeometry,
      new THREE.MeshStandardMaterial({ color: '#4b5563', roughness: 1.0, metalness: 0 }),
      layer3Positions.length
    );
    layer3Mesh.castShadow = true;
    layer3Mesh.receiveShadow = true;

    layer3Positions.forEach((pos, idx) => {
      dummy.position.set(pos.x, pos.y, pos.z);
      dummy.updateMatrix();
      layer3Mesh.setMatrixAt(idx, dummy.matrix);
    });

    layer3Mesh.instanceMatrix.needsUpdate = true;
    terrainGroup.add(layer3Mesh);
  }
}

/**
 * Creates a single terrain cell (legacy, kept for compatibility)
 * @deprecated Use InstancedMesh approach in buildTerrainScene
 */
function createTerrainCell(x, y, z, color, size, terrainType) {
  const geometry = new THREE.PlaneGeometry(size, size);
  const material = new THREE.MeshStandardMaterial({
    color,
    metalness: 0.2,
    roughness: 0.8
  });

  const mesh = new THREE.Mesh(geometry, material);
  mesh.rotation.x = -Math.PI / 2;
  mesh.position.set(x, y, z);
  mesh.userData.terrainType = terrainType;
  mesh.userData.gridX = Math.round(x / size);
  mesh.userData.gridZ = Math.round(z / size);
  mesh.castShadow = true;
  mesh.receiveShadow = true;

  return mesh;
}

// ============= Helpers =============

/**
 * Helper: Get terrain type at grid position
 */
export function getTerrainAtGrid(terrainGrid, gridX, gridZ) {
  if (gridX < 0 || gridX >= terrainGrid[0].length || gridZ < 0 || gridZ >= terrainGrid.length) {
    return null;
  }
  return terrainGrid[gridZ][gridX];
}

/**
 * Helper: Count terrain distribution (for debugging/balancing)
 */
export function getTerrainDistribution(terrainGrid) {
  const distribution = {};

  Object.values(TERRAIN_TYPES).forEach((type) => {
    distribution[type] = 0;
  });

  terrainGrid.forEach((row) => {
    row.forEach((cell) => {
      distribution[cell] = (distribution[cell] || 0) + 1;
    });
  });

  return distribution;
}
