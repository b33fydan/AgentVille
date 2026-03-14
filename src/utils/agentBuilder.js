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

  // ===== BODY (center cube, 0.3×0.35×0.2) =====
  const body = new THREE.Mesh(
    new THREE.BoxGeometry(0.3, 0.35, 0.2),
    new THREE.MeshStandardMaterial({
      color: bodyColor,
      roughness: 0.7,
      metalness: 0.1
    })
  );
  body.position.y = 0.175;
  body.castShadow = true;
  group.add(body);

  // ===== LEGS (2 cubes, 0.12×0.25×0.12, with gap) =====
  const legGeometry = new THREE.BoxGeometry(0.12, 0.25, 0.12);
  const legMaterial = new THREE.MeshStandardMaterial({
    color: darkenColor(bodyColor, 0.6),
    roughness: 0.8
  });

  const leftLeg = new THREE.Mesh(legGeometry, legMaterial);
  leftLeg.position.set(-0.1, 0.125, 0);
  leftLeg.castShadow = true;
  group.add(leftLeg);

  const rightLeg = new THREE.Mesh(legGeometry, legMaterial);
  rightLeg.position.set(0.1, 0.125, 0);
  rightLeg.castShadow = true;
  group.add(rightLeg);

  // ===== ARMS (2 cubes, 0.08×0.25×0.08, sides of body) =====
  const armGeometry = new THREE.BoxGeometry(0.08, 0.25, 0.08);
  const armMaterial = new THREE.MeshStandardMaterial({
    color: bodyColor,
    roughness: 0.7
  });

  const leftArm = new THREE.Mesh(armGeometry, armMaterial);
  leftArm.position.set(-0.2, 0.175, 0);
  leftArm.castShadow = true;
  group.add(leftArm);

  const rightArm = new THREE.Mesh(armGeometry, armMaterial);
  rightArm.position.set(0.2, 0.175, 0);
  rightArm.castShadow = true;
  rightArm.userData.workingArm = true; // Mark for work animation
  group.add(rightArm);

  // ===== HEAD (0.25×0.25×0.25, skin tone) =====
  const head = new THREE.Mesh(
    new THREE.BoxGeometry(0.25, 0.25, 0.25),
    new THREE.MeshStandardMaterial({
      color: '#fcd34d', // Warm skin tone
      roughness: 0.6
    })
  );
  head.position.y = 0.475;
  head.castShadow = true;
  group.add(head);
  group.userData.headRef = head; // For morale bar positioning

  // ===== EYES (2 tiny cubes, 0.06×0.06×0.06) =====
  const eyeGeometry = new THREE.BoxGeometry(0.06, 0.06, 0.06);
  const eyeMaterial = new THREE.MeshStandardMaterial({ color: '#1e293b' });

  const leftEye = new THREE.Mesh(eyeGeometry, eyeMaterial);
  leftEye.position.set(-0.08, 0.53, 0.125);
  leftEye.castShadow = true;
  group.add(leftEye);

  const rightEye = new THREE.Mesh(eyeGeometry, eyeMaterial);
  rightEye.position.set(0.08, 0.53, 0.125);
  rightEye.castShadow = true;
  group.add(rightEye);

  // ===== HAT (zone-specific) =====
  const hat = createHat(specialization);
  if (hat) {
    hat.position.y = 0.65;
    hat.castShadow = true;
    group.add(hat);
  }

  // ===== TOOL (zone-specific, held in right hand) =====
  const tool = createTool(specialization);
  if (tool) {
    tool.position.set(0.28, 0.2, 0);
    tool.castShadow = true;
    group.add(tool);
  }

  // ===== MORALE BAR (floating above head) =====
  const moraleBar = createMoraleBar(morale);
  moraleBar.position.y = 0.95;
  moraleBar.userData.moraleProp = true; // Mark for visibility control
  group.add(moraleBar);

  // ===== ANIMATION DATA =====
  group.userData.rightArm = rightArm;
  group.userData.isWorking = false;
  group.userData.morale = morale;
  group.userData.moraleBar = moraleBar;
  group.userData.isDarkMorale = isDarkMorale;

  return group;
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
