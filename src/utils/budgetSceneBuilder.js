import * as THREE from 'three';
import { BILL_CATEGORY_COLORS, COLORS, createBuilding, createMonster, createTree, createVoxel } from './voxelBuilder.js';

const GROWTH_ANIMATION_MS = 500;

export function getMonsterScale(amount) {
  if (amount < 100) {
    return 0.7;
  }

  if (amount <= 500) {
    return 1;
  }

  return 1.3;
}

export function getIncomeScale(income) {
  const normalized = 0.5 + ((income - 1000) * 1.5) / 4000;
  return Math.min(2, Math.max(0.3, normalized));
}

export function disposeObject3D(object) {
  object.traverse((node) => {
    if (!(node instanceof THREE.Mesh)) {
      return;
    }

    node.geometry?.dispose();

    if (Array.isArray(node.material)) {
      node.material.forEach((material) => material.dispose());
      return;
    }

    node.material?.dispose();
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

function markGrowthObject(object, options = {}) {
  object.scale.setScalar(0.001);
  object.userData.growthAnimation = {
    start: performance.now(),
    duration: GROWTH_ANIMATION_MS,
    complete: false
  };

  if (options.cloudMotion) {
    object.userData.cloudMotion = {
      originX: object.position.x,
      originY: object.position.y,
      originZ: object.position.z,
      amplitudeX: options.cloudMotion.amplitudeX,
      amplitudeZ: options.cloudMotion.amplitudeZ,
      speed: options.cloudMotion.speed,
      phase: Math.random() * Math.PI * 2
    };
  }

  return object;
}

function createFlower(x, z, petalColor) {
  const flower = new THREE.Group();
  const stem = createVoxel(0, 0.25, 0, '#3f8b42', 0.16);
  stem.scale.y = 2.2;

  flower.add(stem);
  flower.add(createVoxel(0, 0.62, 0, petalColor, 0.2));
  flower.position.set(x, 0.5, z);
  return flower;
}

function createDeadTree(x, z) {
  const deadTree = new THREE.Group();
  const trunk = createVoxel(0, 0.8, 0, '#6a6a6a', 0.4);
  trunk.scale.y = 2.8;
  const branchA = createVoxel(0.28, 1.7, 0, '#7f7f7f', 0.22);
  branchA.rotation.z = Math.PI * 0.22;
  const branchB = createVoxel(-0.22, 1.45, 0.08, '#777777', 0.2);
  branchB.rotation.z = -Math.PI * 0.3;

  deadTree.add(trunk, branchA, branchB);
  deadTree.position.set(x, 0.45, z);
  return deadTree;
}

function createHut(x, z) {
  const hut = new THREE.Group();
  const body = createBuilding(0, 0, 2.2, 2, 2.2, COLORS.woodBase);
  const roof = createVoxel(0, 2.25, 0, COLORS.woodDark, 2.25);
  roof.scale.y = 0.5;
  const door = createVoxel(0, 0.85, 1.05, COLORS.woodDark, 0.6);
  door.scale.y = 1.2;

  hut.add(body, roof, door);
  hut.position.set(x, 0.5, z);
  return hut;
}

function createHouseUpgrade(x, z) {
  const house = new THREE.Group();
  const lower = createBuilding(0, 0, 3, 2, 2.8, COLORS.woodLight);
  const upper = createBuilding(0, 0, 2.4, 2, 2.2, COLORS.stoneLight);
  upper.position.y = 1.9;

  const roofLeft = createVoxel(-0.45, 4.15, 0, '#7f2a2a', 1.2);
  roofLeft.scale.set(1, 0.5, 2.4);
  roofLeft.rotation.z = Math.PI * 0.1;

  const roofRight = createVoxel(0.45, 4.15, 0, '#8e3131', 1.2);
  roofRight.scale.set(1, 0.5, 2.4);
  roofRight.rotation.z = -Math.PI * 0.1;

  house.add(lower, upper, roofLeft, roofRight);
  house.position.set(x, 0.5, z);
  return house;
}

function createWell(x, z) {
  const well = new THREE.Group();

  [-0.45, 0, 0.45].forEach((offset) => {
    well.add(createVoxel(offset, 0.28, -0.45, COLORS.stoneBase, 0.35));
    well.add(createVoxel(offset, 0.28, 0.45, COLORS.stoneBase, 0.35));
    well.add(createVoxel(-0.45, 0.28, offset, COLORS.stoneBase, 0.35));
    well.add(createVoxel(0.45, 0.28, offset, COLORS.stoneBase, 0.35));
  });

  const postLeft = createVoxel(-0.45, 1.15, -0.45, COLORS.woodBase, 0.2);
  postLeft.scale.y = 3;
  const postRight = createVoxel(0.45, 1.15, -0.45, COLORS.woodBase, 0.2);
  postRight.scale.y = 3;
  const roof = createVoxel(0, 2.15, -0.45, COLORS.woodDark, 1.2);
  roof.scale.set(1.1, 0.4, 1.2);

  const water = createVoxel(0, 0.18, 0, COLORS.waterShallow, 0.7);
  water.scale.y = 0.25;

  well.add(postLeft, postRight, roof, water);
  well.position.set(x, 0.5, z);
  return well;
}

function createGardenBed(x, z) {
  const bed = new THREE.Group();
  const soil = createVoxel(0, 0.05, 0, '#5f3f24', 0.9);
  soil.scale.y = 0.3;
  const cropA = createVoxel(-0.2, 0.35, 0.1, COLORS.leafBase, 0.25);
  const cropB = createVoxel(0.2, 0.35, -0.1, COLORS.leafLight, 0.25);

  bed.add(soil, cropA, cropB);
  bed.position.set(x, 0.5, z);
  return bed;
}

function createPond(x, z) {
  const pond = new THREE.Group();
  const rim = createVoxel(0, 0.06, 0, COLORS.stoneDark, 1.8);
  rim.scale.y = 0.3;
  const water = createVoxel(0, 0.01, 0, COLORS.waterBase, 1.5);
  water.scale.y = 0.1;

  pond.add(rim, water);
  pond.position.set(x, 0.5, z);
  return pond;
}

function createFenceSegment(x, z, rotation = 0) {
  const fence = new THREE.Group();
  for (let index = -1; index <= 1; index += 1) {
    const post = createVoxel(index * 0.35, 0.4, 0, COLORS.woodBase, 0.16);
    post.scale.y = 2.6;
    fence.add(post);
  }

  const railA = createVoxel(0, 0.56, 0, COLORS.woodLight, 0.95);
  railA.scale.set(1, 0.2, 0.3);
  const railB = createVoxel(0, 0.9, 0, COLORS.woodLight, 0.95);
  railB.scale.set(1, 0.2, 0.3);

  fence.add(railA, railB);
  fence.position.set(x, 0.5, z);
  fence.rotation.y = rotation;
  return fence;
}

function createStonePath(points) {
  const path = new THREE.Group();
  points.forEach(([x, z], index) => {
    const stone = createVoxel(x, 0.54, z, index % 2 === 0 ? COLORS.stoneLight : COLORS.stoneBase, 0.45);
    stone.scale.y = 0.18;
    path.add(stone);
  });
  return path;
}

function createBridge(x, z) {
  const bridge = new THREE.Group();
  for (let index = -2; index <= 2; index += 1) {
    const plank = createVoxel(index * 0.28, 0.18, 0, COLORS.woodLight, 0.25);
    plank.scale.set(0.9, 0.3, 1.8);
    bridge.add(plank);
  }

  const railLeft = createVoxel(0, 0.52, -0.7, COLORS.woodDark, 1.55);
  railLeft.scale.set(1, 0.2, 0.15);
  const railRight = createVoxel(0, 0.52, 0.7, COLORS.woodDark, 1.55);
  railRight.scale.set(1, 0.2, 0.15);

  bridge.add(railLeft, railRight);
  bridge.position.set(x, 0.5, z);
  bridge.rotation.y = Math.PI / 2;
  return bridge;
}

function createCastleTower(x, z) {
  const tower = new THREE.Group();
  const base = createBuilding(0, 0, 2.5, 6, 2.5, COLORS.stoneBase);
  const battlementOffsets = [
    [-0.85, 6.2, -0.85],
    [0, 6.2, -0.85],
    [0.85, 6.2, -0.85],
    [-0.85, 6.2, 0.85],
    [0, 6.2, 0.85],
    [0.85, 6.2, 0.85],
    [-0.85, 6.2, 0],
    [0.85, 6.2, 0]
  ];

  battlementOffsets.forEach(([bx, by, bz]) => {
    tower.add(createVoxel(bx, by, bz, COLORS.stoneLight, 0.5));
  });

  tower.add(base);
  tower.position.set(x, 0.5, z);
  return tower;
}

function createFlag(x, z, poleHeight = 3.5, color = COLORS.gold) {
  const flag = new THREE.Group();
  const pole = createVoxel(0, poleHeight * 0.5, 0, COLORS.stoneDark, 0.12);
  pole.scale.y = poleHeight;
  const cloth = createVoxel(0.32, poleHeight - 0.25, 0, color, 0.28);
  cloth.scale.set(1.6, 0.6, 0.2);
  flag.add(pole, cloth);
  flag.position.set(x, 0.5, z);
  return flag;
}

function createWallSection(x, z, length = 2.4, rotation = 0) {
  const wall = new THREE.Group();
  const count = Math.max(2, Math.floor(length / 0.42));

  for (let index = 0; index < count; index += 1) {
    const offset = (index - (count - 1) / 2) * 0.42;
    const block = createVoxel(offset, 0.55, 0, COLORS.stoneBase, 0.38);
    block.scale.y = 2.4;
    wall.add(block);
  }

  wall.position.set(x, 0.5, z);
  wall.rotation.y = rotation;
  return wall;
}

function createFountain(x, z) {
  const fountain = new THREE.Group();
  const basin = createVoxel(0, 0.2, 0, '#d9dee8', 1.4);
  basin.scale.y = 0.4;
  const pillar = createVoxel(0, 0.9, 0, '#e4e9f2', 0.45);
  pillar.scale.y = 2.2;
  const waterTop = createVoxel(0, 1.65, 0, COLORS.waterShallow, 0.35);
  const waterPool = createVoxel(0, 0.28, 0, COLORS.waterBase, 1.05);
  waterPool.scale.y = 0.16;

  fountain.add(basin, pillar, waterTop, waterPool);
  fountain.position.set(x, 0.5, z);
  return fountain;
}

function createSmithy(x, z) {
  const smithy = new THREE.Group();
  const body = createBuilding(0, 0, 2, 2, 1.8, COLORS.stoneDark);
  const roof = createVoxel(0, 2.2, 0, '#5a2e1a', 2.1);
  roof.scale.y = 0.45;
  const chimney = createVoxel(0.75, 2.75, -0.4, COLORS.stoneBase, 0.35);
  chimney.scale.y = 1.4;

  smithy.add(body, roof, chimney);
  smithy.position.set(x, 0.5, z);
  return smithy;
}

function createMarketStall(x, z, awningColor) {
  const stall = new THREE.Group();
  const base = createVoxel(0, 0.2, 0, COLORS.woodBase, 1.1);
  base.scale.y = 0.4;

  [-0.4, 0.4].forEach((px) => {
    [-0.4, 0.4].forEach((pz) => {
      const post = createVoxel(px, 0.62, pz, COLORS.woodDark, 0.12);
      post.scale.y = 2.8;
      stall.add(post);
    });
  });

  const awning = createVoxel(0, 1.35, 0, awningColor, 1.25);
  awning.scale.y = 0.22;

  stall.add(base, awning);
  stall.position.set(x, 0.5, z);
  return stall;
}

function createCloud(x, y, z) {
  const cloud = new THREE.Group();
  cloud.add(createVoxel(-0.42, 0, 0, '#f5f7fb', 0.7));
  cloud.add(createVoxel(0.16, 0.08, 0.08, '#ffffff', 0.82));
  cloud.add(createVoxel(0.6, 0, -0.06, '#f0f4fa', 0.62));
  cloud.position.set(x, y, z);
  return cloud;
}

function buildStage0() {
  return [createDeadTree(-2.9, -2.7)];
}

function buildStage1() {
  const objects = [
    createTree(-2.2, 2.7, 'pine'),
    createTree(2.8, 2.35, 'pine'),
    createTree(-3.1, 0.5, 'pine')
  ];

  const flowers = [
    [-0.8, 2.3, '#facc15'],
    [-0.3, 2.7, '#ec4899'],
    [0.2, 2.35, '#ef4444'],
    [2.4, 0.4, '#f59e0b'],
    [1.8, -0.2, '#f43f5e'],
    [-1.7, 1.1, '#fb7185']
  ];

  flowers.forEach(([x, z, color]) => {
    objects.push(createFlower(x, z, color));
  });

  return objects;
}

function buildStage2() {
  return [
    createHut(2.15, -1.1),
    createTree(-0.9, 3.05, 'oak'),
    createTree(3.15, 0.2, 'oak'),
    createStonePath([
      [0, -0.2],
      [0.45, -0.38],
      [0.95, -0.56],
      [1.45, -0.74],
      [1.95, -0.9]
    ])
  ];
}

function buildStage3() {
  const objects = [
    createHouseUpgrade(2.15, -1.1),
    createWell(-1.15, 1.2),
    createGardenBed(-0.4, 2.05),
    createGardenBed(0.25, 2.2),
    createGardenBed(-1.0, 2.35)
  ];

  [
    [-1.55, 2.85, '#fde047'],
    [0.95, 2.7, '#f472b6'],
    [1.6, 2.35, '#fb7185']
  ].forEach(([x, z, color]) => {
    objects.push(createFlower(x, z, color));
  });

  return objects;
}

function buildStage4() {
  const objects = [
    createBuilding(-2.25, -1.45, 2.6, 3, 2, COLORS.stoneDark),
    createPond(2.6, 1.85),
    createStonePath([
      [-1.2, -1.0],
      [-0.6, -0.95],
      [0, -0.9],
      [0.8, -0.95],
      [1.45, -1.0],
      [2.0, -1.05]
    ])
  ];

  const fenceSegments = [
    createFenceSegment(-3.2, -2.45, 0),
    createFenceSegment(-1.7, -2.45, 0),
    createFenceSegment(0, -2.45, 0),
    createFenceSegment(1.7, -2.45, 0),
    createFenceSegment(3.2, -2.45, 0),
    createFenceSegment(-3.45, -1.1, Math.PI / 2),
    createFenceSegment(-3.45, 0.45, Math.PI / 2),
    createFenceSegment(-3.45, 2.0, Math.PI / 2)
  ];

  objects.push(...fenceSegments);
  return objects;
}

function buildStage5() {
  const objects = [
    createCastleTower(2.2, -1.1),
    createFlag(3.08, -1.95, 5.2, COLORS.gold),
    createBridge(2.45, 1.25),
    createGardenBed(-0.2, 2.55),
    createGardenBed(0.55, 2.65),
    createGardenBed(1.3, 2.5),
    createWallSection(-2.7, -2.95, 2.2, 0),
    createWallSection(-0.1, -2.95, 2.2, 0),
    createWallSection(2.5, -2.95, 2.2, 0),
    createWallSection(3.55, -0.65, 2.3, Math.PI / 2),
    createWallSection(3.55, 1.7, 2.3, Math.PI / 2)
  ];

  return objects;
}

function buildStage6() {
  const objects = [
    createBuilding(1.55, -0.45, 3.2, 4, 3, COLORS.stoneBase),
    createWallSection(-3.05, 3.15, 2.1, 0),
    createWallSection(-0.45, 3.15, 2.1, 0),
    createWallSection(2.15, 3.15, 2.1, 0),
    createWallSection(-3.65, 0.9, 2.1, Math.PI / 2),
    createWallSection(-3.65, -1.55, 2.1, Math.PI / 2),
    createWallSection(3.65, -3.15, 1.8, 0),
    createFountain(0.05, 0.55),
    createSmithy(-1.95, -0.25),
    createMarketStall(-0.85, -1.55, '#f97316'),
    createMarketStall(-0.05, -1.55, '#facc15'),
    createFlag(-2.2, -0.25, 3.8, '#fbbf24'),
    createFlag(2.75, 2.85, 3.2, '#f59e0b')
  ];

  [
    [-2.8, 2.9, 'pine'],
    [-2.2, 2.55, 'pine'],
    [-1.6, 2.9, 'oak'],
    [-1.0, 2.55, 'oak']
  ].forEach(([x, z, style]) => {
    objects.push(createTree(x, z, style));
  });

  const gate = new THREE.Group();
  gate.add(createWallSection(1.1, -3.2, 1.4, 0));
  const archLeft = createVoxel(0.55, 1.05, -3.2, COLORS.stoneDark, 0.45);
  archLeft.scale.y = 2.4;
  const archRight = createVoxel(1.65, 1.05, -3.2, COLORS.stoneDark, 0.45);
  archRight.scale.y = 2.4;
  const archTop = createVoxel(1.1, 2.15, -3.2, COLORS.stoneLight, 1.35);
  archTop.scale.y = 0.35;
  gate.add(archLeft, archRight, archTop);
  objects.push(gate);

  const clouds = [
    createCloud(-2.4, 6.8, -0.8),
    createCloud(0.3, 7.2, 2.5),
    createCloud(2.75, 6.5, -1.9)
  ];

  clouds.forEach((cloud) => {
    objects.push(markGrowthObject(cloud, {
      cloudMotion: {
        amplitudeX: 0.35 + Math.random() * 0.25,
        amplitudeZ: 0.2 + Math.random() * 0.15,
        speed: 0.35 + Math.random() * 0.25
      }
    }));
  });

  return objects;
}

const STAGE_BUILDERS = [buildStage0, buildStage1, buildStage2, buildStage3, buildStage4, buildStage5, buildStage6];

function createQuestionBlock() {
  const questionGroup = new THREE.Group();
  const base = createVoxel(0, 0.5, 0, COLORS.stoneBase, 1);
  const accent = COLORS.silver;

  const marks = [
    createVoxel(-0.16, 0.87, 0.52, accent, 0.16),
    createVoxel(0, 0.87, 0.52, accent, 0.16),
    createVoxel(0.16, 0.71, 0.52, accent, 0.16),
    createVoxel(0, 0.55, 0.52, accent, 0.16),
    createVoxel(0, 0.24, 0.52, accent, 0.16)
  ];

  questionGroup.add(base, ...marks);
  questionGroup.userData.type = 'empty-state';
  return questionGroup;
}

function createIncomePile(income) {
  const scale = getIncomeScale(income);
  const pile = new THREE.Group();
  const baseSize = 0.4 * scale;
  const topSize = 0.28 * scale;

  const baseVoxels = [
    createVoxel(-0.45 * scale, 0, -0.25 * scale, COLORS.gold, baseSize),
    createVoxel(0, 0, -0.22 * scale, COLORS.goldLight, baseSize),
    createVoxel(0.45 * scale, 0, -0.25 * scale, COLORS.gold, baseSize),
    createVoxel(-0.24 * scale, 0, 0.23 * scale, COLORS.goldLight, baseSize),
    createVoxel(0.24 * scale, 0, 0.23 * scale, COLORS.gold, baseSize)
  ];

  const topVoxels = [
    createVoxel(-0.12 * scale, 0.27 * scale, 0, COLORS.goldLight, topSize),
    createVoxel(0.12 * scale, 0.24 * scale, -0.04 * scale, COLORS.gold, topSize)
  ];

  pile.add(...baseVoxels, ...topVoxels);
  pile.position.set(0, 0.5, 0);
  pile.userData.type = 'income-pile';
  pile.userData.scale = Number(scale.toFixed(2));

  return pile;
}

export function buildDynamicEntities(group, bills, income, options = {}) {
  const safeStage = Math.max(0, Math.min(6, Math.floor(Number(options?.islandStage) || 0)));

  if (bills.length === 0) {
    group.add(createQuestionBlock());
  } else {
    const baseRadius = bills.length > 8 ? 4.2 : bills.length > 4 ? 3.8 : 3.4;
    const radius = Math.min(5.5, baseRadius + safeStage * 0.22);
    const startAngle = Math.PI * 0.14;
    const endAngle = Math.PI * 0.86;
    const zOffset = Math.min(1.45, 0.9 + safeStage * 0.08);

    bills.forEach((bill, index) => {
      const t = bills.length === 1 ? 0.5 : index / (bills.length - 1);
      const angle = startAngle + (endAngle - startAngle) * t;
      const x = Math.cos(angle) * radius;
      const z = Math.sin(angle) * radius - zOffset;
      const size = getMonsterScale(bill.amount);
      const color = BILL_CATEGORY_COLORS[bill.category] ?? BILL_CATEGORY_COLORS.other;
      const monster = createMonster(x, z, color, size);

      monster.userData.type = 'bill-monster';
      monster.userData.name = bill.name;
      monster.userData.amount = bill.amount;
      monster.userData.category = bill.category;
      monster.userData.scale = size;
      monster.userData.color = color;

      group.add(monster);
    });
  }

  group.add(createIncomePile(income));
}

export function buildIslandStage(group, stage) {
  if (!group.userData.builtStages) {
    group.userData.builtStages = new Set();
  }

  const builtStages = group.userData.builtStages;
  const safeStage = Math.max(0, Math.min(6, Math.floor(stage)));
  const addedObjects = [];

  for (let current = 0; current <= safeStage; current += 1) {
    if (builtStages.has(current)) {
      continue;
    }

    const objects = STAGE_BUILDERS[current]?.() ?? [];
    objects.forEach((object) => {
      if (!object.userData.growthAnimation) {
        markGrowthObject(object);
      }

      object.userData.islandStage = current;
      group.add(object);
      addedObjects.push(object);
    });

    builtStages.add(current);
  }

  return addedObjects;
}

export function updateIslandGrowthAnimations(group, nowMs, deltaSeconds) {
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
      const time = nowMs * 0.001 * cloudMotion.speed + cloudMotion.phase;
      object.position.x = cloudMotion.originX + Math.sin(time) * cloudMotion.amplitudeX;
      object.position.z = cloudMotion.originZ + Math.cos(time * 0.85) * cloudMotion.amplitudeZ;
      object.position.y = cloudMotion.originY + Math.sin(time * 0.7) * 0.12;
    }
  });
}
