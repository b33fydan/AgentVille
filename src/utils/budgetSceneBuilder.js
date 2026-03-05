import * as THREE from 'three';
import {
  BILL_CATEGORY_COLORS,
  COLORS,
  VOXEL_HALF,
  VOXEL_SIZE,
  createGroundVoxel,
  createMonster,
  createTree,
  createVoxel
} from './voxelBuilder.js';

const GROWTH_ANIMATION_MS = 500;
const GROUND_GRID_SIZE = 29;
const GROUND_HALF_SPAN = (GROUND_GRID_SIZE * VOXEL_SIZE) / 2;
const PLAYABLE_HALF_SPAN = GROUND_HALF_SPAN - VOXEL_SIZE * 1.5;
const ROCK_EDGE_MIN = GROUND_HALF_SPAN * 0.72;
const ROCK_EDGE_MAX = GROUND_HALF_SPAN * 0.95;
const ROCK_TANGENT_LIMIT = GROUND_HALF_SPAN * 0.82;
const FLOWER_SCATTER_LIMIT = GROUND_HALF_SPAN * 0.92;
const GRASS_VARIANTS = [COLORS.grassDark, COLORS.grassBase, COLORS.grassLight, COLORS.grassMoss];
const FLOWER_COLORS = ['#ef4444', '#fbbf24', '#ec4899', '#ffffff'];
const ROCK_COLORS = ['#9ca3af', '#6b7280'];

function worldFromGrid(index) {
  return -GROUND_HALF_SPAN + VOXEL_HALF + index * VOXEL_SIZE;
}

function isEdgeIndex(ix, iz) {
  return ix === 0 || iz === 0 || ix === GROUND_GRID_SIZE - 1 || iz === GROUND_GRID_SIZE - 1;
}

function randomBetween(min, max) {
  return min + Math.random() * (max - min);
}

function addGridVoxel(group, gx, gy, gz, color, size = 1, scale = null) {
  const voxel = createVoxel(gx * VOXEL_SIZE, VOXEL_HALF + gy * VOXEL_SIZE, gz * VOXEL_SIZE, color, size);
  if (Array.isArray(scale) && scale.length === 3) {
    voxel.scale.set(scale[0], scale[1], scale[2]);
  }
  group.add(voxel);
  return voxel;
}

function addGridPlate(group, gx, gy, gz, color, scale = [1, 0.5, 1]) {
  const plate = createVoxel(gx * VOXEL_SIZE, gy, gz * VOXEL_SIZE, color, 1);
  plate.scale.set(scale[0], scale[1], scale[2]);
  group.add(plate);
  return plate;
}

function createRockClusters(clusterCount = 4) {
  const rocks = new THREE.Group();

  for (let clusterIndex = 0; clusterIndex < clusterCount; clusterIndex += 1) {
    const edge = Math.floor(Math.random() * 4);
    const edgeDistance = randomBetween(ROCK_EDGE_MIN, ROCK_EDGE_MAX);
    const tangent = randomBetween(-ROCK_TANGENT_LIMIT, ROCK_TANGENT_LIMIT);

    let cx = tangent;
    let cz = tangent;

    if (edge === 0) {
      cx = edgeDistance;
      cz = tangent;
    } else if (edge === 1) {
      cx = -edgeDistance;
      cz = tangent;
    } else if (edge === 2) {
      cx = tangent;
      cz = edgeDistance;
    } else {
      cx = tangent;
      cz = -edgeDistance;
    }

    const rockPieces = 2 + Math.floor(Math.random() * 2);
    for (let piece = 0; piece < rockPieces; piece += 1) {
      const rock = createVoxel(
        cx + randomBetween(-0.18, 0.18),
        randomBetween(0.11, 0.2),
        cz + randomBetween(-0.18, 0.18),
        ROCK_COLORS[Math.floor(Math.random() * ROCK_COLORS.length)],
        0.5 + Math.random() * 0.15
      );
      rock.scale.set(1, 0.7 + Math.random() * 0.35, 1);
      rocks.add(rock);
    }
  }

  return rocks;
}

function createFlowerScatter(count = 10) {
  const flowers = new THREE.Group();
  const blockedZones = [
    { x: 3.24, z: -1.86, r: 1.5 },
    { x: 2.76, z: -0.84, r: 1.7 },
    { x: 3.54, z: 2.4, r: 1.8 }
  ];

  let placed = 0;
  let attempts = 0;

  while (placed < count && attempts < count * 25) {
    attempts += 1;
    const x = randomBetween(-FLOWER_SCATTER_LIMIT, FLOWER_SCATTER_LIMIT);
    const z = randomBetween(-FLOWER_SCATTER_LIMIT, FLOWER_SCATTER_LIMIT);

    const blocked = blockedZones.some((zone) => {
      const dx = x - zone.x;
      const dz = z - zone.z;
      return Math.sqrt(dx * dx + dz * dz) < zone.r;
    });

    if (blocked) {
      continue;
    }

    const flower = createVoxel(
      x,
      randomBetween(0.16, 0.24),
      z,
      FLOWER_COLORS[Math.floor(Math.random() * FLOWER_COLORS.length)],
      0.375
    );

    flowers.add(flower);
    placed += 1;
  }

  return flowers;
}

function createCloudCluster(x, y, z) {
  const cloud = new THREE.Group();
  const cubeCount = 6 + Math.floor(Math.random() * 5);

  for (let index = 0; index < cubeCount; index += 1) {
    const t = cubeCount <= 1 ? 0 : index / (cubeCount - 1);
    const offsetX = (t - 0.5) * 2.4 + randomBetween(-0.18, 0.18);
    const offsetY = randomBetween(-0.18, 0.18);
    const offsetZ = randomBetween(-0.42, 0.42);
    cloud.add(createVoxel(offsetX, offsetY, offsetZ, '#f8fbff', 1.25));
  }

  cloud.position.set(x, y, z);
  cloud.userData.cloudMotion = {
    originX: x,
    originY: y,
    originZ: z,
    amplitudeX: randomBetween(0.65, 1.15),
    amplitudeZ: randomBetween(0.15, 0.35),
    cycleSeconds: 20,
    phase: Math.random() * Math.PI * 2
  };

  return cloud;
}

function createUndersideLayer(group, footprintScale, yStart, yEnd, color, edgeDropChance = 0.2) {
  const min = -GROUND_HALF_SPAN * footprintScale;
  const max = GROUND_HALF_SPAN * footprintScale;

  for (let y = yStart; y >= yEnd; y -= VOXEL_HALF) {
    for (let x = min; x <= max; x += VOXEL_SIZE) {
      for (let z = min; z <= max; z += VOXEL_SIZE) {
        const edgeDistance = Math.max(Math.abs(x), Math.abs(z));
        const edgeThreshold = GROUND_HALF_SPAN * footprintScale - VOXEL_SIZE * 0.4;
        if (edgeDistance > edgeThreshold && Math.random() < edgeDropChance) {
          continue;
        }

        const voxel = createGroundVoxel(
          x + randomBetween(-0.03, 0.03),
          y + randomBetween(-0.04, 0.03),
          z + randomBetween(-0.03, 0.03),
          color
        );
        voxel.scale.set(0.92, 1, 0.92);
        group.add(voxel);
      }
    }
  }
}

function createFloatingUnderside() {
  const underside = new THREE.Group();

  createUndersideLayer(underside, 0.8, -0.2, -0.6, '#92400e', 0.12);
  createUndersideLayer(underside, 0.5, -0.6, -1.2, '#6b7280', 0.2);
  createUndersideLayer(underside, 0.2, -1.2, -1.8, '#4b5563', 0.32);

  for (let index = 0; index < 6; index += 1) {
    const spike = createVoxel(
      randomBetween(-0.65, 0.65),
      randomBetween(-1.55, -1.2),
      randomBetween(-0.65, 0.65),
      '#3f4853',
      0.6
    );
    spike.scale.set(0.55, 1.6 + Math.random() * 1.2, 0.55);
    underside.add(spike);
  }

  for (let index = 0; index < 2; index += 1) {
    const vine = createVoxel(randomBetween(-0.8, 0.8), randomBetween(-1.2, -0.9), randomBetween(-0.8, 0.8), '#3f8b42', 0.35);
    vine.scale.set(0.45, 1.8, 0.45);
    underside.add(vine);
  }

  return underside;
}

function createHut(x, z) {
  const hutGroup = new THREE.Group();
  const hut = new THREE.Group();
  const wallColor = '#d4a574';

  for (let gy = 0; gy < 4; gy += 1) {
    for (let gx = -2; gx <= 2; gx += 1) {
      for (let gz = -2; gz <= 2; gz += 1) {
        const isWall = gx === -2 || gx === 2 || gz === -2 || gz === 2;
        if (!isWall) {
          continue;
        }

        if (gz === 2 && gx === 0 && gy < 2) {
          continue;
        }

        if (gx === 2 && gz === 0 && gy === 2) {
          continue;
        }

        addGridVoxel(hut, gx, gy, gz, wallColor);
      }
    }
  }

  addGridVoxel(hut, 1, 2, 0, '#7dd3fc', 0.8);

  for (let layer = 0; layer < 3; layer += 1) {
    const half = 2 - layer;
    const roofColor = layer === 0 ? '#5f3a1f' : layer === 1 ? '#4a2f1a' : '#3f2615';
    const gy = 4 + layer;

    for (let gx = -half; gx <= half; gx += 1) {
      for (let gz = -half; gz <= half; gz += 1) {
        addGridVoxel(hut, gx, gy, gz, roofColor);
      }
    }
  }

  hutGroup.add(hut);
  hutGroup.scale.set(0.7, 0.7, 0.7);
  hutGroup.position.set(x, VOXEL_HALF, z);
  return hutGroup;
}

function createHouse(x, z) {
  const houseGroup = new THREE.Group();
  const house = new THREE.Group();

  for (let gy = 0; gy < 5; gy += 1) {
    for (let gx = -3; gx <= 3; gx += 1) {
      for (let gz = -3; gz <= 3; gz += 1) {
        const isWall = gx === -3 || gx === 3 || gz === -3 || gz === 3;
        if (!isWall) {
          continue;
        }

        if (gz === 3 && gx === 0 && gy < 2) {
          continue;
        }

        if ((gx === -2 || gx === 2) && gz === 3 && (gy === 2 || gy === 3)) {
          continue;
        }

        if ((gx === -3 || gx === 3) && gz === 0 && gy === 2) {
          continue;
        }

        addGridVoxel(house, gx, gy, gz, '#c89f72');
      }
    }
  }

  addGridVoxel(house, -2, 2, 2, '#8ed1ff', 0.75);
  addGridVoxel(house, 2, 2, 2, '#8ed1ff', 0.75);
  addGridVoxel(house, -2.8, 2, 0, '#8ed1ff', 0.7);
  addGridVoxel(house, 2.8, 2, 0, '#8ed1ff', 0.7);

  for (let layer = 0; layer < 3; layer += 1) {
    const half = 4 - layer;
    const gy = 5 + layer;
    const roofColor = layer === 0 ? '#5a2e1a' : layer === 1 ? '#6b3420' : '#7c3f29';

    for (let gx = -half; gx <= half; gx += 1) {
      for (let gz = -half; gz <= half; gz += 1) {
        addGridVoxel(house, gx, gy, gz, roofColor);
      }
    }
  }

  for (let gx = 2; gx <= 3; gx += 1) {
    for (let gz = -1; gz <= 0; gz += 1) {
      for (let gy = 6; gy <= 8; gy += 1) {
        addGridVoxel(house, gx, gy, gz, '#4b5563');
      }
    }
  }

  houseGroup.add(house);
  houseGroup.scale.set(0.7, 0.7, 0.7);
  houseGroup.position.set(x, VOXEL_HALF, z);
  return houseGroup;
}

function createTower(x, z, bannerColor = COLORS.gold) {
  const tower = new THREE.Group();
  const coords = [-2.5, -1.5, -0.5, 0.5, 1.5, 2.5];

  for (let gy = 0; gy < 8; gy += 1) {
    coords.forEach((gx) => {
      coords.forEach((gz) => {
        const isWall = gx === -2.5 || gx === 2.5 || gz === -2.5 || gz === 2.5;
        if (!isWall) {
          return;
        }

        const isWindow = (gx === 2.5 && gz === 0.5 && (gy === 2 || gy === 3)) ||
          (gz === -2.5 && gx === -0.5 && (gy === 4 || gy === 5));

        if (!isWindow) {
          addGridVoxel(tower, gx, gy, gz, '#9ca3af');
        }
      });
    });
  }

  coords.forEach((gx, ix) => {
    coords.forEach((gz, iz) => {
      const isPerimeter = gx === -2.5 || gx === 2.5 || gz === -2.5 || gz === 2.5;
      if (!isPerimeter) {
        return;
      }
      if ((ix + iz) % 2 === 0) {
        addGridVoxel(tower, gx, 8, gz, '#d1d5db');
      }
    });
  });

  for (let layer = 0; layer < 3; layer += 1) {
    const half = 2 - layer;
    for (let gx = -half; gx <= half; gx += 1) {
      for (let gz = -half; gz <= half; gz += 1) {
        addGridVoxel(tower, gx, 9 + layer, gz, layer === 2 ? '#7f1d1d' : '#8b5e3c');
      }
    }
  }

  for (let gy = 12; gy < 16; gy += 1) {
    addGridVoxel(tower, 0.2, gy * 0.45, 0, '#374151', 0.35, [0.45, 1, 0.45]);
  }

  for (let gx = 1; gx <= 2; gx += 1) {
    for (let gy = 13; gy <= 15; gy += 1) {
      addGridVoxel(tower, gx * 0.55, gy * 0.45, 0, bannerColor, 0.45, [1, 0.9, 0.35]);
    }
  }

  for (let index = 0; index < 3; index += 1) {
    addGridVoxel(
      tower,
      randomBetween(-2.3, 2.3),
      randomBetween(1.4, 6.2),
      2.52,
      ['#2f7d32', '#3ea542', '#52aa57'][Math.floor(Math.random() * 3)],
      0.5
    );
  }

  const towerGroup = new THREE.Group();
  towerGroup.add(tower);
  towerGroup.scale.set(0.7, 0.7, 0.7);
  towerGroup.position.set(x, VOXEL_HALF, z);
  return towerGroup;
}

function createCastle(x, z) {
  const castle = new THREE.Group();
  const mainCoords = [-3.5, -2.5, -1.5, -0.5, 0.5, 1.5, 2.5, 3.5];

  for (let gy = 0; gy < 10; gy += 1) {
    mainCoords.forEach((gx) => {
      mainCoords.forEach((gz) => {
        const isWall = gx === -3.5 || gx === 3.5 || gz === -3.5 || gz === 3.5;
        if (!isWall) {
          return;
        }

        const isGate = gz === 3.5 && Math.abs(gx) <= 1.5 && gy < 4;
        if (!isGate) {
          addGridVoxel(castle, gx, gy, gz, '#9aa3b2');
        }
      });
    });
  }

  const sideCoords = [-1.5, -0.5, 0.5, 1.5];
  for (let gy = 0; gy < 7; gy += 1) {
    sideCoords.forEach((gx) => {
      sideCoords.forEach((gz) => {
        const isWall = gx === -1.5 || gx === 1.5 || gz === -1.5 || gz === 1.5;
        if (isWall) {
          addGridVoxel(castle, gx + 6, gy, gz - 1, '#868e9c');
        }
      });
    });
  }

  for (let gx = 2; gx <= 6; gx += 1) {
    for (let gy = 0; gy < 3; gy += 1) {
      addGridVoxel(castle, gx, gy, -1, '#7d8793');
    }
  }

  addGridVoxel(castle, -2.4, 4.2, 3.8, '#f97316', 0.55);
  addGridVoxel(castle, -2.1, 4.2, 3.95, '#facc15', 0.35);
  addGridVoxel(castle, 2.4, 4.2, 3.8, '#f97316', 0.55);
  addGridVoxel(castle, 2.1, 4.2, 3.95, '#facc15', 0.35);

  for (let gx = -3.5; gx <= 3.5; gx += 1) {
    if (Math.abs(gx) <= 1.5) {
      continue;
    }
    addGridVoxel(castle, gx, 10, -3.5, '#cbd5e1');
    addGridVoxel(castle, gx, 10, 3.5, '#cbd5e1');
  }

  const castleGroup = new THREE.Group();
  castleGroup.add(castle);
  castleGroup.scale.set(0.7, 0.7, 0.7);
  castleGroup.position.set(x, VOXEL_HALF, z);
  return castleGroup;
}

function buildStage0() {
  return [
    createTree(-4.08, 3.96, 'dead'),
    createTree(4.26, 3.78, 'dead'),
    createTree(-3.9, -3.84, 'dead'),
    createTree(4.08, -3.96, 'dead'),
    createRockClusters(5)
  ];
}

function buildStage1() {
  return [
    createTree(-3.42, 3.12, 'pine'),
    createTree(3.54, 3.24, 'oak'),
    createTree(-3.12, -2.88, 'pine'),
    createTree(3.3, -2.64, 'bush'),
    createTree(-1.38, 4.2, 'pine'),
    createTree(1.68, -4.08, 'oak'),
    createFlowerScatter(14)
  ];
}

function buildStage2() {
  const hut = createHut(3.24, -1.86);
  hut.userData.stageSlot = 'main-structure';

  return [
    hut,
    createTree(-4.26, 3.9, 'oak'),
    createTree(4.44, 3.6, 'pine'),
    createTree(-4.02, -3.72, 'pine'),
    createTree(4.38, -4.08, 'oak'),
    createTree(-1.56, 0.96, 'bush')
  ];
}

function buildStage3() {
  const house = createHouse(3.3, -1.8);
  house.userData.stageSlot = 'main-structure';

  return [
    house,
    createTree(-4.32, 3.42, 'oak'),
    createTree(4.08, 3.96, 'pine'),
    createTree(-3.66, -3.36, 'oak'),
    createTree(4.5, -3.24, 'bush'),
    createTree(-0.84, -4.2, 'pine')
  ];
}

function buildStage4() {
  return [
    createTree(-4.44, 4.08, 'pine'),
    createTree(4.32, 4.2, 'oak'),
    createTree(-4.14, -4.08, 'oak'),
    createTree(4.2, -4.2, 'pine'),
    createTree(-2.16, 3.3, 'bush'),
    createTree(2.52, -3.18, 'oak')
  ];
}

function buildStage5() {
  const tower = createTower(3.6, -1.92);
  tower.userData.stageSlot = 'main-structure';

  return [
    tower,
    createCloudCluster(-3.84, 6.4, -1.26),
    createCloudCluster(0.6, 7.1, 3.18),
    createCloudCluster(3.9, 6.7, -2.82),
    createTree(-4.2, 3.9, 'pine'),
    createTree(4.5, 3.48, 'oak'),
    createTree(-4.44, -3.78, 'oak'),
    createTree(4.56, -3.9, 'pine'),
    createTree(-1.2, 4.38, 'bush'),
    createTree(1.38, -4.32, 'oak')
  ];
}

function buildStage6() {
  const castle = createCastle(2.4, -0.84);
  castle.userData.stageSlot = 'main-structure';

  return [
    castle,
    createTree(-4.56, 4.02, 'pine'),
    createTree(4.5, 4.2, 'oak'),
    createTree(-4.5, -4.2, 'oak'),
    createTree(4.62, -4.08, 'pine'),
    createTree(-2.82, 3.24, 'oak'),
    createTree(2.94, -3.18, 'oak'),
    createTree(-0.42, -4.5, 'bush'),
    createTree(1.02, 4.44, 'pine')
  ];
}

const STAGE_BUILDERS = [buildStage0, buildStage1, buildStage2, buildStage3, buildStage4, buildStage5, buildStage6];

export function buildGroundPlatform(parent) {
  const terrain = new THREE.Group();
  terrain.userData.type = 'terrain-base';

  const tileGeometry = new THREE.BoxGeometry(VOXEL_SIZE, VOXEL_HALF, VOXEL_SIZE);
  const tileMaterial = new THREE.MeshStandardMaterial({
    roughness: 0.95,
    metalness: 0.03,
    vertexColors: true
  });

  const count = GROUND_GRID_SIZE * GROUND_GRID_SIZE;
  const topTiles = new THREE.InstancedMesh(tileGeometry, tileMaterial, count);
  topTiles.castShadow = true;
  topTiles.receiveShadow = true;

  const matrixHelper = new THREE.Object3D();
  let index = 0;

  for (let ix = 0; ix < GROUND_GRID_SIZE; ix += 1) {
    for (let iz = 0; iz < GROUND_GRID_SIZE; iz += 1) {
      const x = worldFromGrid(ix);
      const z = worldFromGrid(iz);
      const jitterY = Math.random() * 0.08;

      matrixHelper.position.set(x, jitterY, z);
      matrixHelper.rotation.set(0, randomBetween(-0.03, 0.03), 0);
      matrixHelper.scale.set(1, 1, 1);
      matrixHelper.updateMatrix();

      topTiles.setMatrixAt(index, matrixHelper.matrix);
      topTiles.setColorAt(index, new THREE.Color(GRASS_VARIANTS[Math.floor(Math.random() * GRASS_VARIANTS.length)]));
      index += 1;

      if (isEdgeIndex(ix, iz)) {
        terrain.add(createGroundVoxel(x, -0.2, z, '#4b7335'));
        terrain.add(createGroundVoxel(x, -0.4, z, '#92400e'));
        terrain.add(createGroundVoxel(x, -0.6, z, '#6b7280'));
      }
    }
  }

  topTiles.instanceMatrix.needsUpdate = true;
  if (topTiles.instanceColor) {
    topTiles.instanceColor.needsUpdate = true;
  }

  terrain.add(topTiles);
  terrain.add(createFloatingUnderside());

  if (parent) {
    parent.add(terrain);
  }

  return terrain;
}

export function getMonsterScale(amount) {
  if (amount < 100) {
    return 0.5;
  }

  if (amount < 500) {
    return 0.7;
  }

  return 1;
}

export function getIncomeScale(income) {
  const normalized = 0.35 + ((income - 1000) * 1.1) / 4000;
  return Math.min(1.35, Math.max(0.28, normalized));
}

export function disposeObject3D(object) {
  object.traverse((node) => {
    if (node instanceof THREE.Mesh || node instanceof THREE.InstancedMesh) {
      node.geometry?.dispose();

      if (Array.isArray(node.material)) {
        node.material.forEach((material) => material?.dispose?.());
      } else {
        node.material?.dispose?.();
      }
    }
  });
}

export function clearGroup(group) {
  while (group.children.length > 0) {
    const child = group.children[0];
    group.remove(child);
    disposeObject3D(child);
  }
}

function easeOutCubic(t) {
  return 1 - (1 - t) ** 3;
}

function markGrowthObject(object) {
  object.scale.setScalar(0.001);
  object.userData.growthAnimation = {
    start: performance.now(),
    duration: GROWTH_ANIMATION_MS,
    complete: false
  };

  return object;
}

function createQuestionBlock() {
  const questionGroup = new THREE.Group();
  const base = createVoxel(0, VOXEL_HALF, 0, COLORS.stoneBase, 1.2);
  const accent = COLORS.silver;

  const marks = [
    createVoxel(-0.08, 0.35, 0.24, accent, 0.3),
    createVoxel(0.04, 0.35, 0.24, accent, 0.3),
    createVoxel(0.12, 0.23, 0.24, accent, 0.3),
    createVoxel(0.04, 0.11, 0.24, accent, 0.3),
    createVoxel(0.04, -0.03, 0.24, accent, 0.3)
  ];

  questionGroup.add(base, ...marks);
  questionGroup.userData.type = 'empty-state';
  questionGroup.position.y = VOXEL_HALF;
  return questionGroup;
}

function createIncomePile(income) {
  const scale = getIncomeScale(income);
  const pile = new THREE.Group();
  const baseSize = 0.9 * scale;
  const topSize = 0.65 * scale;

  const baseVoxels = [
    createVoxel(-VOXEL_SIZE * 1.1 * scale, VOXEL_HALF, -VOXEL_SIZE * 0.6 * scale, COLORS.gold, baseSize),
    createVoxel(0, VOXEL_HALF, -VOXEL_SIZE * 0.6 * scale, COLORS.goldLight, baseSize),
    createVoxel(VOXEL_SIZE * 1.1 * scale, VOXEL_HALF, -VOXEL_SIZE * 0.6 * scale, COLORS.gold, baseSize),
    createVoxel(-VOXEL_SIZE * 0.6 * scale, VOXEL_HALF, VOXEL_SIZE * 0.55 * scale, COLORS.goldLight, baseSize),
    createVoxel(VOXEL_SIZE * 0.6 * scale, VOXEL_HALF, VOXEL_SIZE * 0.55 * scale, COLORS.gold, baseSize)
  ];

  const topVoxels = [
    createVoxel(-VOXEL_SIZE * 0.25 * scale, VOXEL_SIZE * 0.6 * scale, 0, COLORS.goldLight, topSize),
    createVoxel(VOXEL_SIZE * 0.25 * scale, VOXEL_SIZE * 0.55 * scale, -VOXEL_SIZE * 0.1 * scale, COLORS.gold, topSize)
  ];

  pile.add(...baseVoxels, ...topVoxels);
  pile.position.set(0, VOXEL_HALF, 0);
  pile.userData.type = 'income-pile';
  pile.userData.scale = Number(scale.toFixed(2));

  return pile;
}

export function buildDynamicEntities(group, bills, income, options = {}) {
  const safeStage = Math.max(0, Math.min(6, Math.floor(Number(options?.islandStage) || 0)));

  if (bills.length === 0) {
    group.add(createQuestionBlock());
  } else {
    const sparseRadius = PLAYABLE_HALF_SPAN * 0.95;
    const mediumRadius = PLAYABLE_HALF_SPAN * 1.02;
    const denseRadius = PLAYABLE_HALF_SPAN * 1.08;
    const baseRadius = bills.length > 8 ? denseRadius : bills.length > 4 ? mediumRadius : sparseRadius;
    const radius = Math.min(PLAYABLE_HALF_SPAN * 1.2, baseRadius + safeStage * 0.2);
    const startAngle = Math.PI * 0.08;
    const endAngle = Math.PI * 0.92;
    const zOffset = Math.min(1.95, 1.22 + safeStage * 0.12);

    bills.forEach((bill, index) => {
      const t = bills.length === 1 ? 0.5 : index / (bills.length - 1);
      const angle = startAngle + (endAngle - startAngle) * t;
      const x = Math.cos(angle) * radius;
      const z = Math.sin(angle) * radius - zOffset;
      const size = getMonsterScale(Number(bill.amount || 0));
      const category = String(bill.category || 'other');
      const color = BILL_CATEGORY_COLORS[category] ?? BILL_CATEGORY_COLORS.other;
      const monster = createMonster(x, z, color, size, category);

      monster.userData.type = 'bill-monster';
      monster.userData.name = bill.name;
      monster.userData.amount = Number(bill.amount || 0);
      monster.userData.category = category;
      monster.userData.scale = size;
      monster.userData.color = color;

      group.add(monster);
    });
  }

  group.add(createIncomePile(income));
}

export function updateDynamicEntityAnimations(group, nowMs) {
  const time = nowMs * 0.001;

  group.children.forEach((child) => {
    if (child.userData?.type !== 'bill-monster') {
      return;
    }

    const bobAmplitude = child.userData?.idleBobAmplitude ?? 0.1;
    const bobSpeed = child.userData?.idleBobSpeed ?? 1.8;
    const bobPhase = child.userData?.idleBobPhase ?? 0;
    const baseY = child.userData?.baseY ?? VOXEL_HALF;
    child.position.y = baseY + Math.sin(time * bobSpeed + bobPhase) * bobAmplitude;

    const orbiters = child.userData?.orbiters;
    if (Array.isArray(orbiters) && orbiters.length > 0) {
      orbiters.forEach((orbiter, index) => {
        const orbitAngle = time * 1.4 + (orbiter.userData?.orbitAngle ?? index);
        const orbitRadius = orbiter.userData?.orbitRadius ?? VOXEL_SIZE * 0.55;
        const orbitHeight = orbiter.userData?.orbitHeight ?? VOXEL_SIZE * 1.2;
        orbiter.position.x = Math.cos(orbitAngle) * orbitRadius;
        orbiter.position.z = Math.sin(orbitAngle) * orbitRadius;
        orbiter.position.y = orbitHeight + Math.sin(orbitAngle * 1.6) * VOXEL_SIZE * 0.08;
      });
    }
  });
}

export function buildIslandStage(group, stage) {
  if (!group.userData.builtStages) {
    group.userData.builtStages = new Set();
  }
  if (!group.userData.activeStageSlots) {
    group.userData.activeStageSlots = new Map();
  }

  const builtStages = group.userData.builtStages;
  const activeStageSlots = group.userData.activeStageSlots;
  const safeStage = Math.max(0, Math.min(6, Math.floor(stage)));
  const addedObjects = [];

  for (let current = 0; current <= safeStage; current += 1) {
    if (builtStages.has(current)) {
      continue;
    }

    const objects = STAGE_BUILDERS[current]?.() ?? [];
    objects.forEach((object) => {
      const slotKey = object.userData?.stageSlot;
      if (slotKey) {
        const previousObject = activeStageSlots.get(slotKey);
        if (previousObject && previousObject !== object) {
          group.remove(previousObject);
          disposeObject3D(previousObject);
        }
      }

      if (!object.userData.growthAnimation) {
        markGrowthObject(object);
      }

      object.userData.islandStage = current;
      group.add(object);
      if (slotKey) {
        activeStageSlots.set(slotKey, object);
      }
      addedObjects.push(object);
    });

    builtStages.add(current);
  }

  return addedObjects;
}

export function updateIslandGrowthAnimations(group, nowMs) {
  group.traverse((object) => {
    const growthAnimation = object.userData?.growthAnimation;
    if (growthAnimation && !growthAnimation.complete) {
      const elapsed = nowMs - growthAnimation.start;
      const t = Math.max(0, Math.min(1, elapsed / growthAnimation.duration));
      const eased = easeOutCubic(t);
      object.scale.setScalar(Math.max(0.001, eased));

      if (t >= 1) {
        growthAnimation.complete = true;
      }
    }

    const cloudMotion = object.userData?.cloudMotion;
    if (cloudMotion) {
      const base = (nowMs / 1000) * ((Math.PI * 2) / cloudMotion.cycleSeconds) + cloudMotion.phase;
      object.position.x = cloudMotion.originX + Math.sin(base) * cloudMotion.amplitudeX;
      object.position.z = cloudMotion.originZ + Math.cos(base * 0.9) * cloudMotion.amplitudeZ;
      object.position.y = cloudMotion.originY + Math.sin(base * 0.5) * 0.12;
    }
  });
}
