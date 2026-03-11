import * as THREE from 'three';
import { createTree, createRocks, createVoxel, VOXEL_SIZE, VOXEL_HALF, COLORS } from './voxelBuilder';

/**
 * Seeded random number generator (for consistent prop placement)
 * Returns number 0-1
 */
function seededRandom(seed) {
  const x = Math.sin(seed) * 10000;
  return x - Math.floor(x);
}

/**
 * Populate terrain with ambient props (trees, grass, reeds, rocks)
 * Run ONCE on island creation, never remove these props
 * 
 * @param {THREE.Scene} scene - Scene to add props to
 * @param {Array} terrain - 8x8 array of { x, z, type }
 * @param {number} islandSeed - Seed for RNG consistency
 */
export function populateTerrainProps(scene, terrain, islandSeed = 12345) {
  terrain.forEach((tile, index) => {
    const { x, z, type } = tile;
    const rng = seededRandom(islandSeed + index); // Consistent RNG per tile

    switch (type) {
      case 'forest':
        addForestProps(scene, x, z, index, islandSeed);
        break;

      case 'plains':
        addPlainsProps(scene, x, z, index, islandSeed);
        break;

      case 'wetlands':
        addWetlandsProps(scene, x, z, index, islandSeed);
        break;

      case 'barren':
        addBarrenProps(scene, x, z, index, islandSeed);
        break;

      default:
        break;
    }
  });

  // Add farmhouse fence & path in center (optional polish)
  addFarmhouseBoundary(scene, terrain);
}

/**
 * Forest tiles: Trees with ground cover
 */
function addForestProps(scene, x, z, index, seed) {
  const rng1 = seededRandom(seed + index * 2);
  const rng2 = seededRandom(seed + index * 2 + 1);

  // 1-2 trees with offset
  const treeCount = rng1 > 0.5 ? 2 : 1;
  for (let i = 0; i < treeCount; i++) {
    const offsetX = (rng1 - 0.5) * 0.35;
    const offsetZ = (rng2 - 0.5) * 0.35;
    const tree = createTree(x + offsetX, z + offsetZ, 'oak');
    scene.add(tree);
  }

  // Ground moss/lichen (tiny dark spots)
  const mossCount = 3 + Math.floor(rng2 * 2);
  for (let i = 0; i < mossCount; i++) {
    const mossX = x + (Math.random() - 0.5) * 0.4;
    const mossZ = z + (Math.random() - 0.5) * 0.4;
    const moss = createVoxel(mossX, VOXEL_HALF * 0.3, mossZ, COLORS.grassMoss, 0.3);
    moss.scale.set(0.5, 0.2, 0.5);
    scene.add(moss);
  }
}

/**
 * Plains tiles: Grass tufts (ground cover, not wheat)
 */
function addPlainsProps(scene, x, z, index, seed) {
  const rng1 = seededRandom(seed + index * 3);
  const rng2 = seededRandom(seed + index * 3 + 1);

  // Ground cover grass (small green cubes scattered)
  const grassCount = 2 + Math.floor(rng1 * 3);
  for (let i = 0; i < grassCount; i++) {
    const grassX = x + (rng1 - 0.5) * 0.4;
    const grassZ = z + (rng2 - 0.5) * 0.4;
    const grass = createVoxel(grassX, VOXEL_HALF * 0.5, grassZ, COLORS.grassBase, 0.25);
    grass.scale.set(0.4, 0.3, 0.4);
    scene.add(grass);
  }

  // Occasional wildflower (tiny yellow-ish accent)
  if (rng2 > 0.7) {
    const flowerX = x + (rng2 - 0.5) * 0.25;
    const flowerZ = z + (rng2 - 0.5) * 0.25;
    const flower = createVoxel(flowerX, VOXEL_HALF + 0.1, flowerZ, COLORS.gold, 0.15);
    flower.scale.set(0.3, 0.6, 0.3);
    scene.add(flower);
  }
}

/**
 * Wetlands tiles: Reeds/marsh vegetation
 */
function addWetlandsProps(scene, x, z, index, seed) {
  const rng1 = seededRandom(seed + index * 4);
  const rng2 = seededRandom(seed + index * 4 + 1);

  // Reed clusters (thin tall green rectangles with lean)
  const reedCount = 3 + Math.floor(rng1 * 3);
  for (let i = 0; i < reedCount; i++) {
    const reedX = x + (rng1 - 0.5) * 0.3;
    const reedZ = z + (rng2 - 0.5) * 0.3;
    const lean = (rng2 - 0.5) * 0.2; // Organic sway

    const reed = createVoxel(reedX + lean, VOXEL_HALF + 0.15, reedZ, COLORS.grassBase, 0.5);
    reed.scale.set(0.03, 0.3, 0.03);
    reed.rotation.z = lean * 0.5;
    scene.add(reed);
  }

  // Tiny blue puddles (water accent)
  if (rng2 > 0.6) {
    const pudleX = x + (rng2 - 0.5) * 0.35;
    const pudleZ = z + (rng2 - 0.5) * 0.35;
    const pudle = createVoxel(pudleX, VOXEL_HALF * 0.1, pudleZ, COLORS.waterShallow, 0.2);
    pudle.scale.set(1.0, 0.1, 1.0);
    scene.add(pudle);
  }
}

/**
 * Barren tiles: Rocks and sparse elements
 */
function addBarrenProps(scene, x, z, index, seed) {
  // Rock cluster (using createRocks utility)
  const rocks = createRocks(x, z, 1 + Math.floor(Math.random() * 2));
  scene.add(rocks);

  // Occasional scattered small stone
  if (Math.random() > 0.5) {
    const stoneX = x + (Math.random() - 0.5) * 0.3;
    const stoneZ = z + (Math.random() - 0.5) * 0.3;
    const stone = createVoxel(stoneX, VOXEL_HALF, stoneZ, COLORS.stoneLight, 0.3);
    stone.scale.set(0.6, 0.4, 0.6);
    scene.add(stone);
  }
}

/**
 * Add visual boundary around farmhouse (fence + path)
 * Center tiles only, for home base feel
 */
function addFarmhouseBoundary(scene, terrain) {
  // Find center tile (approximately index 27 for 8x8)
  const centerTile = terrain[27];
  if (!centerTile) return;

  const { x, z } = centerTile;

  // Wooden fence posts (4 corners)
  const fencePositions = [
    [x - 0.6, z - 0.6],
    [x + 0.6, z - 0.6],
    [x - 0.6, z + 0.6],
    [x + 0.6, z + 0.6]
  ];

  fencePositions.forEach(([fenceX, fenceZ]) => {
    const post = createVoxel(fenceX, VOXEL_HALF + 0.2, fenceZ, COLORS.woodDark, 0.6);
    post.scale.set(0.2, 0.4, 0.2);
    scene.add(post);

    // Horizontal rails connecting posts (simplified)
    const rail = createVoxel(fenceX, VOXEL_HALF + 0.35, fenceZ, COLORS.woodBase, 0.8);
    rail.scale.set(1.4, 0.1, 0.1);
    scene.add(rail);
  });

  // Light path from farmhouse toward island exit
  const pathTiles = [
    [x, z - 1.2],
    [x, z - 1.8],
    [x, z - 2.4]
  ];

  pathTiles.forEach(([pathX, pathZ]) => {
    const path = createVoxel(pathX, VOXEL_HALF * 0.3, pathZ, COLORS.stoneBase, 0.7);
    path.scale.set(0.8, 0.15, 0.8);
    scene.add(path);
  });
}
