import * as THREE from 'three';

/**
 * Creates a complete 8-cube agent character model
 * Structure: legs + body + arms + head + eyes + hat + tool
 * Heights ~1.2 units (taller than wheat, shorter than trees)
 * 
 * @param {object} agent - Agent data (id, name, specialization, traits, morale)
 * @returns {THREE.Group} Complete character with animations ready
 */
export function createAgentModel(agent) {
  const group = new THREE.Group();

  const {
    specialization = 'plains',
    traits = {},
    morale = 50,
    appearance = {}
  } = agent;

  const bodyColor = appearance.bodyColor || getBodyColor(specialization);
  const isDarkMorale = morale < 20;
  const isLowMorale = morale < 40;

  // Shared geometries (reused across all sub-cubes for memory efficiency)
  const v = 0.06; // Voxel unit size (~0.06 units = high density)
  const skinColor = '#fcd34d';
  const pantsColor = darkenColor(bodyColor, 0.6);
  const shoeColor = darkenColor(bodyColor, 0.4);

  // Shared geometry — one BoxGeometry reused for all voxels
  const sharedGeo = new THREE.BoxGeometry(v, v, v);
  // Material cache to avoid duplicate materials per color
  const matCache = {};
  function getMat(color) {
    if (!matCache[color]) {
      matCache[color] = new THREE.MeshStandardMaterial({ color, roughness: 0.7, metalness: 0.1 });
    }
    return matCache[color];
  }

  function vox(parent, x, y, z, color, sx = 1, sy = 1, sz = 1) {
    const geo = (sx === 1 && sy === 1 && sz === 1) ? sharedGeo : new THREE.BoxGeometry(v * sx, v * sy, v * sz);
    const mesh = new THREE.Mesh(geo, getMat(color));
    mesh.position.set(x * v, y * v, z * v);
    mesh.castShadow = true;
    parent.add(mesh);
    return mesh;
  }

  // ===== BODY (torso: 5w × 6h × 3d voxels) =====
  const body = new THREE.Group();
  body.position.y = v * 5; // Torso center Y
  for (let bx = -2; bx <= 2; bx++) {
    for (let by = -2; by <= 3; by++) {
      for (let bz = -1; bz <= 1; bz++) {
        // Skip some interior voxels to save draw calls
        if (Math.abs(bx) < 2 && Math.abs(by) < 2 && Math.abs(bz) < 1) continue;
        const c = by >= 2 ? bodyColor : (by >= 0 ? bodyColor : pantsColor);
        vox(body, bx, by, bz, c);
      }
    }
  }
  // Belt detail
  vox(body, -1, 0, 1.1, '#8b7355', 1, 1, 0.3);
  vox(body, 0, 0, 1.1, '#d4af37', 1, 1, 0.3); // Belt buckle (gold)
  vox(body, 1, 0, 1.1, '#8b7355', 1, 1, 0.3);
  group.add(body);

  // ===== LEGS (each: 2w × 5h × 2d voxels) =====
  const leftLeg = new THREE.Group();
  leftLeg.position.set(-v * 1.2, v * 1.5, 0);
  for (let ly = 0; ly < 5; ly++) {
    for (let lx = 0; lx < 2; lx++) {
      for (let lz = 0; lz < 2; lz++) {
        const c = ly < 1 ? shoeColor : pantsColor;
        vox(leftLeg, lx - 0.5, ly - 2.5, lz - 0.5, c);
      }
    }
  }
  group.add(leftLeg);

  const rightLeg = new THREE.Group();
  rightLeg.position.set(v * 1.2, v * 1.5, 0);
  for (let ly = 0; ly < 5; ly++) {
    for (let lx = 0; lx < 2; lx++) {
      for (let lz = 0; lz < 2; lz++) {
        const c = ly < 1 ? shoeColor : pantsColor;
        vox(rightLeg, lx - 0.5, ly - 2.5, lz - 0.5, c);
      }
    }
  }
  group.add(rightLeg);

  // ===== ARMS (each: 2w × 5h × 2d voxels) =====
  const leftArm = new THREE.Group();
  leftArm.position.set(-v * 3.5, v * 6, 0);
  for (let ay = 0; ay < 5; ay++) {
    for (let ax = 0; ax < 2; ax++) {
      for (let az = 0; az < 2; az++) {
        const c = ay >= 3 ? bodyColor : skinColor;
        vox(leftArm, ax - 0.5, -ay, az - 0.5, c);
      }
    }
  }
  group.add(leftArm);

  const rightArm = new THREE.Group();
  rightArm.position.set(v * 3.5, v * 6, 0);
  rightArm.userData.workingArm = true;
  for (let ay = 0; ay < 5; ay++) {
    for (let ax = 0; ax < 2; ax++) {
      for (let az = 0; az < 2; az++) {
        const c = ay >= 3 ? bodyColor : skinColor;
        vox(rightArm, ax - 0.5, -ay, az - 0.5, c);
      }
    }
  }
  group.add(rightArm);

  // ===== HEAD (4w × 4h × 4d voxels, skin tone) =====
  const head = new THREE.Group();
  head.position.y = v * 10;
  for (let hx = -1.5; hx <= 1.5; hx++) {
    for (let hy = -1.5; hy <= 1.5; hy++) {
      for (let hz = -1.5; hz <= 1.5; hz++) {
        vox(head, hx, hy, hz, skinColor);
      }
    }
  }
  // Hair (top + back of head, darker color)
  const hairColor = darkenColor(bodyColor, 0.5);
  for (let hx = -1.5; hx <= 1.5; hx++) {
    for (let hz = -1.5; hz <= 1.5; hz++) {
      vox(head, hx, 2.2, hz, hairColor); // Top
    }
    vox(head, hx, 1.5, -1.8, hairColor); // Back row
    vox(head, hx, 0.5, -1.8, hairColor);
  }
  group.add(head);
  group.userData.headRef = head;

  // ===== EYES (2 dark cubes on face) =====
  vox(head, -0.8, 0.3, 1.8, '#1e293b');
  vox(head, 0.8, 0.3, 1.8, '#1e293b');
  // Mouth
  vox(head, -0.5, -0.7, 1.8, '#c2410c', 1, 0.5, 0.5);
  vox(head, 0.5, -0.7, 1.8, '#c2410c', 1, 0.5, 0.5);

  // ===== HAT (zone-specific) =====
  const hat = createHat(specialization);
  if (hat) {
    hat.position.y = v * 12.5;
    hat.castShadow = true;
    group.add(hat);
  }

  // ===== TOOL (zone-specific, attached to right arm) =====
  const tool = createTool(specialization);
  if (tool) {
    tool.position.set(v * 4.5, v * 3, 0);
    tool.castShadow = true;
    group.add(tool);
  }

  // ===== MORALE BAR (floating above head) =====
  const moraleBar = createMoraleBar(morale);
  moraleBar.position.y = v * 15;
  moraleBar.userData.moraleProp = true;
  group.add(moraleBar);

  // ===== ANIMATION DATA & STATE MACHINE =====
  group.userData.rightArm = rightArm;
  group.userData.leftArm = leftArm;
  group.userData.legs = [leftLeg, rightLeg];
  group.userData.body = body;
  group.userData.head = head;
  group.userData.isWorking = false;
  group.userData.morale = morale;
  group.userData.moraleBar = moraleBar;
  group.userData.isDarkMorale = isDarkMorale;
  group.userData.bodyColor = bodyColor;

  // Animation state machine
  group.animState = 'idle';
  group.animClock = 0;
  group.animSpeed = 1.0;
  group.zoneType = null;
  group.baseY = 0;

  // Animation updater (called every frame)
  group.updateAnimation = function (deltaTime) {
    this.animClock += deltaTime * this.animSpeed;

    switch (this.animState) {
      case 'idle':
        updateIdleAnimation(this, deltaTime);
        break;
      case 'walking':
        updateWalkAnimation(this, deltaTime);
        break;
      case 'working':
        updateWorkAnimation(this, deltaTime);
        break;
      default:
        break;
    }
  };

  return group;
}

// ===== ANIMATION STATE UPDATERS =====

/**
 * Idle animation: gentle Y bob + slow rotation
 */
function updateIdleAnimation(group, deltaTime) {
  const amplitude = 0.05;
  const bobFreq = 2.0; // Hz

  // Gentle Y bob
  group.position.y = group.baseY + Math.sin(group.animClock * 2 * Math.PI * bobFreq) * amplitude;

  // Slow rotation (looking around)
  group.rotation.y += 0.3 * deltaTime;
}

/**
 * Walking animation: leg swing + arm swing + body bob + face direction
 */
function updateWalkAnimation(group, deltaTime) {
  const legSwingFreq = 4.0; // Hz
  const legSwingAmp = 0.4; // radians
  const armSwingAmp = 0.3;
  const bodyBobAmp = 0.03;

  const legPhase = group.animClock * 2 * Math.PI * legSwingFreq;

  // Leg swing (alternating)
  if (group.userData.legs && group.userData.legs.length >= 2) {
    const leftLeg = group.userData.legs[0];
    const rightLeg = group.userData.legs[1];

    leftLeg.rotation.x = Math.sin(legPhase) * legSwingAmp;
    rightLeg.rotation.x = Math.sin(legPhase + Math.PI) * legSwingAmp;
  }

  // Arm swing (opposite to legs)
  if (group.userData.rightArm && group.userData.leftArm) {
    group.userData.leftArm.rotation.x = Math.sin(legPhase + Math.PI) * armSwingAmp;
    group.userData.rightArm.rotation.x = Math.sin(legPhase) * armSwingAmp;
  }

  // Body bob (subtle)
  group.position.y = group.baseY + Math.abs(Math.sin(legPhase)) * bodyBobAmp;
}

/**
 * Working animation: zone-specific (forest=chop, plains=harvest, wetlands=scoop)
 */
function updateWorkAnimation(group, deltaTime) {
  const zoneType = group.zoneType;

  if (zoneType === 'forest') {
    updateChopAnimation(group, deltaTime);
  } else if (zoneType === 'plains') {
    updateHarvestAnimation(group, deltaTime);
  } else if (zoneType === 'wetlands') {
    updateScoopAnimation(group, deltaTime);
  }
}

/**
 * Forest work: right arm chop (overhead swing)
 */
function updateChopAnimation(group, deltaTime) {
  const chopFreq = 1.0 / 1.5; // 1.5s period
  const chopPhase = group.animClock * 2 * Math.PI * chopFreq;

  if (group.userData.rightArm) {
    // Swing from -0.8 to 0.2 radians
    group.userData.rightArm.rotation.x = -0.8 + Math.sin(chopPhase + Math.PI / 2) * 0.5;
  }
}

/**
 * Plains work: bend forward + arms pull
 */
function updateHarvestAnimation(group, deltaTime) {
  const harvestFreq = 1.0 / 2.0; // 2.0s period
  const harvestPhase = group.animClock * 2 * Math.PI * harvestFreq;

  // Body bends forward
  if (group.userData.body) {
    group.userData.body.rotation.x = 0.3 * Math.abs(Math.sin(harvestPhase));
  }

  // Arms alternate reach and pull
  if (group.userData.rightArm && group.userData.leftArm) {
    group.userData.rightArm.rotation.x = Math.sin(harvestPhase) * 0.6;
    group.userData.leftArm.rotation.x = Math.sin(harvestPhase + Math.PI) * 0.6;
  }
}

/**
 * Wetlands work: both arms swing forward and down
 */
function updateScoopAnimation(group, deltaTime) {
  const scoopFreq = 1.0 / 1.8; // 1.8s period
  const scoopPhase = group.animClock * 2 * Math.PI * scoopFreq;

  if (group.userData.rightArm && group.userData.leftArm) {
    // Swing from -0.5 to 0.3
    const scoopAmount = -0.5 + Math.sin(scoopPhase + Math.PI / 2) * 0.4;
    group.userData.rightArm.rotation.x = scoopAmount;
    group.userData.leftArm.rotation.x = scoopAmount;
  }
}

// ===== HAT BY SPECIALIZATION =====

function createHat(specialization) {
  let hat;

  switch (specialization) {
    case 'forest': {
      // Yellow hard hat: wide flat cube
      hat = new THREE.Mesh(
        new THREE.BoxGeometry(0.22, 0.08, 0.22),
        new THREE.MeshStandardMaterial({ color: '#facc15' })
      );
      break;
    }
    case 'plains': {
      // Tan straw hat: slightly tapered
      hat = new THREE.Mesh(
        new THREE.ConeGeometry(0.15, 0.1, 6),
        new THREE.MeshStandardMaterial({ color: '#d4a017' })
      );
      break;
    }
    case 'wetlands': {
      // Blue bandana: flat square on head
      hat = new THREE.Mesh(
        new THREE.BoxGeometry(0.2, 0.05, 0.25),
        new THREE.MeshStandardMaterial({ color: '#3b82f6' })
      );
      break;
    }
    default:
      return null; // No hat for generalist
  }

  return hat;
}

// ===== TOOL BY SPECIALIZATION =====

function createTool(specialization) {
  const toolGroup = new THREE.Group();
  const toolMaterial = new THREE.MeshStandardMaterial({
    color: '#8b7355',
    roughness: 0.9
  });

  switch (specialization) {
    case 'forest': {
      // Axe: L-shape (3 cubes)
      // Handle: vertical
      const handle = new THREE.Mesh(
        new THREE.BoxGeometry(0.03, 0.2, 0.03),
        toolMaterial
      );
      handle.position.set(0, 0, 0);
      toolGroup.add(handle);

      // Head: horizontal cube at top
      const head = new THREE.Mesh(
        new THREE.BoxGeometry(0.12, 0.06, 0.04),
        new THREE.MeshStandardMaterial({ color: '#c0c0c0' }) // Silver head
      );
      head.position.set(0.04, 0.12, 0);
      toolGroup.add(head);
      break;
    }
    case 'plains': {
      // Scythe: curved (simulated with 3 cubes)
      // Handle
      const handle = new THREE.Mesh(
        new THREE.BoxGeometry(0.03, 0.25, 0.03),
        toolMaterial
      );
      handle.rotation.z = 0.2;
      handle.position.set(0, 0.05, 0);
      toolGroup.add(handle);

      // Blade (L-shape)
      const blade = new THREE.Mesh(
        new THREE.BoxGeometry(0.08, 0.04, 0.03),
        new THREE.MeshStandardMaterial({ color: '#c0c0c0' })
      );
      blade.position.set(0.08, 0.15, 0);
      toolGroup.add(blade);
      break;
    }
    case 'wetlands': {
      // Pitchfork: 3 prongs (using small cubes)
      // Handle
      const handle = new THREE.Mesh(
        new THREE.BoxGeometry(0.02, 0.22, 0.02),
        toolMaterial
      );
      handle.position.set(0, 0, 0);
      toolGroup.add(handle);

      // Three prongs
      const prongs = [
        { x: -0.06, z: 0 },
        { x: 0, z: 0 },
        { x: 0.06, z: 0 }
      ];

      prongs.forEach(({ x, z }) => {
        const prong = new THREE.Mesh(
          new THREE.BoxGeometry(0.03, 0.08, 0.03),
          new THREE.MeshStandardMaterial({ color: '#c0c0c0' })
        );
        prong.position.set(x, 0.18, z);
        toolGroup.add(prong);
      });
      break;
    }
    default:
      return null; // No tool for generalist
  }

  return toolGroup;
}

// ===== MORALE BAR (floating above agent) =====

function createMoraleBar(morale) {
  const barGroup = new THREE.Group();

  // Determine color: green >60%, yellow 30-60%, red <30%
  let barColor = '#22c55e'; // Green
  if (morale < 30) {
    barColor = '#ef4444'; // Red
  } else if (morale < 60) {
    barColor = '#eab308'; // Yellow
  }

  // Bar background (gray)
  const bg = new THREE.Mesh(
    new THREE.BoxGeometry(0.4, 0.05, 0.02),
    new THREE.MeshStandardMaterial({ color: '#4b5563' })
  );
  bg.position.z = 0.01;
  barGroup.add(bg);

  // Bar fill (width based on morale %)
  const fillWidth = 0.38 * (morale / 100);
  const fill = new THREE.Mesh(
    new THREE.BoxGeometry(fillWidth, 0.05, 0.02),
    new THREE.MeshStandardMaterial({ color: barColor })
  );
  fill.position.set(-0.19 + fillWidth / 2, 0, 0);
  fill.castShadow = true;
  barGroup.add(fill);

  // Billboard behavior setup (will be handled in IslandSceneManager)
  barGroup.userData.isMoraleBar = true;
  barGroup.userData.morale = morale;

  return barGroup;
}

// ===== HELPER FUNCTIONS =====

function getBodyColor(specialization) {
  const colors = {
    forest: '#2d7d2f',  // Dark green
    plains: '#d4af37',  // Gold
    wetlands: '#2f87c6' // Blue
  };
  return colors[specialization] || '#999999';
}

function darkenColor(hexColor, factor) {
  const color = new THREE.Color(hexColor);
  color.multiplyScalar(factor);
  return color;
}

/**
 * Create a label/name tag above agent (optional, for later)
 * @deprecated – use Field Log for agent identification
 */
export function createAgentLabel(agent) {
  const canvas = document.createElement('canvas');
  canvas.width = 256;
  canvas.height = 64;
  const ctx = canvas.getContext('2d');

  ctx.fillStyle = agent.appearance?.bodyColor || '#999999';
  ctx.fillRect(0, 0, 256, 64);

  ctx.fillStyle = '#ffffff';
  ctx.font = 'bold 32px Arial';
  ctx.textAlign = 'center';
  ctx.fillText(agent.name, 128, 40);

  const texture = new THREE.CanvasTexture(canvas);
  const material = new THREE.MeshBasicMaterial({ map: texture });
  const geometry = new THREE.PlaneGeometry(0.5, 0.15);
  const mesh = new THREE.Mesh(geometry, material);

  return mesh;
}

/**
 * Animation: work arm rotation (30° swing on 1.5s loop)
 * Call from IslandSceneManager animation loop
 */
export function animateAgentWorking(agent, time) {
  const rightArm = agent.userData.rightArm;
  if (!rightArm) return;

  // 1.5s period = 2π / 1.5 ≈ 4.19 rad/s
  const angle = Math.sin(time * 4.19) * 0.52; // 30° = ~0.52 rad
  rightArm.rotation.z = angle;
}

/**
 * Animation: idle bob (gentle up/down, 2s period)
 * Call from IslandSceneManager animation loop
 */
export function animateAgentIdle(agent, time) {
  const amplitude = 0.05;
  const period = 2.0;
  agent.position.y = (agent.userData.baseY || 0) + Math.sin(time * (2 * Math.PI / period)) * amplitude;
}

/**
 * Update morale bar color and fill based on current morale
 * Call when morale changes
 */
export function updateAgentMoraleBar(agent, morale) {
  const bar = agent.userData.moraleBar;
  if (!bar || !bar.children[1]) return;

  // Update color
  let barColor = '#22c55e';
  if (morale < 30) {
    barColor = '#ef4444';
  } else if (morale < 60) {
    barColor = '#eab308';
  }
  bar.children[1].material.color.setStyle(barColor);

  // Update fill width
  const fillWidth = 0.38 * (morale / 100);
  bar.children[1].scale.x = fillWidth / (0.38 * 0.5); // Normalize scale
  bar.children[1].position.x = -0.19 + fillWidth / 2;

  agent.userData.morale = morale;
}

/**
 * Get animation speed multiplier from morale
 * Affects animation frequency + visual feedback
 */
export function getMoraleAnimSpeed(morale) {
  if (morale >= 80) return 1.2; // Happy: energetic, faster
  if (morale >= 50) return 1.0; // Neutral: normal
  if (morale >= 20) return 0.6; // Unhappy: sluggish
  return 0.0; // Mutinous: stopped
}

/**
 * Update agent visual tint based on morale
 * High morale: normal colors
 * Low morale: desaturated
 * Very low: red tint
 */
export function updateMoraleTint(agent, morale) {
  const bodyGroup = agent.userData?.body;
  if (!bodyGroup) return;

  const originalColor = new THREE.Color(agent.userData.bodyColor || 0x999999);

  // Apply tint to all meshes in the body group (and agent group for arms/legs)
  const applyTint = (mesh) => {
    if (!mesh.material) return;
    if (morale >= 50) {
      mesh.material.emissive?.setHex(0x000000);
    } else if (morale >= 20) {
      mesh.material.emissive?.setHex(0x000000);
      const gray = new THREE.Color(0x888888);
      mesh.material.color.lerp(gray, 0.15);
    } else {
      mesh.material.color.setHex(0xcc3333);
      if (mesh.material.emissive) mesh.material.emissive.setHex(0x660000);
    }
  };

  bodyGroup.traverse((child) => {
    if (child.isMesh) applyTint(child);
  });
}

/**
 * Add head-shake animation for mutinous agents (morale < 20)
 * Applied during animation update
 */
export function updateMutinousHeadShake(agent, deltaTime) {
  const headMesh = agent.children.find((child) => child.geometry?.type === 'BoxGeometry' && child.position.y > 0.4);
  if (!headMesh) return;

  const shakeFreq = 2.0; // Hz
  const shakeAmp = 0.1; // radians
  headMesh.rotation.y = Math.sin(agent.animClock * 2 * Math.PI * shakeFreq) * shakeAmp;
}

/**
 * Apply morale state to agent posture
 */
export function applyMoralePosture(agent, morale) {
  if (morale < 20) {
    // Very low morale: slouch (tilt body)
    agent.children.forEach((child) => {
      if (child.userData?.workingArm) return; // Skip arms
      if (child.userData?.isMoraleBar) return; // Skip bar
      child.rotation.z = 0.1; // Slight tilt
    });
  } else if (morale < 40) {
    // Low morale: slight slouch
    agent.children.forEach((child) => {
      if (child.userData?.workingArm) return;
      if (child.userData?.isMoraleBar) return;
      child.rotation.z = 0.05;
    });
  }
}
