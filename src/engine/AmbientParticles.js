// ============= AMBIENT PARTICLES =============
// Lightweight particle effects for scene atmosphere:
// - Chimney smoke (morning/evening)
// - Fireflies (night)
// Zero dependencies beyond Three.js.

import * as THREE from 'three';
import { useGameStore } from '../store/gameStore';

const MAX_SMOKE = 12;
const MAX_FIREFLIES = 20;

let smokeParticles = [];
let fireflyParticles = [];
let particleGroup = null;

// Shared materials
let smokeMat = null;
let fireflyMat = null;

/**
 * Initialize particle systems. Call once during scene setup.
 * @param {THREE.Scene} scene
 */
export function initParticles(scene) {
  particleGroup = new THREE.Group();
  scene.add(particleGroup);

  const smokeGeo = new THREE.BoxGeometry(0.04, 0.04, 0.04);
  smokeMat = new THREE.MeshStandardMaterial({
    color: '#9ca3af',
    transparent: true,
    opacity: 0.4,
    roughness: 1.0
  });

  const fireflyGeo = new THREE.BoxGeometry(0.02, 0.02, 0.02);
  fireflyMat = new THREE.MeshBasicMaterial({
    color: '#fde047',
    transparent: true,
    opacity: 0.8
  });

  // Pre-create smoke particles (reuse via pool)
  for (let i = 0; i < MAX_SMOKE; i++) {
    const mesh = new THREE.Mesh(smokeGeo, smokeMat.clone());
    mesh.visible = false;
    particleGroup.add(mesh);
    smokeParticles.push({
      mesh,
      life: 0,
      maxLife: 3 + Math.random() * 2,
      vx: (Math.random() - 0.5) * 0.02,
      vy: 0.08 + Math.random() * 0.04,
      vz: (Math.random() - 0.5) * 0.02,
      startX: 0,
      startY: 0.32, // Above farmhouse chimney
      startZ: -0.05
    });
  }

  // Pre-create firefly particles
  for (let i = 0; i < MAX_FIREFLIES; i++) {
    const mesh = new THREE.Mesh(fireflyGeo, fireflyMat.clone());
    mesh.visible = false;
    particleGroup.add(mesh);
    fireflyParticles.push({
      mesh,
      active: false,
      x: (Math.random() - 0.5) * 6,
      y: 0.3 + Math.random() * 1.0,
      z: (Math.random() - 0.5) * 6,
      phase: Math.random() * Math.PI * 2,
      driftSpeed: 0.2 + Math.random() * 0.3,
      blinkSpeed: 1.5 + Math.random() * 2.0
    });
  }
}

/**
 * Update particles each frame.
 * @param {number} deltaTime - Seconds since last frame
 */
export function updateParticles(deltaTime) {
  const dayPhase = useGameStore.getState().dayPhase || 'morning';

  // Smoke: active during morning and evening
  const smokeActive = dayPhase === 'morning' || dayPhase === 'evening';
  updateSmoke(deltaTime, smokeActive);

  // Fireflies: active at night
  const firefliesActive = dayPhase === 'night';
  updateFireflies(deltaTime, firefliesActive);
}

function updateSmoke(dt, active) {
  smokeParticles.forEach((p) => {
    if (!active && p.life <= 0) {
      p.mesh.visible = false;
      return;
    }

    if (p.life <= 0) {
      // Respawn
      p.life = p.maxLife;
      p.mesh.position.set(p.startX, p.startY, p.startZ);
      p.mesh.visible = true;
      p.mesh.material.opacity = 0.4;
      p.mesh.scale.set(1, 1, 1);
    }

    p.life -= dt;
    const t = 1 - (p.life / p.maxLife); // 0→1 over lifetime

    // Rise and drift
    p.mesh.position.x += p.vx * dt;
    p.mesh.position.y += p.vy * dt;
    p.mesh.position.z += p.vz * dt;

    // Expand and fade
    const scale = 1 + t * 2;
    p.mesh.scale.set(scale, scale, scale);
    p.mesh.material.opacity = 0.4 * (1 - t);

    if (p.life <= 0) {
      p.mesh.visible = false;
    }
  });
}

function updateFireflies(dt, active) {
  fireflyParticles.forEach((p) => {
    if (!active) {
      p.mesh.visible = false;
      p.active = false;
      return;
    }

    if (!p.active) {
      p.active = true;
      p.mesh.visible = true;
    }

    p.phase += dt * p.driftSpeed;

    // Gentle floating drift
    p.mesh.position.x = p.x + Math.sin(p.phase) * 0.3;
    p.mesh.position.y = p.y + Math.sin(p.phase * 0.7) * 0.15;
    p.mesh.position.z = p.z + Math.cos(p.phase * 0.9) * 0.3;

    // Blink
    const blink = (Math.sin(p.phase * p.blinkSpeed) + 1) * 0.5; // 0→1
    p.mesh.material.opacity = 0.2 + blink * 0.7;
  });
}

/**
 * Dispose all particles.
 * @param {THREE.Scene} scene
 */
export function disposeParticles(scene) {
  if (particleGroup) {
    scene.remove(particleGroup);
    particleGroup = null;
  }
  smokeParticles = [];
  fireflyParticles = [];
}
