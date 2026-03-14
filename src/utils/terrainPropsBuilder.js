import * as THREE from 'three';
import { COLORS, TERRAIN_TYPES } from './voxelBuilder';

/**
 * Seeded random for consistent prop placement
 */
function seededRandom(seed) {
  const x = Math.sin(seed) * 10000;
  return x - Math.floor(x);
}

/**
 * Populate terrain with ambient props for 16×16 grid
 * Forest: trees + bushes + logs
 * Plains: wheat field + farmhouse
 * Wetlands: reeds + water patches
 * Barren: rocks + dead trees
 * Run ONCE on island creation
 */
export function populateTerrainProps(scene, terrainGrid, islandSeed = 12345) {
  if (!terrainGrid || terrainGrid.length === 0) return;

  const rows = terrainGrid.length; // 16
  const cols = terrainGrid[0].length; // 16
  const cellSize = 0.5;
  const gridWidth = cols * cellSize;
  const gridHeight = rows * cellSize;
  const offsetX = gridWidth / 2;
  const offsetZ = gridHeight / 2;

  // Add props per terrain tile
  for (let row = 0; row < rows; row++) {
    for (let col = 0; col < cols; col++) {
      const terrainType = terrainGrid[row][col];
      const x = col * cellSize - offsetX + cellSize / 2;
      const z = row * cellSize - offsetZ + cellSize / 2;
      const tileIndex = row * cols + col;
      const seed = islandSeed + tileIndex;

      switch (terrainType) {
        case TERRAIN_TYPES.FOREST:
          addForestProps(scene, x, z, seed);
          break;
        case TERRAIN_TYPES.PLAINS:
          addPlainsProps(scene, x, z, seed);
          break;
        case TERRAIN_TYPES.WETLANDS:
          addWetlandsProps(scene, x, z, seed);
          break;
        case TERRAIN_TYPES.BARREN:
          addBarrenProps(scene, x, z, seed);
          break;
        default:
          break;
      }
    }
  }

  // Add central farmhouse
  addFarmhouse(scene);
}

// ============= FOREST PROPS =============

function addForestProps(scene, x, z, seed) {
  const rng1 = seededRandom(seed);
  const rng2 = seededRandom(seed + 1);
  const rng3 = seededRandom(seed + 2);

  // 2-3 trees per tile (mix of pine and oak)
  const treeCount = 2 + (rng1 > 0.6 ? 1 : 0);
  for (let i = 0; i < treeCount; i++) {
    const offsetX = (seededRandom(seed + i * 10) - 0.5) * 0.35;
    const offsetZ = (seededRandom(seed + i * 10 + 1) - 0.5) * 0.35;
    const treeType = seededRandom(seed + i * 10 + 2) > 0.5 ? 'pine' : 'oak';
    const tree = createTree(x + offsetX, 0, z + offsetZ, treeType);
    scene.add(tree);
  }

  // Ground cover bushes (2-4 per tile)
  const bushCount = 2 + Math.floor(rng2 * 2);
  for (let i = 0; i < bushCount; i++) {
    const bushX = x + (seededRandom(seed + 100 + i) - 0.5) * 0.35;
    const bushZ = z + (seededRandom(seed + 200 + i) - 0.5) * 0.35;
    createBush(scene, bushX, bushZ);
  }

  // Rock clusters (1-2 per tile)
  if (rng3 > 0.5) {
    const rockX = x + (rng3 - 0.5) * 0.3;
    const rockZ = z + (seededRandom(seed + 3) - 0.5) * 0.3;
    createRockCluster(scene, rockX, rockZ, seededRandom(seed + 4));
  }
}

function createTree(x, y, z, type) {
  const group = new THREE.Group();

  if (type === 'pine') {
    // Pine: narrow trunk + cone-shaped canopy
    const trunk = new THREE.Mesh(
      new THREE.BoxGeometry(0.08, 0.5, 0.08),
      new THREE.MeshStandardMaterial({ color: '#654321', roughness: 0.9 })
    );
    trunk.position.set(x, y + 0.25, z);
    trunk.castShadow = true;
    group.add(trunk);

    // Three-tier cone leaves
    for (let tier = 0; tier < 3; tier++) {
      const tierRadius = 0.25 - tier * 0.08;
      const tierHeight = 0.5 + tier * 0.1;
      const leaves = new THREE.Mesh(
        new THREE.ConeGeometry(tierRadius, 0.2, 6),
        new THREE.MeshStandardMaterial({
          color: ['#1a5f3d', '#2d7a4a', '#3a9d5d'][tier],
          roughness: 0.8
        })
      );
      leaves.position.set(x, y + tierHeight, z);
      leaves.castShadow = true;
      group.add(leaves);
    }
  } else if (type === 'oak') {
    // Oak: thick trunk + round canopy
    const trunk = new THREE.Mesh(
      new THREE.BoxGeometry(0.12, 0.4, 0.12),
      new THREE.MeshStandardMaterial({ color: '#5d4e37', roughness: 0.95 })
    );
    trunk.position.set(x, y + 0.2, z);
    trunk.castShadow = true;
    group.add(trunk);

    // Round canopy (8-cube cluster simulation)
    const canopyPositions = [
      [0, 0.35, 0],
      [0.1, 0.35, 0.1],
      [-0.1, 0.35, 0.1],
      [0.1, 0.35, -0.1],
      [-0.1, 0.35, -0.1],
      [0, 0.45, 0],
      [0.08, 0.45, 0.08],
      [-0.08, 0.45, -0.08]
    ];

    canopyPositions.forEach(([ox, oy, oz]) => {
      const canopyLeaf = new THREE.Mesh(
        new THREE.SphereGeometry(0.15, 4, 4),
        new THREE.MeshStandardMaterial({
          color: '#2d5a3d',
          roughness: 0.75
        })
      );
      canopyLeaf.position.set(x + ox, y + oy, z + oz);
      canopyLeaf.castShadow = true;
      canopyLeaf.scale.set(1, 0.9, 1);
      group.add(canopyLeaf);
    });
  }

  return group;
}

function createBush(scene, x, z) {
  const bush = new THREE.Mesh(
    new THREE.SphereGeometry(0.15, 4, 4),
    new THREE.MeshStandardMaterial({
      color: '#3a7d3a',
      roughness: 0.8
    })
  );
  bush.position.set(x, 0.08, z);
  bush.castShadow = true;
  bush.scale.set(1, 0.6, 1);
  scene.add(bush);
}

function createRockCluster(scene, x, z, rng) {
  // 3-5 irregular rock cubes
  const rockCount = 3 + Math.floor(rng * 2);
  const group = new THREE.Group();

  for (let i = 0; i < rockCount; i++) {
    const offsetX = (seededRandom(rng + i * 10) - 0.5) * 0.2;
    const offsetZ = (seededRandom(rng + i * 10 + 1) - 0.5) * 0.2;
    const offsetY = (seededRandom(rng + i * 10 + 2) - 0.5) * 0.1;

    const rock = new THREE.Mesh(
      new THREE.BoxGeometry(
        0.12 + seededRandom(rng + i * 10 + 3) * 0.08,
        0.08 + seededRandom(rng + i * 10 + 4) * 0.06,
        0.12 + seededRandom(rng + i * 10 + 5) * 0.08
      ),
      new THREE.MeshStandardMaterial({
        color: '#888888',
        roughness: 1.0
      })
    );
    rock.position.set(offsetX, 0.05 + offsetY, offsetZ);
    rock.castShadow = true;
    group.add(rock);
  }

  group.position.set(x, 0, z);
  scene.add(group);
}

// ============= PLAINS PROPS =============

function addPlainsProps(scene, x, z, seed) {
  const rng = seededRandom(seed);

  // Wheat field rows (8-12 stalks per tile)
  const wheatCount = 8 + Math.floor(rng * 4);
  for (let i = 0; i < wheatCount; i++) {
    const wheatX = x - 0.2 + (i % 4) * 0.1;
    const wheatZ = z - 0.2 + Math.floor(i / 4) * 0.1;
    createWheatStalk(scene, wheatX, wheatZ, seededRandom(seed + i * 5));
  }

  // Hay bales (1-3 per zone)
  if (rng > 0.3) {
    const hayCount = 1 + (rng > 0.7 ? 1 : 0) + (rng > 0.85 ? 1 : 0);
    for (let i = 0; i < hayCount; i++) {
      const hayX = x + (seededRandom(seed + 1000 + i) - 0.5) * 0.3;
      const hayZ = z + (seededRandom(seed + 1001 + i) - 0.5) * 0.3;
      createHayBale(scene, hayX, hayZ);
    }
  }
}

function createWheatStalk(scene, x, z, rng) {
  // Thin yellow rectangle
  const stalk = new THREE.Mesh(
    new THREE.BoxGeometry(0.03, 0.25, 0.03),
    new THREE.MeshStandardMaterial({
      color: ['#eab308', '#ca8a04', '#fbbf24'][Math.floor(rng * 3)],
      roughness: 0.6
    })
  );
  stalk.position.set(x, 0.125, z);
  stalk.castShadow = true;
  scene.add(stalk);
}

function createHayBale(scene, x, z) {
  // 2×1×1 cluster of tan cubes
  const bale = new THREE.Mesh(
    new THREE.BoxGeometry(0.2, 0.1, 0.1),
    new THREE.MeshStandardMaterial({
      color: '#d4a017',
      roughness: 0.85
    })
  );
  bale.position.set(x, 0.08, z);
  bale.castShadow = true;
  scene.add(bale);
}

// ============= WETLANDS PROPS =============

function addWetlandsProps(scene, x, z, seed) {
  const rng1 = seededRandom(seed);
  const rng2 = seededRandom(seed + 1);

  // Reeds (6-10 per tile)
  const reedCount = 6 + Math.floor(rng1 * 4);
  for (let i = 0; i < reedCount; i++) {
    const reedX = x + (seededRandom(seed + i * 5) - 0.5) * 0.35;
    const reedZ = z + (seededRandom(seed + i * 5 + 1) - 0.5) * 0.35;
    createReed(scene, reedX, reedZ, seededRandom(seed + i * 5 + 2));
  }

  // Shallow water patches (2-3 per tile, 60% chance)
  if (rng2 > 0.4) {
    const waterCount = 2 + (rng2 > 0.7 ? 1 : 0);
    for (let i = 0; i < waterCount; i++) {
      const waterX = x + (seededRandom(seed + 500 + i) - 0.5) * 0.3;
      const waterZ = z + (seededRandom(seed + 501 + i) - 0.5) * 0.3;
      createShallowWater(scene, waterX, waterZ);
    }
  }
}

function createReed(scene, x, z, rng) {
  // Thin green rectangle with slight lean
  const lean = (rng - 0.5) * 0.1;
  const reed = new THREE.Mesh(
    new THREE.BoxGeometry(0.02, 0.3, 0.02),
    new THREE.MeshStandardMaterial({
      color: ['#22d3ee', '#0891b2', '#15803d'][Math.floor(rng * 3)],
      roughness: 0.6
    })
  );
  reed.position.set(x + lean * 0.1, 0.15, z);
  reed.rotation.z = lean * 0.3;
  reed.castShadow = true;
  scene.add(reed);
}

function createShallowWater(scene, x, z) {
  // Flat blue cube, semi-transparent
  const water = new THREE.Mesh(
    new THREE.BoxGeometry(0.15, 0.05, 0.15),
    new THREE.MeshStandardMaterial({
      color: '#0891b2',
      transparent: true,
      opacity: 0.6,
      roughness: 0.3,
      metalness: 0.2
    })
  );
  water.position.set(x, 0.02, z);
  water.receiveShadow = true;
  scene.add(water);
}

// ============= BARREN PROPS =============

function addBarrenProps(scene, x, z, seed) {
  const rng = seededRandom(seed);

  // Rock clusters (1-2 per tile)
  if (rng > 0.3) {
    createRockCluster(scene, x, z, rng);
  }

  // Dead trees (1 per 2-3 tiles, ~33% chance)
  if (rng > 0.67) {
    createDeadTree(scene, x, z);
  }
}

function createDeadTree(scene, x, z) {
  // Dead trunk only, no leaves, slight lean
  const trunk = new THREE.Mesh(
    new THREE.BoxGeometry(0.06, 0.35, 0.06),
    new THREE.MeshStandardMaterial({
      color: '#4a4a4a',
      roughness: 1.0
    })
  );
  trunk.position.set(x + 0.08, 0.18, z);
  trunk.rotation.z = 0.2; // Slight lean
  trunk.castShadow = true;
  scene.add(trunk);
}

// ============= FARMHOUSE (Central Anchor) =============

function addFarmhouse(scene) {
  // Centered at (0, 0, 0)
  // 6w × 4d × 3h in 0.25-unit cubes

  // Main structure: warm brown
  const mainBody = new THREE.Mesh(
    new THREE.BoxGeometry(0.3, 0.18, 0.2),
    new THREE.MeshStandardMaterial({
      color: '#a0826d',
      roughness: 0.8
    })
  );
  mainBody.position.set(0, 0.09, 0);
  mainBody.castShadow = true;
  scene.add(mainBody);

  // Pitched roof: triangle (cone)
  const roof = new THREE.Mesh(
    new THREE.ConeGeometry(0.18, 0.12, 4),
    new THREE.MeshStandardMaterial({
      color: '#6b5344',
      roughness: 0.9
    })
  );
  roof.position.set(0, 0.25, 0);
  roof.castShadow = true;
  scene.add(roof);

  // Door: darker brown rectangle
  const door = new THREE.Mesh(
    new THREE.BoxGeometry(0.06, 0.12, 0.02),
    new THREE.MeshStandardMaterial({ color: '#3a3a3a' })
  );
  door.position.set(0, 0.06, 0.11);
  door.castShadow = true;
  scene.add(door);

  // Window: tiny blue square
  const window1 = new THREE.Mesh(
    new THREE.BoxGeometry(0.03, 0.03, 0.02),
    new THREE.MeshStandardMaterial({ color: '#87ceeb' })
  );
  window1.position.set(-0.08, 0.12, 0.11);
  window1.castShadow = true;
  scene.add(window1);

  const window2 = new THREE.Mesh(
    new THREE.BoxGeometry(0.03, 0.03, 0.02),
    new THREE.MeshStandardMaterial({ color: '#87ceeb' })
  );
  window2.position.set(0.08, 0.12, 0.11);
  window2.castShadow = true;
  scene.add(window2);

  // Fence boundary around farmhouse (4 posts)
  const fencePositions = [
    [-0.25, -0.2],
    [0.25, -0.2],
    [-0.25, 0.2],
    [0.25, 0.2]
  ];

  fencePositions.forEach(([fx, fz]) => {
    const post = new THREE.Mesh(
      new THREE.BoxGeometry(0.04, 0.15, 0.04),
      new THREE.MeshStandardMaterial({ color: '#5d4e37' })
    );
    post.position.set(fx, 0.08, fz);
    post.castShadow = true;
    scene.add(post);
  });
}
