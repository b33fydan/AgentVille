import { useEffect, useRef, useState } from 'react';
import * as THREE from 'three';
import { OrbitControls } from 'three/examples/jsm/controls/OrbitControls.js';
import { useBudgetStore } from '../../store/budgetStore.js';
import { useGameStore } from '../../store/gameStore.js';
import {
  buildGroundPlatform,
  buildDynamicEntities,
  buildIslandStage,
  clearGroup,
  disposeObject3D,
  updateDynamicEntityAnimations,
  updateIslandGrowthAnimations
} from '../../utils/budgetSceneBuilder.js';
import { getHeroArmorColor, createHero } from '../../utils/heroBuilder.js';
import { getBannerColorHex } from '../../utils/kingdomTheme.js';
import { soundManager } from '../../utils/soundManager.js';
import { VOXEL_HALF } from '../../utils/voxelBuilder.js';
import { COLORS, createVoxel } from '../../utils/voxelBuilder.js';

const BASE_FPS = 60;
const FRAME_MS = 1000 / BASE_FPS;
const HERO_STAND_Y = VOXEL_HALF;

function lerp(start, end, t) {
  return start + (end - start) * t;
}

function easeOutCubic(t) {
  return 1 - (1 - t) ** 3;
}

function easeInOutSine(t) {
  return -(Math.cos(Math.PI * t) - 1) / 2;
}

function formatCurrency(value) {
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD',
    maximumFractionDigits: 0
  }).format(Number(value) || 0);
}

function addWater(scene) {
  const waterGeometry = new THREE.PlaneGeometry(30, 30);
  const waterMaterial = new THREE.MeshStandardMaterial({
    color: COLORS.waterBase,
    transparent: true,
    opacity: 0.62,
    roughness: 0.3,
    metalness: 0.1,
    side: THREE.DoubleSide
  });

  const water = new THREE.Mesh(waterGeometry, waterMaterial);
  water.rotation.x = -Math.PI / 2;
  water.position.y = -1.05;
  water.receiveShadow = true;
  scene.add(water);
}

export default function IslandScene({ onSceneReady = null }) {
  const mountRef = useRef(null);
  const sceneRef = useRef(null);
  const cameraRef = useRef(null);
  const rendererRef = useRef(null);
  const controlsRef = useRef(null);

  const dynamicBudgetGroupRef = useRef(null);
  const islandGrowthGroupRef = useRef(null);
  const effectsGroupRef = useRef(null);
  const heroRef = useRef(null);
  const kingdomFlagRef = useRef(null);

  const animationFrameRef = useRef(0);
  const battleRunningRef = useRef(false);
  const mountedRef = useRef(false);

  const particleStateRef = useRef([]);
  const floatingEntriesRef = useRef([]);
  const floatingIdRef = useRef(0);
  const timeoutIdsRef = useRef(new Set());
  const flashRef = useRef(null);
  const flashOpacityRef = useRef(0);
  const floatingStateCountRef = useRef(0);

  const bills = useBudgetStore((state) => state.bills);
  const income = useBudgetStore((state) => state.income);

  const islandStage = useGameStore((state) => state.islandStage);
  const armorTier = useGameStore((state) => state.armorTier);
  const battleRequest = useGameStore((state) => state.battleRequest);
  const isInBattle = useGameStore((state) => state.isInBattle);
  const bannerColor = useBudgetStore((state) => state.bannerColor);

  const [floatingTexts, setFloatingTexts] = useState([]);
  const [flashOpacity, setFlashOpacity] = useState(0);

  const scheduleTimeout = (callback, delay) => {
    const id = window.setTimeout(() => {
      timeoutIdsRef.current.delete(id);
      callback();
    }, delay);
    timeoutIdsRef.current.add(id);
    return id;
  };

  const clearScheduledTimeouts = () => {
    timeoutIdsRef.current.forEach((id) => window.clearTimeout(id));
    timeoutIdsRef.current.clear();
  };

  const wait = (ms) =>
    new Promise((resolve) => {
      scheduleTimeout(resolve, ms);
    });

  const animateValue = (duration, onUpdate, easing = (t) => t) =>
    new Promise((resolve) => {
      const start = performance.now();

      const step = (now) => {
        if (!mountedRef.current) {
          resolve();
          return;
        }

        const t = Math.min(1, (now - start) / Math.max(1, duration));
        onUpdate(easing(t), t);

        if (t < 1) {
          window.requestAnimationFrame(step);
          return;
        }

        resolve();
      };

      window.requestAnimationFrame(step);
    });

  const triggerFlash = (duration = 100, maxOpacity = 0.85) => {
    flashRef.current = {
      start: performance.now(),
      duration,
      maxOpacity
    };
  };

  const spawnParticles = (worldPosition, color, count, speedRange = [1.2, 2.8], size = 0.2) => {
    if (!effectsGroupRef.current) {
      return;
    }

    const burstColor = new THREE.Color(color);

    for (let index = 0; index < count; index += 1) {
      const mesh = createVoxel(0, 0, 0, burstColor, size + Math.random() * 0.08);
      mesh.position.copy(worldPosition);
      mesh.material.transparent = true;

      const velocity = new THREE.Vector3(
        (Math.random() - 0.5) * (speedRange[1] - speedRange[0]),
        speedRange[0] + Math.random() * speedRange[1],
        (Math.random() - 0.5) * (speedRange[1] - speedRange[0])
      );

      particleStateRef.current.push({
        mesh,
        velocity,
        life: 0.65 + Math.random() * 0.35,
        totalLife: 0.9
      });

      effectsGroupRef.current.add(mesh);
    }
  };

  const addFloatingText = (text, worldPosition, color = '#facc15') => {
    floatingEntriesRef.current.push({
      id: floatingIdRef.current,
      text,
      basePosition: worldPosition.clone(),
      color,
      start: performance.now(),
      duration: 950
    });
    floatingIdRef.current += 1;
  };

  const updateFloatingTexts = (now) => {
    if (!cameraRef.current || !mountRef.current) {
      return;
    }

    const width = mountRef.current.clientWidth;
    const height = mountRef.current.clientHeight;

    const next = [];

    floatingEntriesRef.current = floatingEntriesRef.current.filter((entry) => {
      const age = now - entry.start;
      if (age >= entry.duration) {
        return false;
      }

      const t = age / entry.duration;
      const eased = easeOutCubic(t);
      const world = entry.basePosition.clone();
      world.y += 0.25 + eased * 1.35;

      const projected = world.project(cameraRef.current);
      if (projected.z > 1) {
        return true;
      }

      next.push({
        id: entry.id,
        text: entry.text,
        color: entry.color,
        opacity: 1 - t,
        scale: 1 + eased * 0.35,
        x: (projected.x * 0.5 + 0.5) * width,
        y: (-projected.y * 0.5 + 0.5) * height
      });

      return true;
    });

    if (next.length > 0 || floatingStateCountRef.current > 0) {
      floatingStateCountRef.current = next.length;
      setFloatingTexts(next);
    }
  };

  const updateParticles = (deltaSeconds) => {
    if (!effectsGroupRef.current) {
      return;
    }

    particleStateRef.current = particleStateRef.current.filter((particle) => {
      particle.velocity.y -= 8.5 * deltaSeconds;
      particle.mesh.position.addScaledVector(particle.velocity, deltaSeconds);
      particle.life -= deltaSeconds;

      const alpha = Math.max(0, Math.min(1, particle.life / particle.totalLife));
      particle.mesh.material.opacity = alpha;

      if (particle.life > 0) {
        return true;
      }

      effectsGroupRef.current.remove(particle.mesh);
      particle.mesh.geometry.dispose();
      particle.mesh.material.dispose();
      return false;
    });
  };

  const updateFlash = (now) => {
    const flash = flashRef.current;

    if (!flash) {
      if (flashOpacityRef.current !== 0) {
        flashOpacityRef.current = 0;
        setFlashOpacity(0);
      }
      return;
    }

    const t = Math.max(0, Math.min(1, (now - flash.start) / flash.duration));
    const opacity = flash.maxOpacity * (1 - t);
    flashOpacityRef.current = opacity;
    setFlashOpacity(opacity);

    if (t >= 1) {
      flashRef.current = null;
    }
  };

  const ensureHero = (armor) => {
    if (!sceneRef.current) {
      return null;
    }

    if (heroRef.current && heroRef.current.userData.armorTier === armor) {
      return heroRef.current;
    }

    if (heroRef.current) {
      sceneRef.current.remove(heroRef.current);
      disposeObject3D(heroRef.current);
      heroRef.current = null;
    }

    const hero = createHero(0, 0, armor);
    hero.visible = false;
    sceneRef.current.add(hero);
    heroRef.current = hero;
    return hero;
  };

  const ensureKingdomFlag = (colorId) => {
    if (!sceneRef.current) {
      return;
    }

    if (kingdomFlagRef.current) {
      sceneRef.current.remove(kingdomFlagRef.current);
      disposeObject3D(kingdomFlagRef.current);
      kingdomFlagRef.current = null;
    }

    const flag = new THREE.Group();
    const pole = createVoxel(0, 1.8, 0, COLORS.stoneDark, 0.12);
    pole.scale.y = 3.6;
    const cloth = createVoxel(0.34, 3.1, 0, getBannerColorHex(colorId), 0.24);
    cloth.scale.set(1.8, 1.1, 0.3);
    flag.add(pole, cloth);
    flag.position.set(0, 0.5, -0.1);
    flag.userData.type = 'kingdom-flag';
    sceneRef.current.add(flag);
    kingdomFlagRef.current = flag;
  };

  const updateCameraForStage = () => {
    const camera = cameraRef.current;
    const controls = controlsRef.current;

    if (!camera || !controls) {
      return;
    }

    const target = controls.target.clone();
    const offset = camera.position.clone().sub(target);
    if (offset.lengthSq() <= 0.0001) {
      offset.set(1, 1, 1);
    }

    const currentDistance = offset.length();
    const nextDistance = THREE.MathUtils.clamp(currentDistance, 4, 20);
    offset.setLength(nextDistance);
    camera.position.copy(target.add(offset));
    camera.lookAt(controls.target);
    controls.update();
  };

  const setMonsterFlash = (monster, colorHex) => {
    monster.traverse((node) => {
      if (node instanceof THREE.Mesh && node.material instanceof THREE.MeshStandardMaterial) {
        node.material.emissive.setHex(colorHex);
      }
    });
  };

  const runBattle = async (battleBills) => {
    if (!mountedRef.current || battleRunningRef.current || !dynamicBudgetGroupRef.current) {
      return;
    }

    battleRunningRef.current = true;
    const gameStore = useGameStore.getState();
    gameStore.setBattleState(true);
    gameStore.setHeroVisible(true);

    const openingXP = gameStore.xp;
    gameStore.setBattleDisplayXP(openingXP);

    const runtimeIncome = useBudgetStore.getState().income;
    const runtimeIslandStage = useGameStore.getState().islandStage;
    clearGroup(dynamicBudgetGroupRef.current);
    buildDynamicEntities(dynamicBudgetGroupRef.current, battleBills, runtimeIncome, {
      islandStage: runtimeIslandStage
    });

    const hero = ensureHero(useGameStore.getState().armorTier);

    if (!hero) {
      battleRunningRef.current = false;
      useGameStore.getState().setBattleState(false);
      return;
    }

    hero.visible = true;
    hero.position.set(0, -2, 0);
    hero.rotation.set(0, 0, 0);
    soundManager.playHeroSpawn();

    useGameStore.getState().setHeroPosition({ x: 0, z: 0 });

    await animateValue(
      500,
      (t) => {
        hero.position.y = lerp(-2, HERO_STAND_Y, t);
      },
      easeOutCubic
    );

    spawnParticles(hero.position.clone(), '#f8fafc', 8, [1.2, 2.5], 0.18);
    await wait(200);

    const monsters = dynamicBudgetGroupRef.current.children.filter(
      (child) => child.userData?.type === 'bill-monster'
    );

    let runningVisualXP = openingXP;

    for (const monster of monsters) {
      if (!mountedRef.current) {
        break;
      }

      const target = monster.position.clone();
      target.set(target.x, HERO_STAND_Y, target.z + 0.42);

      const startPos = hero.position.clone();
      const startRotation = hero.rotation.y;

      await animateValue(
        330,
        (t) => {
          hero.position.set(
            lerp(startPos.x, target.x, t),
            lerp(startPos.y, target.y, t),
            lerp(startPos.z, target.z, t)
          );
          hero.rotation.y = startRotation + Math.PI * 2 * t;
        },
        easeOutCubic
      );

      hero.rotation.y = 0;

      setMonsterFlash(monster, 0xffffff);
      await wait(100);
      setMonsterFlash(monster, 0x000000);

      const monsterWorld = new THREE.Vector3();
      monster.getWorldPosition(monsterWorld);

      const rewardAmount = Number(monster.userData?.amount || 0);
      const rewardColor = monster.userData?.color ?? COLORS.monsterOther;

      spawnParticles(monsterWorld, rewardColor, 4 + Math.floor(Math.random() * 2), [1.4, 3.2], 0.24);
      addFloatingText(`+${formatCurrency(rewardAmount)}`, monsterWorld, '#fde047');
      soundManager.playMonsterSlay();
      soundManager.playXPTick();

      dynamicBudgetGroupRef.current.remove(monster);
      disposeObject3D(monster);

      const xpStart = runningVisualXP;
      const xpEnd = runningVisualXP + rewardAmount;

      await animateValue(
        300,
        (t) => {
          const tickXP = Math.round(lerp(xpStart, xpEnd, t));
          useGameStore.getState().setBattleDisplayXP(tickXP);
        },
        easeOutCubic
      );

      runningVisualXP = xpEnd;
      useGameStore.getState().incrementBillsSlain(1);
    }

    const centerStart = hero.position.clone();
    await animateValue(
      280,
      (t) => {
        hero.position.set(
          lerp(centerStart.x, 0, t),
          lerp(centerStart.y, HERO_STAND_Y, t),
          lerp(centerStart.z, 0, t)
        );
      },
      easeOutCubic
    );

    await animateValue(
      500,
      (t) => {
        hero.position.y = HERO_STAND_Y + Math.sin(Math.PI * t) * 0.9;
      },
      easeInOutSine
    );

    hero.position.y = HERO_STAND_Y;
    triggerFlash(110, 0.9);
    soundManager.playVictory();
    useGameStore.getState().announceHUD({ type: 'payday', headline: 'PAYDAY COMPLETE!' });

    const beforeLevel = useGameStore.getState().level;
    const beforeArmorTier = useGameStore.getState().armorTier;
    const totalBattleXP = battleBills.reduce((sum, bill) => sum + Number(bill.amount || 0), 0);

    const budgetStore = useBudgetStore.getState();
    budgetStore.triggerPayday();

    const currentGameStore = useGameStore.getState();
    currentGameStore.addXP(totalBattleXP);
    currentGameStore.incrementMonthsCompleted();

    const afterState = useGameStore.getState();
    const leveledUp = afterState.level > beforeLevel;

    if (leveledUp && hero.userData.armorMeshes?.length) {
      triggerFlash(220, 1);
      spawnParticles(new THREE.Vector3(0, 1.5, 0), '#facc15', 18, [2.4, 4.4], 0.22);
      soundManager.playLevelUp();

      const nextTier = afterState.armorTier;
      useGameStore.getState().announceHUD({
        type: 'level-up',
        headline: 'LEVEL UP!',
        subtitle: `You are now a ${nextTier[0].toUpperCase()}${nextTier.slice(1)}!`
      });

      const fromColor = new THREE.Color(getHeroArmorColor(beforeArmorTier));
      const toColor = new THREE.Color(getHeroArmorColor(nextTier));

      await animateValue(
        700,
        (t) => {
          hero.userData.armorMeshes.forEach((mesh) => {
            if (mesh.material?.color) {
              mesh.material.color.copy(fromColor.clone().lerp(toColor, t));
            }
          });
        },
        easeOutCubic
      );

      await wait(1000);
    } else {
      await wait(900);
    }

    hero.visible = false;

    useGameStore.getState().setHeroVisible(false);
    useGameStore.getState().setHeroPosition({ x: 0, z: 0 });
    useGameStore.getState().clearBattleDisplayXP();
    useGameStore.getState().setBattleState(false);

    battleRunningRef.current = false;
  };

  useEffect(() => {
    if (!mountRef.current) {
      return () => {};
    }

    mountedRef.current = true;
    const initialIslandStage = useGameStore.getState().islandStage;

    const scene = new THREE.Scene();
    scene.background = new THREE.Color('#1a3a2a');
    sceneRef.current = scene;

    const camera = new THREE.PerspectiveCamera(50, 1, 0.1, 120);
    const initialDistance = 10;
    const initialAxis = initialDistance / Math.sqrt(3);
    camera.position.set(initialAxis * 1.05, initialAxis, initialAxis * 0.95);
    camera.lookAt(0, VOXEL_HALF, 0);
    cameraRef.current = camera;

    const renderer = new THREE.WebGLRenderer({
      antialias: true,
      alpha: false,
      powerPreference: 'high-performance'
    });
    rendererRef.current = renderer;

    renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    renderer.shadowMap.enabled = true;
    renderer.shadowMap.type = THREE.PCFSoftShadowMap;
    renderer.domElement.style.touchAction = 'none';

    const resize = () => {
      if (!mountRef.current) {
        return;
      }

      const width = mountRef.current.clientWidth;
      const height = mountRef.current.clientHeight;

      renderer.setSize(width, height);
      camera.aspect = width / Math.max(1, height);
      camera.updateProjectionMatrix();
    };

    mountRef.current.appendChild(renderer.domElement);
    resize();
    onSceneReady?.({ renderer, scene, camera, controls: null });

    const ambientLight = new THREE.AmbientLight(0xffffff, 0.5);
    scene.add(ambientLight);

    const directionalLight = new THREE.DirectionalLight(0xffffff, 0.7);
    directionalLight.position.set(8, 12, 4);
    directionalLight.castShadow = true;
    directionalLight.shadow.mapSize.set(1024, 1024);
    directionalLight.shadow.camera.near = 0.5;
    directionalLight.shadow.camera.far = 40;
    directionalLight.shadow.camera.left = -15;
    directionalLight.shadow.camera.right = 15;
    directionalLight.shadow.camera.top = 15;
    directionalLight.shadow.camera.bottom = -15;
    scene.add(directionalLight);
    const hemisphereLight = new THREE.HemisphereLight(0x87ceeb, 0x4a7c4f, 0.3);
    scene.add(hemisphereLight);

    buildGroundPlatform(scene);
    addWater(scene);
    ensureKingdomFlag(useBudgetStore.getState().bannerColor);

    const growthGroup = new THREE.Group();
    growthGroup.userData.builtStages = new Set();
    scene.add(growthGroup);
    islandGrowthGroupRef.current = growthGroup;
    const initialGrowthObjects = buildIslandStage(growthGroup, initialIslandStage);
    if (initialGrowthObjects.length > 0) {
      soundManager.playIslandGrow();
    }

    const dynamicBudgetGroup = new THREE.Group();
    scene.add(dynamicBudgetGroup);
    dynamicBudgetGroupRef.current = dynamicBudgetGroup;
    buildDynamicEntities(dynamicBudgetGroup, useBudgetStore.getState().bills, useBudgetStore.getState().income, {
      islandStage: initialIslandStage
    });

    const effectsGroup = new THREE.Group();
    scene.add(effectsGroup);
    effectsGroupRef.current = effectsGroup;

    const controls = new OrbitControls(camera, renderer.domElement);
    controls.enableDamping = true;
    controls.dampingFactor = 0.08;
    controls.target.set(0, VOXEL_HALF, 0);
    controls.minDistance = 4;
    controls.maxDistance = 20;
    controls.minPolarAngle = 0;
    controls.maxPolarAngle = Math.PI;
    controls.minAzimuthAngle = -Infinity;
    controls.maxAzimuthAngle = Infinity;
    controls.enablePan = false;
    controls.touches = {
      ONE: THREE.TOUCH.ROTATE,
      TWO: THREE.TOUCH.DOLLY_PAN
    };
    controls.update();
    controlsRef.current = controls;
    updateCameraForStage();
    onSceneReady?.({ renderer, scene, camera, controls });

    let previous = performance.now();
    let frameTimer = 0;

    const renderFrame = () => {
      animationFrameRef.current = window.requestAnimationFrame(renderFrame);

      const now = performance.now();
      const deltaMs = now - previous;
      previous = now;
      frameTimer += deltaMs;

      updateParticles(deltaMs / 1000);
      updateFloatingTexts(now);
      updateFlash(now);

      if (islandGrowthGroupRef.current) {
        updateIslandGrowthAnimations(islandGrowthGroupRef.current, now);
      }

      const battleActive = battleRunningRef.current || useGameStore.getState().isInBattle;
      if (dynamicBudgetGroupRef.current && !battleActive) {
        updateDynamicEntityAnimations(dynamicBudgetGroupRef.current, now);
      }

      if (frameTimer >= FRAME_MS) {
        controls.update();
        renderer.render(scene, camera);
        frameTimer = 0;
      }
    };

    renderFrame();
    window.addEventListener('resize', resize);

    window.render_game_to_text = () => {
      const activeMonsters = dynamicBudgetGroupRef.current
        ? dynamicBudgetGroupRef.current.children
            .filter((child) => child.userData?.type === 'bill-monster')
            .map((monster) => ({
              name: monster.userData.name,
              amount: monster.userData.amount,
              x: Number(monster.position.x.toFixed(2)),
              z: Number(monster.position.z.toFixed(2))
            }))
        : [];

      const hero = heroRef.current
        ? {
            visible: heroRef.current.visible,
            x: Number(heroRef.current.position.x.toFixed(2)),
            y: Number(heroRef.current.position.y.toFixed(2)),
            z: Number(heroRef.current.position.z.toFixed(2))
          }
        : null;

      return JSON.stringify({
        mode: useGameStore.getState().isInBattle ? 'battle' : 'idle',
        islandStage: useGameStore.getState().islandStage,
        level: useGameStore.getState().level,
        xp: useGameStore.getState().xp,
        hero,
        monsters: activeMonsters,
        coordSystem: 'origin center island, +x right, +z toward camera-left arc'
      });
    };

    return () => {
      mountedRef.current = false;
      clearScheduledTimeouts();

      delete window.render_game_to_text;

      window.removeEventListener('resize', resize);
      window.cancelAnimationFrame(animationFrameRef.current);

      controls.dispose();

      if (heroRef.current) {
        scene.remove(heroRef.current);
        disposeObject3D(heroRef.current);
        heroRef.current = null;
      }

      if (kingdomFlagRef.current) {
        scene.remove(kingdomFlagRef.current);
        disposeObject3D(kingdomFlagRef.current);
        kingdomFlagRef.current = null;
      }

      particleStateRef.current.forEach((particle) => {
        effectsGroup.remove(particle.mesh);
        particle.mesh.geometry.dispose();
        particle.mesh.material.dispose();
      });
      particleStateRef.current = [];

      if (dynamicBudgetGroupRef.current) {
        clearGroup(dynamicBudgetGroupRef.current);
        scene.remove(dynamicBudgetGroupRef.current);
        dynamicBudgetGroupRef.current = null;
      }

      if (islandGrowthGroupRef.current) {
        clearGroup(islandGrowthGroupRef.current);
        scene.remove(islandGrowthGroupRef.current);
        islandGrowthGroupRef.current = null;
      }

      if (effectsGroupRef.current) {
        clearGroup(effectsGroupRef.current);
        scene.remove(effectsGroupRef.current);
        effectsGroupRef.current = null;
      }

      scene.traverse((object) => {
        if (object instanceof THREE.Mesh) {
          object.geometry.dispose();

          if (Array.isArray(object.material)) {
            object.material.forEach((material) => material.dispose());
          } else {
            object.material.dispose();
          }
        }
      });

      renderer.dispose();

      if (mountRef.current?.contains(renderer.domElement)) {
        mountRef.current.removeChild(renderer.domElement);
      }

      onSceneReady?.(null);
    };
  }, [onSceneReady]);

  useEffect(() => {
    if (!dynamicBudgetGroupRef.current) {
      return;
    }

    if (battleRunningRef.current || isInBattle) {
      return;
    }

    clearGroup(dynamicBudgetGroupRef.current);
    buildDynamicEntities(dynamicBudgetGroupRef.current, bills, income, {
      islandStage
    });
  }, [bills, income, isInBattle, islandStage]);

  useEffect(() => {
    if (!islandGrowthGroupRef.current) {
      return;
    }

    const addedObjects = buildIslandStage(islandGrowthGroupRef.current, islandStage);
    if (addedObjects.length > 0) {
      soundManager.playIslandGrow();
    }

    updateCameraForStage();
  }, [islandStage]);

  useEffect(() => {
    if (!battleRequest || !battleRequest.id) {
      return;
    }

    if (battleRunningRef.current) {
      return;
    }

    useGameStore.getState().clearBattleRequest();

    runBattle(battleRequest.bills).catch(() => {
      battleRunningRef.current = false;
      useGameStore.getState().setBattleState(false);
      useGameStore.getState().setHeroVisible(false);
      useGameStore.getState().clearBattleDisplayXP();
    });
  }, [battleRequest]);

  useEffect(() => {
    ensureHero(armorTier);
  }, [armorTier]);

  useEffect(() => {
    ensureKingdomFlag(bannerColor);
  }, [bannerColor]);

  return (
    <div className="relative h-full w-full min-h-[360px]">
      <div ref={mountRef} className="h-full w-full min-h-[360px]" />

      <div className="pointer-events-none absolute inset-0 overflow-hidden">
        {flashOpacity > 0 && <div className="absolute inset-0 bg-white" style={{ opacity: flashOpacity }} />}

        {floatingTexts.map((text) => (
          <div
            key={text.id}
            className="absolute -translate-x-1/2 -translate-y-1/2 text-sm font-bold"
            style={{
              left: text.x,
              top: text.y,
              opacity: text.opacity,
              color: text.color,
              transform: `translate(-50%, -50%) scale(${text.scale})`
            }}
          >
            {text.text}
          </div>
        ))}
      </div>
    </div>
  );
}
