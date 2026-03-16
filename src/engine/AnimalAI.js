// ============= ANIMAL AI =============
// Simple NPC creatures that wander their home zones.
// No gameplay impact — purely aesthetic life on the island.

import * as THREE from 'three';

// ─── Constants ───
const MOVE_SPEED = 0.4; // Slower than agents
const ARRIVAL_THRESHOLD = 0.1;
const WANDER_PAUSE_MIN = 2.0; // Seconds before picking new target
const WANDER_PAUSE_MAX = 6.0;

// ─── Animal Definitions ───
const ANIMAL_DEFS = [
  { type: 'chicken', zone: { x: 0.5, z: -0.8 }, radius: 1.2, count: 3 },
  { type: 'chicken', zone: { x: -0.3, z: -1.0 }, radius: 0.8, count: 2 },
  { type: 'cow', zone: { x: 1.5, z: 1.0 }, radius: 1.5, count: 2 },
  { type: 'dog', zone: { x: -0.2, z: -1.5 }, radius: 2.0, count: 1 },
  { type: 'cat', zone: { x: 0.3, z: 0.2 }, radius: 0.5, count: 1 }
];

// ─── Animal State ───
const animals = []; // { mesh, type, home, radius, target, state, timer, animClock }

/**
 * Initialize animals and add to scene.
 * Call once during scene setup.
 * @param {THREE.Scene} scene
 */
export function initAnimals(scene) {
  ANIMAL_DEFS.forEach((def) => {
    for (let i = 0; i < def.count; i++) {
      const angle = Math.random() * Math.PI * 2;
      const dist = Math.random() * def.radius * 0.5;
      const startX = def.zone.x + Math.cos(angle) * dist;
      const startZ = def.zone.z + Math.sin(angle) * dist;

      const mesh = createAnimalMesh(def.type);
      mesh.position.set(startX, 0, startZ);
      scene.add(mesh);

      animals.push({
        mesh,
        type: def.type,
        home: { x: def.zone.x, z: def.zone.z },
        radius: def.radius,
        target: { x: startX, z: startZ },
        state: 'idle', // 'idle' | 'walking'
        timer: Math.random() * WANDER_PAUSE_MAX,
        animClock: Math.random() * 10
      });
    }
  });

  console.log(`[AnimalAI] Spawned ${animals.length} animals`);
}

/**
 * Update all animals (call every frame from animation loop).
 * @param {number} deltaTime - Seconds since last frame
 */
export function updateAnimals(deltaTime) {
  animals.forEach((animal) => {
    animal.animClock += deltaTime;

    if (animal.state === 'idle') {
      animal.timer -= deltaTime;
      if (animal.timer <= 0) {
        // Pick new wander target within home radius
        const angle = Math.random() * Math.PI * 2;
        const dist = Math.random() * animal.radius;
        animal.target.x = animal.home.x + Math.cos(angle) * dist;
        animal.target.z = animal.home.z + Math.sin(angle) * dist;
        animal.state = 'walking';
      }

      // Idle animation
      animateIdle(animal, deltaTime);
    } else if (animal.state === 'walking') {
      // Move toward target
      const dx = animal.target.x - animal.mesh.position.x;
      const dz = animal.target.z - animal.mesh.position.z;
      const dist = Math.sqrt(dx * dx + dz * dz);

      if (dist < ARRIVAL_THRESHOLD) {
        animal.state = 'idle';
        animal.timer = WANDER_PAUSE_MIN + Math.random() * (WANDER_PAUSE_MAX - WANDER_PAUSE_MIN);
      } else {
        const speed = animal.type === 'cow' ? MOVE_SPEED * 0.5 : MOVE_SPEED;
        const step = speed * deltaTime;
        animal.mesh.position.x += (dx / dist) * step;
        animal.mesh.position.z += (dz / dist) * step;

        // Face direction of travel
        animal.mesh.rotation.y = Math.atan2(dx, dz);
      }

      // Walk animation
      animateWalking(animal, deltaTime);
    }
  });
}

/**
 * Dispose all animal meshes from scene.
 * @param {THREE.Scene} scene
 */
export function disposeAnimals(scene) {
  animals.forEach((animal) => {
    scene.remove(animal.mesh);
  });
  animals.length = 0;
}

// ─── Animal Mesh Builders ───

function createAnimalMesh(type) {
  switch (type) {
    case 'chicken': return createChicken();
    case 'cow': return createCow();
    case 'dog': return createDog();
    case 'cat': return createCat();
    default: return createChicken();
  }
}

function createChicken() {
  const g = new THREE.Group();
  const white = new THREE.MeshStandardMaterial({ color: '#f5f5f0', roughness: 0.8 });
  const red = new THREE.MeshStandardMaterial({ color: '#dc2626', roughness: 0.6 });
  const yellow = new THREE.MeshStandardMaterial({ color: '#fbbf24', roughness: 0.6 });
  const dark = new THREE.MeshStandardMaterial({ color: '#1e293b' });

  // Body
  const body = new THREE.Mesh(new THREE.BoxGeometry(0.12, 0.1, 0.15), white);
  body.position.y = 0.08;
  body.castShadow = true;
  g.add(body);

  // Head
  const head = new THREE.Mesh(new THREE.BoxGeometry(0.07, 0.07, 0.07), white);
  head.position.set(0, 0.16, 0.06);
  head.castShadow = true;
  g.add(head);
  g.userData.head = head;

  // Comb
  const comb = new THREE.Mesh(new THREE.BoxGeometry(0.03, 0.04, 0.03), red);
  comb.position.set(0, 0.21, 0.06);
  g.add(comb);

  // Beak
  const beak = new THREE.Mesh(new THREE.BoxGeometry(0.03, 0.02, 0.04), yellow);
  beak.position.set(0, 0.15, 0.1);
  g.add(beak);

  // Eyes
  const eyeGeo = new THREE.BoxGeometry(0.015, 0.015, 0.015);
  const leftEye = new THREE.Mesh(eyeGeo, dark);
  leftEye.position.set(-0.025, 0.17, 0.09);
  g.add(leftEye);
  const rightEye = new THREE.Mesh(eyeGeo, dark);
  rightEye.position.set(0.025, 0.17, 0.09);
  g.add(rightEye);

  // Legs
  const legMat = new THREE.MeshStandardMaterial({ color: '#d4a017' });
  const legGeo = new THREE.BoxGeometry(0.02, 0.06, 0.02);
  const leftLeg = new THREE.Mesh(legGeo, legMat);
  leftLeg.position.set(-0.03, 0.02, 0);
  g.add(leftLeg);
  g.userData.leftLeg = leftLeg;
  const rightLeg = new THREE.Mesh(legGeo, legMat);
  rightLeg.position.set(0.03, 0.02, 0);
  g.add(rightLeg);
  g.userData.rightLeg = rightLeg;

  return g;
}

function createCow() {
  const g = new THREE.Group();
  const white = new THREE.MeshStandardMaterial({ color: '#f5f5f0', roughness: 0.85 });
  const black = new THREE.MeshStandardMaterial({ color: '#1e293b', roughness: 0.85 });
  const pink = new THREE.MeshStandardMaterial({ color: '#fda4af', roughness: 0.6 });

  // Body (larger than other animals)
  const body = new THREE.Mesh(new THREE.BoxGeometry(0.2, 0.15, 0.3), white);
  body.position.y = 0.14;
  body.castShadow = true;
  g.add(body);

  // Black patches
  const patch1 = new THREE.Mesh(new THREE.BoxGeometry(0.08, 0.08, 0.1), black);
  patch1.position.set(-0.07, 0.18, 0.05);
  g.add(patch1);
  const patch2 = new THREE.Mesh(new THREE.BoxGeometry(0.06, 0.06, 0.08), black);
  patch2.position.set(0.05, 0.16, -0.08);
  g.add(patch2);

  // Head
  const head = new THREE.Mesh(new THREE.BoxGeometry(0.12, 0.1, 0.1), white);
  head.position.set(0, 0.2, 0.18);
  head.castShadow = true;
  g.add(head);
  g.userData.head = head;

  // Nose
  const nose = new THREE.Mesh(new THREE.BoxGeometry(0.08, 0.05, 0.04), pink);
  nose.position.set(0, 0.18, 0.24);
  g.add(nose);

  // Legs (4)
  const legGeo = new THREE.BoxGeometry(0.04, 0.12, 0.04);
  const legMat = new THREE.MeshStandardMaterial({ color: '#e5e5e0' });
  [[-0.06, -0.1], [0.06, -0.1], [-0.06, 0.1], [0.06, 0.1]].forEach(([lx, lz], i) => {
    const leg = new THREE.Mesh(legGeo, legMat);
    leg.position.set(lx, 0.06, lz);
    leg.castShadow = true;
    g.add(leg);
    if (i === 0) g.userData.leftLeg = leg;
    if (i === 1) g.userData.rightLeg = leg;
  });

  return g;
}

function createDog() {
  const g = new THREE.Group();
  const brown = new THREE.MeshStandardMaterial({ color: '#92643a', roughness: 0.8 });
  const dark = new THREE.MeshStandardMaterial({ color: '#1e293b' });

  // Body
  const body = new THREE.Mesh(new THREE.BoxGeometry(0.1, 0.08, 0.18), brown);
  body.position.y = 0.1;
  body.castShadow = true;
  g.add(body);

  // Head
  const head = new THREE.Mesh(new THREE.BoxGeometry(0.08, 0.08, 0.08), brown);
  head.position.set(0, 0.14, 0.1);
  head.castShadow = true;
  g.add(head);
  g.userData.head = head;

  // Ears
  const earGeo = new THREE.BoxGeometry(0.03, 0.04, 0.02);
  const leftEar = new THREE.Mesh(earGeo, brown);
  leftEar.position.set(-0.04, 0.19, 0.1);
  leftEar.rotation.z = -0.3;
  g.add(leftEar);
  const rightEar = new THREE.Mesh(earGeo, brown);
  rightEar.position.set(0.04, 0.19, 0.1);
  rightEar.rotation.z = 0.3;
  g.add(rightEar);

  // Eyes
  const eyeGeo = new THREE.BoxGeometry(0.015, 0.015, 0.015);
  const leftEye = new THREE.Mesh(eyeGeo, dark);
  leftEye.position.set(-0.02, 0.15, 0.14);
  g.add(leftEye);
  const rightEye = new THREE.Mesh(eyeGeo, dark);
  rightEye.position.set(0.02, 0.15, 0.14);
  g.add(rightEye);

  // Tail
  const tail = new THREE.Mesh(new THREE.BoxGeometry(0.02, 0.06, 0.02), brown);
  tail.position.set(0, 0.14, -0.1);
  tail.rotation.x = -0.5;
  g.add(tail);
  g.userData.tail = tail;

  // Legs
  const legGeo = new THREE.BoxGeometry(0.03, 0.08, 0.03);
  [[-0.03, -0.06], [0.03, -0.06], [-0.03, 0.06], [0.03, 0.06]].forEach(([lx, lz], i) => {
    const leg = new THREE.Mesh(legGeo, brown);
    leg.position.set(lx, 0.04, lz);
    g.add(leg);
    if (i === 0) g.userData.leftLeg = leg;
    if (i === 1) g.userData.rightLeg = leg;
  });

  return g;
}

function createCat() {
  const g = new THREE.Group();
  const gray = new THREE.MeshStandardMaterial({ color: '#6b7280', roughness: 0.75 });
  const dark = new THREE.MeshStandardMaterial({ color: '#1e293b' });
  const green = new THREE.MeshStandardMaterial({ color: '#22c55e' });

  // Body
  const body = new THREE.Mesh(new THREE.BoxGeometry(0.08, 0.06, 0.14), gray);
  body.position.y = 0.08;
  body.castShadow = true;
  g.add(body);

  // Head
  const head = new THREE.Mesh(new THREE.BoxGeometry(0.07, 0.07, 0.07), gray);
  head.position.set(0, 0.12, 0.08);
  head.castShadow = true;
  g.add(head);
  g.userData.head = head;

  // Ears (triangular — use small rotated boxes)
  const earGeo = new THREE.BoxGeometry(0.025, 0.035, 0.02);
  const leftEar = new THREE.Mesh(earGeo, gray);
  leftEar.position.set(-0.025, 0.17, 0.08);
  g.add(leftEar);
  const rightEar = new THREE.Mesh(earGeo, gray);
  rightEar.position.set(0.025, 0.17, 0.08);
  g.add(rightEar);

  // Eyes (green)
  const eyeGeo = new THREE.BoxGeometry(0.015, 0.012, 0.015);
  const leftEye = new THREE.Mesh(eyeGeo, green);
  leftEye.position.set(-0.02, 0.13, 0.115);
  g.add(leftEye);
  const rightEye = new THREE.Mesh(eyeGeo, green);
  rightEye.position.set(0.02, 0.13, 0.115);
  g.add(rightEye);

  // Tail (long, curved up)
  const tail = new THREE.Mesh(new THREE.BoxGeometry(0.02, 0.02, 0.1), gray);
  tail.position.set(0, 0.1, -0.1);
  tail.rotation.x = -0.6;
  g.add(tail);
  g.userData.tail = tail;

  // Legs
  const legGeo = new THREE.BoxGeometry(0.025, 0.06, 0.025);
  [[-0.025, -0.04], [0.025, -0.04], [-0.025, 0.04], [0.025, 0.04]].forEach(([lx, lz], i) => {
    const leg = new THREE.Mesh(legGeo, gray);
    leg.position.set(lx, 0.03, lz);
    g.add(leg);
    if (i === 0) g.userData.leftLeg = leg;
    if (i === 1) g.userData.rightLeg = leg;
  });

  return g;
}

// ─── Animations ───

function animateIdle(animal, dt) {
  const t = animal.animClock;

  if (animal.type === 'chicken') {
    // Pecking animation
    const head = animal.mesh.userData.head;
    if (head) {
      head.rotation.x = Math.sin(t * 3) * 0.3; // Pecking motion
    }
  } else if (animal.type === 'cat') {
    // Tail sway
    const tail = animal.mesh.userData.tail;
    if (tail) {
      tail.rotation.z = Math.sin(t * 1.5) * 0.2;
    }
  } else if (animal.type === 'dog') {
    // Tail wag
    const tail = animal.mesh.userData.tail;
    if (tail) {
      tail.rotation.z = Math.sin(t * 5) * 0.3;
    }
  } else if (animal.type === 'cow') {
    // Gentle head bob (grazing)
    const head = animal.mesh.userData.head;
    if (head) {
      head.rotation.x = Math.sin(t * 0.8) * 0.15;
    }
  }
}

function animateWalking(animal, dt) {
  const t = animal.animClock;
  const freq = animal.type === 'cow' ? 3.0 : 6.0;

  // Leg swing
  const ll = animal.mesh.userData.leftLeg;
  const rl = animal.mesh.userData.rightLeg;
  if (ll && rl) {
    ll.rotation.x = Math.sin(t * freq) * 0.3;
    rl.rotation.x = Math.sin(t * freq + Math.PI) * 0.3;
  }

  // Body bob
  animal.mesh.position.y = Math.abs(Math.sin(t * freq)) * 0.01;
}
