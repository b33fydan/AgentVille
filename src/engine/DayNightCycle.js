// ============= DAY/NIGHT LIGHTING CYCLE =============
// Lerps scene lighting based on gameHour (0-24).
// Zero new draw calls — just parameter changes on existing lights.

// ─── Lighting Presets ───
// Each preset defines the target state at a specific hour.
// Between presets, values are linearly interpolated.

const PRESETS = [
  { // 0h — Pre-dawn (dark blue, dim)
    hour: 0,
    sunColor: [0.29, 0.44, 0.65],   // #4A6FA5 cool blue
    sunIntensity: 0.3,
    sunAngle: 45,                     // degrees from horizon
    sunSide: 1,                       // 1 = east, -1 = west
    ambientIntensity: 0.35,
    skyColor: [0.12, 0.12, 0.25],    // dark purple
    fogColor: [0.12, 0.12, 0.25],
    hemiSkyColor: [0.2, 0.25, 0.4],
    hemiGroundColor: [0.15, 0.2, 0.15]
  },
  { // 5h — Dawn (warm orange glow on horizon)
    hour: 5,
    sunColor: [1.0, 0.6, 0.3],       // warm orange
    sunIntensity: 0.5,
    sunAngle: 10,
    sunSide: 1,
    ambientIntensity: 0.35,
    skyColor: [0.6, 0.4, 0.35],      // dawn pink-orange
    fogColor: [0.6, 0.45, 0.4],
    hemiSkyColor: [0.7, 0.5, 0.4],
    hemiGroundColor: [0.25, 0.3, 0.2]
  },
  { // 8h — Morning (warm gold)
    hour: 8,
    sunColor: [1.0, 0.89, 0.71],     // #FFE4B5 warm gold
    sunIntensity: 0.8,
    sunAngle: 30,
    sunSide: 1,
    ambientIntensity: 0.45,
    skyColor: [0.53, 0.81, 0.92],    // #87CEEB sky blue
    fogColor: [0.53, 0.81, 0.92],
    hemiSkyColor: [0.53, 0.81, 0.92],
    hemiGroundColor: [0.29, 0.49, 0.31]
  },
  { // 12h — Noon (bright white, overhead)
    hour: 12,
    sunColor: [1.0, 1.0, 1.0],       // pure white
    sunIntensity: 1.0,
    sunAngle: 70,
    sunSide: 1,
    ambientIntensity: 0.5,
    skyColor: [0.53, 0.81, 0.92],
    fogColor: [0.53, 0.81, 0.92],
    hemiSkyColor: [0.53, 0.81, 0.92],
    hemiGroundColor: [0.29, 0.49, 0.31]
  },
  { // 16h — Afternoon (slightly warm)
    hour: 16,
    sunColor: [1.0, 0.95, 0.85],     // warm white
    sunIntensity: 0.9,
    sunAngle: 40,
    sunSide: -1,                      // sun moving west
    ambientIntensity: 0.45,
    skyColor: [0.53, 0.81, 0.92],
    fogColor: [0.53, 0.81, 0.92],
    hemiSkyColor: [0.53, 0.81, 0.92],
    hemiGroundColor: [0.29, 0.49, 0.31]
  },
  { // 19h — Sunset (deep orange)
    hour: 19,
    sunColor: [1.0, 0.55, 0.26],     // #FF8C42 orange
    sunIntensity: 0.6,
    sunAngle: 10,
    sunSide: -1,
    ambientIntensity: 0.35,
    skyColor: [0.6, 0.35, 0.25],     // sunset orange
    fogColor: [0.55, 0.35, 0.3],
    hemiSkyColor: [0.6, 0.4, 0.3],
    hemiGroundColor: [0.2, 0.25, 0.15]
  },
  { // 21h — Dusk (deep blue)
    hour: 21,
    sunColor: [0.29, 0.44, 0.65],
    sunIntensity: 0.35,
    sunAngle: 30,
    sunSide: -1,
    ambientIntensity: 0.35,
    skyColor: [0.15, 0.15, 0.3],     // deep twilight
    fogColor: [0.15, 0.15, 0.3],
    hemiSkyColor: [0.2, 0.2, 0.35],
    hemiGroundColor: [0.1, 0.15, 0.1]
  },
  { // 24h — Midnight (same as 0h, for seamless loop)
    hour: 24,
    sunColor: [0.29, 0.44, 0.65],
    sunIntensity: 0.3,
    sunAngle: 45,
    sunSide: 1,
    ambientIntensity: 0.35,
    skyColor: [0.12, 0.12, 0.25],
    fogColor: [0.12, 0.12, 0.25],
    hemiSkyColor: [0.2, 0.25, 0.4],
    hemiGroundColor: [0.15, 0.2, 0.15]
  }
];

// ─── Interpolation Helpers ───

function lerp(a, b, t) {
  return a + (b - a) * t;
}

function lerpColor3(a, b, t) {
  return [lerp(a[0], b[0], t), lerp(a[1], b[1], t), lerp(a[2], b[2], t)];
}

function getInterpolatedPreset(hour) {
  const h = ((hour % 24) + 24) % 24; // Normalize to 0-24

  // Find surrounding presets
  let prev = PRESETS[PRESETS.length - 2]; // 21h
  let next = PRESETS[0]; // 0h

  for (let i = 0; i < PRESETS.length - 1; i++) {
    if (h >= PRESETS[i].hour && h < PRESETS[i + 1].hour) {
      prev = PRESETS[i];
      next = PRESETS[i + 1];
      break;
    }
  }

  const range = next.hour - prev.hour;
  const t = range > 0 ? (h - prev.hour) / range : 0;

  return {
    sunColor: lerpColor3(prev.sunColor, next.sunColor, t),
    sunIntensity: lerp(prev.sunIntensity, next.sunIntensity, t),
    sunAngle: lerp(prev.sunAngle, next.sunAngle, t),
    sunSide: lerp(prev.sunSide, next.sunSide, t),
    ambientIntensity: lerp(prev.ambientIntensity, next.ambientIntensity, t),
    skyColor: lerpColor3(prev.skyColor, next.skyColor, t),
    fogColor: lerpColor3(prev.fogColor, next.fogColor, t),
    hemiSkyColor: lerpColor3(prev.hemiSkyColor, next.hemiSkyColor, t),
    hemiGroundColor: lerpColor3(prev.hemiGroundColor, next.hemiGroundColor, t)
  };
}

// ─── Public API ───

/**
 * Apply day/night lighting to the scene based on game hour.
 * Call this every frame from the animation loop.
 *
 * @param {number} gameHour - 0 to 24
 * @param {object} lights - { directionalLight, ambientLight, hemisphereLight }
 * @param {THREE.Scene} scene - for background/fog color
 */
export function applyDayNightLighting(gameHour, lights, scene) {
  const preset = getInterpolatedPreset(gameHour);

  // Directional light (sun/moon)
  if (lights.directionalLight) {
    const dl = lights.directionalLight;
    dl.color.setRGB(preset.sunColor[0], preset.sunColor[1], preset.sunColor[2]);
    dl.intensity = preset.sunIntensity;

    // Position sun based on angle and side
    const angleRad = (preset.sunAngle * Math.PI) / 180;
    const radius = 22;
    const x = Math.cos(angleRad) * radius * preset.sunSide;
    const y = Math.sin(angleRad) * radius;
    const z = 12; // Keep z stable for consistent shadows
    dl.position.set(x, y, z);
  }

  // Ambient light
  if (lights.ambientLight) {
    lights.ambientLight.intensity = preset.ambientIntensity;
  }

  // Hemisphere light
  if (lights.hemisphereLight) {
    const hl = lights.hemisphereLight;
    hl.color.setRGB(preset.hemiSkyColor[0], preset.hemiSkyColor[1], preset.hemiSkyColor[2]);
    hl.groundColor.setRGB(preset.hemiGroundColor[0], preset.hemiGroundColor[1], preset.hemiGroundColor[2]);
  }

  // Scene background
  if (scene) {
    scene.background.setRGB(preset.skyColor[0], preset.skyColor[1], preset.skyColor[2]);
    if (scene.fog) {
      scene.fog.color.setRGB(preset.fogColor[0], preset.fogColor[1], preset.fogColor[2]);
    }
  }
}
