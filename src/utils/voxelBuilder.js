import * as THREE from 'three';
import { mergeGeometries } from 'three/examples/jsm/utils/BufferGeometryUtils.js';

const BASE_VOXEL_SIZE = 0.4;
export const VOXEL_SCALE = 0.85;
export const VOXEL_SIZE = BASE_VOXEL_SIZE * VOXEL_SCALE;
export const VOXEL_HALF = VOXEL_SIZE * 0.5;

export const COLORS = {
  grassDark: '#2f7d32',
  grassBase: '#3a913f',
  grassLight: '#52aa57',
  grassMoss: '#2b6b30',
  waterDeep: '#1f6aa5',
  waterBase: '#2f87c6',
  waterShallow: '#57a8db',
  woodDark: '#5f3a1f',
  woodBase: '#7a4a24',
  woodLight: '#966233',
  stoneDark: '#5b6368',
  stoneBase: '#7c858a',
  stoneLight: '#a3aeb5',
  leafDark: '#2d7d2f',
  leafBase: '#3ea542',
  leafLight: '#63c567',
  gold: '#d4af37',
  goldLight: '#e6c65c',
  silver: '#c0c0c0',
  bronze: '#cd7f32',
  monsterHousing: '#d74b4b',
  monsterUtilities: '#d6c24a',
  monsterPhone: '#7c59cf',
  monsterTransport: '#db8739',
  monsterFood: '#4ea85a',
  monsterHealth: '#7ddf96',
  monsterEntertainment: '#4b83d7',
  monsterOther: '#8c96a3',
  monsterSlime: '#65d16f',
  monsterGoblin: '#6e8a32',
  monsterOrc: '#4a6b2a',
  monsterShadow: '#4f3a6f',
  heroArmor: '#5b7289',
  heroCape: '#c84d4d',
  heroSkin: '#f1c7a3',
  heroTrim: '#f4d370',
  shieldWood: '#744522',
  shieldMetal: '#90a0ad'
};

export const BILL_CATEGORY_COLORS = {
  housing: COLORS.monsterHousing,
  utilities: COLORS.monsterUtilities,
  phone: COLORS.monsterPhone,
  transport: COLORS.monsterTransport,
  food: COLORS.monsterFood,
  health: COLORS.monsterHealth,
  entertainment: COLORS.monsterEntertainment,
  other: COLORS.monsterTransport
};

const LEAF_SHADES = [COLORS.leafDark, COLORS.leafBase, COLORS.leafLight];

function pickLeafShade() {
  return LEAF_SHADES[Math.floor(Math.random() * LEAF_SHADES.length)];
}

function addLocalVoxel(group, x, y, z, color, size = 1, scale = null) {
  const voxel = createVoxel(x, y, z, color, size);
  if (Array.isArray(scale) && scale.length === 3) {
    voxel.scale.set(scale[0], scale[1], scale[2]);
  }
  group.add(voxel);
  return voxel;
}

export function createVoxel(x, y, z, color, size = 1) {
  const cubeSize = Math.max(VOXEL_SIZE * 0.05, VOXEL_SIZE * size);
  const geometry = new THREE.BoxGeometry(cubeSize, cubeSize, cubeSize);
  const material = new THREE.MeshStandardMaterial({ color });
  const mesh = new THREE.Mesh(geometry, material);
  mesh.position.set(x, y, z);
  mesh.castShadow = true;
  mesh.receiveShadow = true;
  return mesh;
}

export function createGroundVoxel(x, y, z, color, size = 1) {
  const geometry = new THREE.BoxGeometry(VOXEL_SIZE * size, VOXEL_HALF, VOXEL_SIZE * size);
  const material = new THREE.MeshStandardMaterial({ color });
  const mesh = new THREE.Mesh(geometry, material);
  mesh.position.set(x, y, z);
  mesh.castShadow = true;
  mesh.receiveShadow = true;
  return mesh;
}

function createPineTree() {
  const tree = new THREE.Group();

  for (let index = 0; index < 4; index += 1) {
    addLocalVoxel(tree, 0, VOXEL_HALF + index * VOXEL_SIZE, 0, COLORS.woodBase, 1, [0.5, 1, 0.5]);
  }

  const baseLayerY = VOXEL_HALF + VOXEL_SIZE * 3;
  const baseSlots = [];
  for (let gx = -1; gx <= 1; gx += 1) {
    for (let gz = -1; gz <= 1; gz += 1) {
      baseSlots.push([gx, gz]);
    }
  }

  const removed = new Set();
  while (removed.size < 3) {
    removed.add(Math.floor(Math.random() * baseSlots.length));
  }

  baseSlots.forEach(([gx, gz], slotIndex) => {
    if (!removed.has(slotIndex) || (gx === 0 && gz === 0)) {
      addLocalVoxel(tree, gx * VOXEL_SIZE, baseLayerY, gz * VOXEL_SIZE, pickLeafShade());
    }
  });

  [
    [-0.5, -0.5],
    [0.5, -0.5],
    [-0.5, 0.5],
    [0.5, 0.5],
    [0, 0]
  ].forEach(([gx, gz], index) => {
    if (index !== 4 || Math.random() > 0.2) {
      addLocalVoxel(tree, gx * VOXEL_SIZE, baseLayerY + VOXEL_SIZE, gz * VOXEL_SIZE, pickLeafShade());
    }
  });

  addLocalVoxel(tree, 0, baseLayerY + VOXEL_SIZE * 2, 0, pickLeafShade());
  addLocalVoxel(tree, 0, baseLayerY + VOXEL_SIZE * 2.75, 0, COLORS.leafLight, 0.8);

  return tree;
}

function createOakTree() {
  const tree = new THREE.Group();

  for (let index = 0; index < 3; index += 1) {
    addLocalVoxel(tree, 0, VOXEL_HALF + index * VOXEL_SIZE, 0, COLORS.woodLight, 1, [0.75, 1, 0.75]);
  }

  const canopyCenterY = VOXEL_HALF + VOXEL_SIZE * 3;
  const canopyOffsets = [
    [0, 0, 0],
    [1, 0, 0],
    [-1, 0, 0],
    [0, 0, 1],
    [0, 0, -1],
    [1, 1, 0],
    [-1, 1, 0],
    [0, 1, 1],
    [0, 1, -1],
    [1, 0, 1],
    [-1, 0, -1],
    [1, 0, -1],
    [-1, 0, 1],
    [0, 2, 0],
    [0, -1, 0]
  ];

  const holeCount = 3 + Math.floor(Math.random() * 2);
  const skipped = new Set();
  while (skipped.size < holeCount) {
    skipped.add(Math.floor(Math.random() * canopyOffsets.length));
  }

  canopyOffsets.forEach(([ox, oy, oz], index) => {
    if (!skipped.has(index)) {
      addLocalVoxel(tree, ox * VOXEL_SIZE * 0.8, canopyCenterY + oy * VOXEL_SIZE * 0.8, oz * VOXEL_SIZE * 0.8, pickLeafShade());
    }
  });

  return tree;
}

function createBushCluster() {
  const bush = new THREE.Group();
  const offsets = [
    [0, VOXEL_HALF, 0],
    [VOXEL_SIZE * 0.55, VOXEL_HALF, 0],
    [-VOXEL_SIZE * 0.55, VOXEL_HALF, 0],
    [0, VOXEL_HALF, VOXEL_SIZE * 0.55],
    [0, VOXEL_HALF, -VOXEL_SIZE * 0.55]
  ];

  const count = 3 + Math.floor(Math.random() * 3);
  for (let index = 0; index < count; index += 1) {
    const [x, y, z] = offsets[index];
    addLocalVoxel(bush, x, y, z, index % 2 === 0 ? COLORS.leafBase : COLORS.leafDark, 0.95);
  }

  return bush;
}

function createDeadTreeStyle() {
  const tree = new THREE.Group();
  const trunk = addLocalVoxel(tree, 0, VOXEL_HALF, 0, '#6b4f34', 1, [0.5, 1, 0.5]);
  const trunkMid = addLocalVoxel(tree, 0.03, VOXEL_HALF + VOXEL_SIZE, 0, '#5b412a', 1, [0.5, 1, 0.5]);
  const trunkTop = addLocalVoxel(tree, 0.06, VOXEL_HALF + VOXEL_SIZE * 2, 0.02, '#4f3723', 1, [0.45, 1, 0.45]);
  trunk.rotation.z = 0.08;
  trunkMid.rotation.z = 0.08;
  trunkTop.rotation.z = 0.08;

  const branchA = addLocalVoxel(tree, VOXEL_SIZE * 0.45, VOXEL_HALF + VOXEL_SIZE * 1.9, 0, '#705037', 0.75, [0.8, 0.55, 0.5]);
  branchA.rotation.z = -0.35;
  const branchB = addLocalVoxel(tree, -VOXEL_SIZE * 0.35, VOXEL_HALF + VOXEL_SIZE * 1.45, VOXEL_SIZE * 0.2, '#705037', 0.7, [0.8, 0.5, 0.5]);
  branchB.rotation.z = 0.25;

  return tree;
}

export function createTree(x, z, style = 'oak') {
  let tree;

  if (style === 'pine') {
    tree = createPineTree();
  } else if (style === 'bush') {
    tree = createBushCluster();
  } else if (style === 'dead') {
    tree = createDeadTreeStyle();
  } else {
    tree = createOakTree();
  }

  tree.position.set(x, 0, z);
  tree.userData.type = 'tree';
  tree.userData.treeStyle = style;
  tree.userData.treeSpacingRadius =
    style === 'pine'
      ? VOXEL_SIZE * 2.25
      : style === 'bush'
        ? VOXEL_SIZE * 1.95
        : style === 'dead'
          ? VOXEL_SIZE * 1.85
          : VOXEL_SIZE * 2.35;
  return tree;
}

export function createBuilding(x, z, width, height, depth, color = COLORS.stoneBase) {
  const floorCount = Math.max(1, Math.round(height));
  const geos = [];

  for (let level = 0; level < floorCount; level += 1) {
    const taper = 1 - level * 0.05;
    const levelWidth = Math.max(0.6, width * taper);
    const levelDepth = Math.max(0.6, depth * taper);
    const levelGeo = new THREE.BoxGeometry(levelWidth * VOXEL_SIZE, VOXEL_SIZE, levelDepth * VOXEL_SIZE);
    levelGeo.translate(0, (level + 0.5) * VOXEL_SIZE, 0);
    geos.push(levelGeo);
  }

  const merged = mergeGeometries(geos);
  geos.forEach((geo) => geo.dispose());

  const mesh = new THREE.Mesh(
    merged,
    new THREE.MeshStandardMaterial({ color, roughness: 0.8, metalness: 0.05 })
  );
  mesh.position.set(x, 0, z);
  mesh.castShadow = true;
  mesh.receiveShadow = true;
  return mesh;
}

export function createCharacter(x, z, armorColor = COLORS.heroArmor, hasShield = true) {
  const character = new THREE.Group();
  const legs = createVoxel(x, 0.28, z, '#3f2b1a', 0.8);
  const torso = createVoxel(x, 0.72, z, armorColor, 1);
  const shoulders = createVoxel(x, 1.08, z, COLORS.heroTrim, 1.1);
  const head = createVoxel(x, 1.44, z, COLORS.heroSkin, 0.8);

  character.add(legs, torso, shoulders, head);

  if (hasShield) {
    const shield = createVoxel(x + 0.36, 0.76, z, COLORS.shieldWood, 0.75);
    const shieldRim = createVoxel(x + 0.36, 0.76, z + 0.02, COLORS.shieldMetal, 0.5);
    character.add(shield, shieldRim);
  }

  return character;
}

export function createMonster(x, z, color = COLORS.monsterGoblin, size = 1, category = 'other') {
  const monster = new THREE.Group();
  const unit = VOXEL_SIZE * Math.max(0.35, size);
  const bodyColor = new THREE.Color(color);
  const headColor = bodyColor.clone().multiplyScalar(0.9);

  const addMonsterVoxel = (ux, uy, uz, voxelColor, voxelSize = 1, scale = null) => {
    const voxel = createVoxel(ux * unit, uy * unit, uz * unit, voxelColor, voxelSize * Math.max(0.35, size));
    if (Array.isArray(scale) && scale.length === 3) {
      voxel.scale.set(scale[0], scale[1], scale[2]);
    }
    monster.add(voxel);
    return voxel;
  };

  for (let ix = 0; ix < 2; ix += 1) {
    for (let iy = 0; iy < 2; iy += 1) {
      for (let iz = 0; iz < 2; iz += 1) {
        addMonsterVoxel((ix - 0.5) * 0.75, iy + 0.5, (iz - 0.5) * 0.75, bodyColor);
      }
    }
  }

  if (category === 'housing') {
    for (let iy = 0; iy < 2; iy += 1) {
      for (let iz = 0; iz < 2; iz += 1) {
        addMonsterVoxel(-1.5, iy + 0.5, (iz - 0.5) * 0.75, bodyColor);
      }
    }
  }

  for (let ix = 0; ix < 2; ix += 1) {
    for (let iy = 0; iy < 2; iy += 1) {
      for (let iz = 0; iz < 2; iz += 1) {
        if (category === 'food' && ix === 0 && iy === 0 && iz === 1) {
          continue;
        }

        addMonsterVoxel((ix - 0.5) * 0.75, 2.15 + iy * 0.75, (iz - 0.5) * 0.75, headColor, 0.75);
      }
    }
  }

  addMonsterVoxel(-0.22, 2.55, 0.95, '#f8fafc', 0.25);
  addMonsterVoxel(0.22, 2.55, 0.95, '#f8fafc', 0.25);

  if (category === 'utilities') {
    const orbiters = [];
    const orbiterCount = 3 + Math.floor(Math.random() * 2);
    for (let index = 0; index < orbiterCount; index += 1) {
      const angle = (index / orbiterCount) * Math.PI * 2;
      const orbiter = addMonsterVoxel(Math.cos(angle) * 1.6, 3.1, Math.sin(angle) * 1.6, '#facc15', 0.25);
      orbiter.userData.orbitAngle = angle;
      orbiter.userData.orbitRadius = 1.6 * unit;
      orbiter.userData.orbitHeight = 3.1 * unit;
      orbiters.push(orbiter);
    }
    monster.userData.orbiters = orbiters;
  }

  if (category === 'phone') {
    for (let index = 0; index < 3; index += 1) {
      addMonsterVoxel(0.85, 3.0 + index * 0.5, 0, COLORS.monsterPhone, 0.22);
    }
  }

  if (category === 'transport') {
    [
      [-0.9, -0.2, -0.9],
      [0.9, -0.2, -0.9],
      [-0.9, -0.2, 0.9],
      [0.9, -0.2, 0.9]
    ].forEach(([lx, ly, lz]) => {
      addMonsterVoxel(lx, ly, lz, bodyColor, 0.45, [0.9, 1.5, 0.9]);
    });
  }

  if (category === 'entertainment') {
    const left = addMonsterVoxel(-0.7, 3.35, 0, '#fca5a5', 0.55, [0.5, 1.2, 0.5]);
    left.rotation.z = 0.5;
    const right = addMonsterVoxel(0.7, 3.35, 0, '#93c5fd', 0.55, [0.5, 1.2, 0.5]);
    right.rotation.z = -0.5;
  }

  if (category === 'health') {
    monster.traverse((node) => {
      if (node instanceof THREE.Mesh && node.material instanceof THREE.MeshStandardMaterial) {
        node.material.color.lerp(new THREE.Color('#dcfce7'), 0.2);
      }
    });
  }

  monster.position.set(x, VOXEL_HALF, z);
  monster.userData.type = 'monster';
  monster.userData.idleOriginX = x;
  monster.userData.idleOriginZ = z;
  monster.userData.baseY = monster.position.y;
  monster.userData.idleBobAmplitude = 0.1;
  monster.userData.idleBobSpeed = 1.6 + Math.random() * 0.7;
  monster.userData.idleBobPhase = Math.random() * Math.PI * 2;
  monster.userData.idleDriftRadius = VOXEL_SIZE * (0.08 + Math.random() * 0.09);
  monster.userData.idleDriftSpeed = 0.45 + Math.random() * 0.3;
  monster.userData.idleDriftPhase = Math.random() * Math.PI * 2;
  monster.userData.idleYawBase = monster.rotation.y;
  monster.userData.idleYawAmplitude = 0.05 + Math.random() * 0.04;
  monster.userData.idleYawSpeed = 0.8 + Math.random() * 0.35;
  monster.userData.idleYawPhase = Math.random() * Math.PI * 2;

  return monster;
}

export function createRocks(x, z, count = 4) {
  const rocks = new THREE.Group();

  for (let index = 0; index < count; index += 1) {
    const size = 0.4 + Math.random() * 0.4;
    const rock = createVoxel(
      x + (Math.random() - 0.5) * VOXEL_SIZE * 2.4,
      VOXEL_HALF,
      z + (Math.random() - 0.5) * VOXEL_SIZE * 2.4,
      index % 2 === 0 ? COLORS.stoneBase : COLORS.stoneDark,
      size
    );
    rock.scale.set(1, 0.8 + Math.random() * 0.5, 1);
    rock.rotation.y = Math.random() * Math.PI;
    rocks.add(rock);
  }

  return rocks;
}

export function createGroup(meshes = []) {
  const group = new THREE.Group();
  meshes.forEach((mesh) => group.add(mesh));
  return group;
}
