import { useEffect, useRef } from 'react';
import { useAgentStore } from '../../store/agentStore.js';
import { useGameStore } from '../../store/gameStore.js';
import { generateTerrainGrid, buildTerrainScene } from '../../utils/terrainBuilder.js';
import { createAgentModel, createAgentLabel, getMoraleAnimSpeed, updateMoraleTint, updateMutinousHeadShake } from '../../utils/agentBuilder.js';
import { VOXEL_SIZE, VOXEL_HALF, COLORS } from '../../utils/voxelBuilder.js';
import { IslandSceneManager } from '../../utils/islandSceneManager.js';
import { populateTerrainProps } from '../../utils/terrainPropsBuilder.js';
import { initAgentPosition, setAgentTarget, recallAgentToCenter, getZoneWorldPosition, updateAgentPositions } from '../../utils/agentMovement.js';

const SCENE_WIDTH = window.innerWidth;
const SCENE_HEIGHT = window.innerHeight;

export default function IslandScene() {
  const mountRef = useRef(null);
  const sceneRef = useRef(null);
  const cameraRef = useRef(null);
  const rendererRef = useRef(null);
  const controlsRef = useRef(null);
  const terrainGroupRef = useRef(null);
  const animationFrameRef = useRef(null);
  const sceneManagerRef = useRef(null);
  const agentMeshesRef = useRef(new Map()); // Map<agentId, THREE.Group>

  const agents = useAgentStore((state) => state.agents);
  const resources = useGameStore((state) => state.resources);
  const terrain = useGameStore((state) => state.terrain);

  // ============= Scene Setup =============

  useEffect(() => {
    if (!mountRef.current) return;

    // Dynamically import THREE.js and OrbitControls on mount
    // This prevents the ~500KB THREE bundle from loading until the scene actually renders
    (async () => {
      const THREE = await import('three');
      const { OrbitControls } = await import('three/examples/jsm/controls/OrbitControls.js');

    // Scene
    const scene = new THREE.Scene();
    scene.background = new THREE.Color(0x87ceeb); // Sky blue
    scene.fog = new THREE.Fog(0x87ceeb, 50, 100);
    sceneRef.current = scene;

    // Camera (isometric-ish view)
    // Grid is now 16×16 at 0.5 units = 8×8 units, so camera positioned further out
    const camera = new THREE.PerspectiveCamera(
      45, // Tighter FOV for "miniature" feel
      SCENE_WIDTH / SCENE_HEIGHT,
      0.1,
      1000
    );
    camera.position.set(12, 12, 12);
    camera.lookAt(0, 0, 0);
    cameraRef.current = camera;

    // Renderer
    const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true });
    renderer.setSize(SCENE_WIDTH, SCENE_HEIGHT);
    renderer.shadowMap.enabled = true;
    renderer.shadowMap.type = THREE.PCFShadowMap;
    mountRef.current.appendChild(renderer.domElement);
    rendererRef.current = renderer;

    // Controls
    const controls = new OrbitControls(camera, renderer.domElement);
    controls.autoRotate = true; // Auto-rotate by default
    controls.autoRotateSpeed = 0.3; // Gentle rotation
    controls.enableDamping = true;
    controls.dampingFactor = 0.08;
    controls.minDistance = 5;
    controls.maxDistance = 35; // Increased for larger 16×16 grid
    controls.minPolarAngle = Math.PI * 0.3; // Prevent nearly top-down
    controls.maxPolarAngle = Math.PI / 2.2; // Prevent going under island
    controls.enablePan = false; // Disable panning
    
    // Resume auto-rotate after 5s of no interaction
    let rotateTimeout;
    controls.addEventListener('change', () => {
      controls.autoRotate = false;
      clearTimeout(rotateTimeout);
      rotateTimeout = setTimeout(() => {
        controls.autoRotate = true;
      }, 5000);
    });
    
    controlsRef.current = controls;

    // Lights
    const ambientLight = new THREE.AmbientLight(0xffffff, 0.5);
    scene.add(ambientLight);

    // Hemisphere light (sky + ground bounce)
    const hemisphereLight = new THREE.HemisphereLight(0x87ceeb, 0x4a7c4f, 0.25);
    scene.add(hemisphereLight);

    // Directional light (main sun)
    // Adjusted for 16×16 grid and shadow coverage
    const directionalLight = new THREE.DirectionalLight(0xffffff, 0.7);
    directionalLight.position.set(12, 22, 12);
    directionalLight.target.position.set(0, 0, 0);
    directionalLight.castShadow = true;
    directionalLight.shadow.mapSize.width = 2048;
    directionalLight.shadow.mapSize.height = 2048;
    directionalLight.shadow.camera.near = 0.5;
    directionalLight.shadow.camera.far = 100;
    directionalLight.shadow.camera.left = -25;
    directionalLight.shadow.camera.right = 25;
    directionalLight.shadow.camera.top = 25;
    directionalLight.shadow.camera.bottom = -25;
    directionalLight.shadow.bias = -0.001;
    scene.add(directionalLight);
    scene.add(directionalLight.target);

    // Water planes (animated dual layer for depth effect)
    const waterGeometry1 = new THREE.PlaneGeometry(60, 60);
    const waterMaterial1 = new THREE.MeshStandardMaterial({
      color: 0x3b82f6,
      transparent: true,
      opacity: 0.6,
      roughness: 0.2,
      metalness: 0.2,
      side: THREE.DoubleSide
    });
    const water1 = new THREE.Mesh(waterGeometry1, waterMaterial1);
    water1.rotation.x = -Math.PI / 2;
    water1.position.y = -0.15;
    water1.receiveShadow = true;
    scene.add(water1);

    // Deeper water layer
    const waterGeometry2 = new THREE.PlaneGeometry(60, 60);
    const waterMaterial2 = new THREE.MeshStandardMaterial({
      color: 0x1d4ed8,
      transparent: true,
      opacity: 0.3,
      roughness: 0.4,
      metalness: 0.1,
      side: THREE.DoubleSide
    });
    const water2 = new THREE.Mesh(waterGeometry2, waterMaterial2);
    water2.rotation.x = -Math.PI / 2;
    water2.position.y = -0.3;
    water2.receiveShadow = true;
    scene.add(water2);

    // Store water refs for animation
    const waterAnimationRef = { water1, water2, time: 0 };

    // Terrain group
    const terrainGroup = new THREE.Group();
    scene.add(terrainGroup);
    terrainGroupRef.current = terrainGroup;

    // ============= Generate Terrain Grid =============

    const terrainGrid = generateTerrainGrid(12345); // Fixed seed for consistency
    const terrainScene = buildTerrainScene(terrainGrid, 0.6);
    terrainGroup.add(terrainScene);

    // Store in game store for reference
    useGameStore.setState({
      terrain: terrainGrid,
      islandSeed: 12345
    });

    // ============= Populate Ambient Terrain Props =============
    // Add trees, grass, reeds, rocks, fence, path (one-time on init)
    populateTerrainProps(scene, terrainGrid, 12345);

    // ============= Initialize Scene Manager =============

    const sceneManager = new IslandSceneManager(scene, terrainGrid);
    sceneManager.initStaticProps(); // Add farmhouse
    sceneManagerRef.current = sceneManager;

    // ============= Animation Loop =============

    let animationId;
    let lastFrameTime = performance.now();

    const animate = () => {
      animationId = window.requestAnimationFrame(animate);

      // Calculate delta time
      const now = performance.now();
      const deltaTime = Math.min((now - lastFrameTime) / 1000, 0.033); // Cap at 33ms (30 FPS min)
      lastFrameTime = now;

      // Water animation (gentle wave)
      waterAnimationRef.time += 0.01;
      const waveAmount = 0.03;
      water1.position.y = -0.15 + Math.sin(waterAnimationRef.time) * waveAmount;
      water2.position.y = -0.3 + Math.sin(waterAnimationRef.time + 1) * (waveAmount * 0.6);

      // ===== AGENT MOVEMENT & ANIMATION =====
      const agentMeshes = agentMeshesRef.current;

      // 1. Update all agent positions (movement toward targets)
      const positions = updateAgentPositions(deltaTime);

      // 2. Apply positions to meshes and handle state transitions
      positions.forEach((pos, agentId) => {
        const mesh = agentMeshes.get(agentId);
        if (!mesh) return;

        // Update position
        mesh.position.x = pos.x;
        mesh.position.z = pos.z;

        // Transition to working state when arrived at zone
        if (pos.arrived && mesh.animState === 'walking') {
          const agent = useAgentStore.getState().agents.find((a) => a.id === agentId);
          if (agent?.assignedZone !== null && agent?.assignedZone !== undefined) {
            mesh.animState = 'working';
            // Map zone index to zone type
            const zoneType = getZoneTypeFromAgent(agent);
            mesh.zoneType = zoneType;
          } else {
            mesh.animState = 'idle';
            mesh.zoneType = null;
          }
        }

        // Update facing direction while walking
        if (pos.direction) {
          mesh.rotation.y = Math.atan2(pos.direction.x, pos.direction.z);
        }
      });

      // 3. Update all agent animations
      agentMeshes.forEach((mesh) => {
        mesh.updateAnimation(deltaTime);
      });

      controls.update();

      renderer.render(scene, camera);
    };

    // Helper: Get zone type from agent
    function getZoneTypeFromAgent(agent) {
      if (!agent.assignedZone) return null;
      const pos = getZoneWorldPosition(agent.assignedZone);
      // Determine zone type from position or store
      // For now, use a simple mapping
      if (agent.assignedZone === 'forest') return 'forest';
      if (agent.assignedZone === 'plains') return 'plains';
      if (agent.assignedZone === 'wetlands') return 'wetlands';
      return null;
    }

    animate();
    animationFrameRef.current = animationId;

    // ============= Handle Resize =============

    const handleResize = () => {
      const width = window.innerWidth;
      const height = window.innerHeight;

      camera.aspect = width / height;
      camera.updateProjectionMatrix();
      renderer.setSize(width, height);
    };

    window.addEventListener('resize', handleResize);

    // ============= Cleanup =============

    return () => {
      window.removeEventListener('resize', handleResize);
      window.cancelAnimationFrame(animationId);

      // Cleanup scene manager
      if (sceneManagerRef.current) {
        sceneManagerRef.current.dispose();
      }

      if (mountRef.current && renderer.domElement.parentNode === mountRef.current) {
        mountRef.current.removeChild(renderer.domElement);
      }

      renderer.dispose();
    };
    })(); // End async IIFE for dynamic THREE import
  }, []);

  // ============= Sync Scene Manager =============

  useEffect(() => {
    if (!sceneManagerRef.current) return;

    // Sync agents and resources whenever they change
    sceneManagerRef.current.syncScene(agents, resources, terrain);
  }, [agents, resources, terrain]);

  // ============= AGENT MOVEMENT SUBSCRIPTION =============
  
  useEffect(() => {
    // Subscribe to agent changes (assignments, morale)
    const unsubscribe = useAgentStore.subscribe(
      (state) => state.agents.map((a) => ({ id: a.id, morale: a.morale, assignedZone: a.assignedZone })),
      (agentStates) => {
        const agentMeshes = agentMeshesRef.current;
        const scene = sceneRef.current;
        
        if (!scene) return;

        agentStates.forEach((agent) => {
          let mesh = agentMeshes.get(agent.id);

          // Create mesh if it doesn't exist
          if (!mesh) {
            const fullAgent = useAgentStore.getState().agents.find((a) => a.id === agent.id);
            if (!fullAgent) return;

            mesh = createAgentModel(fullAgent);
            mesh.position.set(0, 0.5, -1.5); // Default center position
            mesh.baseY = 0.5;
            scene.add(mesh);
            agentMeshes.set(agent.id, mesh);

            // Initialize position tracking
            initAgentPosition(agent.id, 0, -1.5);
          }

          // Update animation speed from morale
          mesh.animSpeed = getMoraleAnimSpeed(agent.morale);

          // Update visual tint from morale
          const fullAgent = useAgentStore.getState().agents.find((a) => a.id === agent.id);
          if (fullAgent) {
            updateMoraleTint(mesh, agent.morale);
          }

          // Update target position from zone assignment
          if (agent.assignedZone) {
            const targetPos = getZoneWorldPosition(agent.assignedZone);
            setAgentTarget(agent.id, targetPos.x, targetPos.z);
            mesh.animState = 'walking';
          } else {
            recallAgentToCenter(agent.id);
            mesh.animState = 'walking';
          }
        });
      }
    );

    return () => unsubscribe();
  }, []);

  return <div ref={mountRef} style={{ width: '100vw', height: '100vh', overflow: 'hidden' }} />;
}
