import * as THREE from 'three';
import { VOXEL_SIZE } from './voxelBuilder';

// ============= Agent Color Palette =============
const AGENT_SPECIALIZATIONS = {
  forest: {
    primary: 0x2d7d2f,   // Dark green
    secondary: 0x52aa57, // Light green
    accent: 0x1f6aa5     // Blue trim
  },
  plains: {
    primary: 0xd4af37,   // Gold
    secondary: 0xe6c65c, // Light gold
    accent: 0xf4d370     // Yellow trim
  },
  wetlands: {
    primary: 0x2f87c6,   // Blue
    secondary: 0x57a8db, // Light blue
    accent: 0x4ea85a     // Green trim
  }
};

// ============= Work Ethic → Size/Posture =============
// 0-33: Lazy (slouched, smaller) → 33-66: Normal (upright) → 66-100: Overachiever (tall, muscular)

function getAgentScale(workEthic) {
  // Map work ethic (0-100) to size (0.6 - 1.2x)
  return 0.6 + (workEthic / 100) * 0.6;
}

// ============= Risk → Color Shade Variation =============
// 0-33: Cautious (muted) → 33-66: Balanced (normal) → 66-100: Gambler (vibrant)

function getRiskColor(primary, risk) {
  const color = new THREE.Color(primary);

  if (risk < 33) {
    // Cautious: desaturate
    color.lerp(new THREE.Color(0x666666), 0.3);
  } else if (risk > 66) {
    // Gambler: saturate & brighten
    color.multiplyScalar(1.2);
  }

  return color.getHex();
}

// ============= Loyalty → Outfit Style =============
// 0-33: Independent (minimal outfit) → 33-66: Neutral (standard) → 66-100: Obedient (armored)

function hasArmor(loyalty) {
  return loyalty > 50; // Simple binary: armor if loyal enough
}

// ============= Agent Voxel Builder =============

/**
 * Creates a complete agent voxel model with trait-driven appearance
 * @param {object} agent - Agent data (name, traits, morale)
 * @returns {THREE.Group} Agent group with body, head, armor, accessories
 */
export function createAgentModel(agent) {
  const agentGroup = new THREE.Group();

  const { traits } = agent;
  const specialization = traits?.specialization || 'plains';
  const workEthic = traits?.workEthic || 50;
  const risk = traits?.risk || 50;
  const loyalty = traits?.loyalty || 50;

  const colors = AGENT_SPECIALIZATIONS[specialization];
  const scale = getAgentScale(workEthic);
  const bodyColor = getRiskColor(colors.primary, risk);
  const shouldHaveArmor = hasArmor(loyalty);

  // ===== Body (main voxel) =====
  const bodyHeight = 0.4 * scale;
  const bodyWidth = 0.25 * scale;
  const bodyGeometry = new THREE.BoxGeometry(bodyWidth, bodyHeight, bodyWidth);
  const bodyMaterial = new THREE.MeshStandardMaterial({
    color: bodyColor,
    metalness: 0.2,
    roughness: 0.7
  });
  const body = new THREE.Mesh(bodyGeometry, bodyMaterial);
  body.position.y = bodyHeight / 2 + 0.05;
  body.castShadow = true;
  body.receiveShadow = true;
  agentGroup.add(body);

  // ===== Armor (if loyal) =====
  if (shouldHaveArmor) {
    const armorGeometry = new THREE.BoxGeometry(
      bodyWidth * 1.15,
      bodyHeight * 0.8,
      bodyWidth * 1.15
    );
    const armorMaterial = new THREE.MeshStandardMaterial({
      color: colors.accent,
      metalness: 0.6,
      roughness: 0.3,
      emissive: colors.accent,
      emissiveIntensity: 0.1
    });
    const armor = new THREE.Mesh(armorGeometry, armorMaterial);
    armor.position.y = bodyHeight / 2 + 0.05;
    armor.position.z = -0.02;
    armor.castShadow = true;
    armor.receiveShadow = true;
    agentGroup.add(armor);
  }

  // ===== Head =====
  const headSize = bodyWidth * 0.8 * scale;
  const headGeometry = new THREE.BoxGeometry(headSize, headSize, headSize);
  const headMaterial = new THREE.MeshStandardMaterial({
    color: bodyColor,
    metalness: 0.2,
    roughness: 0.7
  });
  const head = new THREE.Mesh(headGeometry, headMaterial);
  head.position.y = bodyHeight + headSize / 2 + 0.1;
  head.castShadow = true;
  head.receiveShadow = true;
  agentGroup.add(head);

  // ===== Eyes (small accent voxels) =====
  const eyeSize = headSize * 0.2;
  const eyeColor = new THREE.Color(0xffffff);
  const leftEyeGeometry = new THREE.BoxGeometry(eyeSize, eyeSize, eyeSize * 0.5);
  const eyeMaterial = new THREE.MeshStandardMaterial({ color: eyeColor });

  const leftEye = new THREE.Mesh(leftEyeGeometry, eyeMaterial);
  leftEye.position.set(-headSize * 0.15, bodyHeight + headSize * 0.7, headSize * 0.4);
  leftEye.castShadow = false;
  agentGroup.add(leftEye);

  const rightEye = new THREE.Mesh(
    new THREE.BoxGeometry(eyeSize, eyeSize, eyeSize * 0.5),
    eyeMaterial
  );
  rightEye.position.set(headSize * 0.15, bodyHeight + headSize * 0.7, headSize * 0.4);
  rightEye.castShadow = false;
  agentGroup.add(rightEye);

  // ===== Specialty Accent (small shoulder gem) =====
  const accentGeometry = new THREE.OctahedronGeometry(headSize * 0.15, 2);
  const accentMaterial = new THREE.MeshStandardMaterial({
    color: colors.secondary,
    metalness: 0.7,
    roughness: 0.2,
    emissive: colors.secondary,
    emissiveIntensity: 0.3
  });
  const accent = new THREE.Mesh(accentGeometry, accentMaterial);
  accent.position.set(bodyWidth * 0.6, bodyHeight * 0.6, 0);
  accent.castShadow = true;
  agentGroup.add(accent);

  // ===== Metadata =====
  agentGroup.userData.agentId = agent.id;
  agentGroup.userData.morale = agent.morale;
  agentGroup.userData.specialization = specialization;
  agentGroup.userData.workEthic = workEthic;
  agentGroup.userData.risk = risk;
  agentGroup.userData.loyalty = loyalty;

  // Scale entire group
  agentGroup.scale.multiplyScalar(scale);

  return agentGroup;
}

/**
 * Creates a name + morale label for the agent
 * Uses Canvas texture for text rendering
 */
export function createAgentLabel(agent) {
  const canvas = document.createElement('canvas');
  canvas.width = 512;
  canvas.height = 128;

  const ctx = canvas.getContext('2d');

  // Background (semi-transparent)
  ctx.fillStyle = 'rgba(0, 0, 0, 0.7)';
  ctx.fillRect(0, 0, canvas.width, canvas.height);

  // Name (top)
  ctx.fillStyle = '#ffffff';
  ctx.font = 'bold 36px Arial';
  ctx.textAlign = 'center';
  ctx.fillText(agent.name, canvas.width / 2, 50);

  // Morale bar (bottom)
  const moralePct = agent.morale / 100;
  const barWidth = 300;
  const barHeight = 20;
  const barX = (canvas.width - barWidth) / 2;
  const barY = 75;

  // Background bar
  ctx.fillStyle = '#333333';
  ctx.fillRect(barX, barY, barWidth, barHeight);

  // Morale color (green=high, yellow=mid, red=low)
  let moraleColor = '#00ff00'; // Green
  if (moralePct < 0.33) moraleColor = '#ff3333'; // Red
  else if (moralePct < 0.66) moraleColor = '#ffff00'; // Yellow

  // Morale fill
  ctx.fillStyle = moraleColor;
  ctx.fillRect(barX, barY, barWidth * moralePct, barHeight);

  // Border
  ctx.strokeStyle = '#ffffff';
  ctx.lineWidth = 2;
  ctx.strokeRect(barX, barY, barWidth, barHeight);

  // Morale text
  ctx.fillStyle = '#ffffff';
  ctx.font = '14px Arial';
  ctx.textAlign = 'right';
  ctx.fillText(`${Math.round(agent.morale)}%`, barX + barWidth + 20, barY + 18);

  // Create texture
  const texture = new THREE.CanvasTexture(canvas);
  const geometry = new THREE.PlaneGeometry(3, 0.75);
  const material = new THREE.MeshBasicMaterial({
    map: texture,
    transparent: true,
    side: THREE.DoubleSide
  });
  const label = new THREE.Mesh(geometry, material);

  // Position above agent
  label.position.y = 1.2;

  return label;
}

/**
 * Updates agent appearance (e.g., morale color shift)
 */
export function updateAgentMorale(agentMesh, newMorale) {
  if (!agentMesh || !agentMesh.userData) return;

  agentMesh.userData.morale = newMorale;

  // Could add visual feedback here:
  // - Color shift on body based on morale
  // - Posture change (slouch vs. stand)
  // - Glow effect
  // For MVP, just update metadata. Visual update in Phase 2.
}

/**
 * Helper: Get all agent colors for a specialization
 */
export function getSpecializationColors(specialization) {
  return AGENT_SPECIALIZATIONS[specialization] || AGENT_SPECIALIZATIONS.plains;
}

/**
 * Helper: Describe agent appearance in text
 */
export function describeAgent(agent) {
  const { traits, morale } = agent;
  const workEthic = traits?.workEthic || 50;
  const risk = traits?.risk || 50;
  const loyalty = traits?.loyalty || 50;
  const spec = traits?.specialization || 'plains';

  const workDesc =
    workEthic > 66 ? 'Very hardworking' : workEthic > 33 ? 'Balanced' : 'Lazy';
  const riskDesc =
    risk > 66 ? 'Adventurous, vibrant colors' : risk > 33 ? 'Cautious, muted colors' : 'Very cautious';
  const loyalDesc =
    loyalty > 66 ? 'Armored, loyal' : loyalty > 33 ? 'Neutral stance' : 'Independent, minimal outfit';
  const moraleDesc =
    morale > 70 ? 'Very happy' : morale > 40 ? 'Content' : 'Unhappy';

  return `${agent.name} (${spec}): ${workDesc}, ${riskDesc}, ${loyalDesc}. Morale: ${moraleDesc}`;
}
