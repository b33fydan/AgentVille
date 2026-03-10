import { useEffect, useRef } from 'react';
import * as THREE from 'three';
import { OrbitControls } from 'three/examples/jsm/controls/OrbitControls.js';
import { useAgentStore } from '../../store/agentStore.js';
import { generateTerrainGrid, buildTerrainScene } from '../../utils/terrainBuilder.js';
import { createAgentModel, createAgentLabel } from '../../utils/agentBuilder.js';
import { VOXEL_SIZE, VOXEL_HALF, COLORS } from '../../utils/voxelBuilder.js';

const SCENE_WIDTH = window.innerWidth;
const SCENE_HEIGHT = window.innerHeight;

export default function IslandScene() {
  const mountRef = useRef(null);
  const sceneRef = useRef(null);
  const cameraRef = useRef(null);
  const rendererRef = useRef(null);
  const controlsRef = useRef(null);
  const terrainGroupRef = useRef(null);
  const agentGroupRef = useRef(null);
  const animationFrameRef = useRef(null);

  const agents = useAgentStore((state) => state.agents);

  // ============= Scene Setup =============

  useEffect(() => {
    if (!mountRef.current) return;

    // Scene
    const scene = new THREE.Scene();
    scene.background = new THREE.Color(0x87ceeb); // Sky blue
    scene.fog = new THREE.Fog(0x87ceeb, 50, 100);
    sceneRef.current = scene;

    // Camera
    const camera = new THREE.PerspectiveCamera(
      75,
      SCENE_WIDTH / SCENE_HEIGHT,
      0.1,
      1000
    );
    camera.position.set(8, 12, 12);
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
    controls.autoRotate = false;
    controls.enableDamping = true;
    controls.dampingFactor = 0.05;
    controls.autoRotateSpeed = 0.5;
    controls.minDistance = 5;
    controls.maxDistance = 30;
    controls.maxPolarAngle = Math.PI * 0.9;
    controls.minPolarAngle = Math.PI * 0.1;
    controlsRef.current = controls;

    // Lights
    const ambientLight = new THREE.AmbientLight(0xffffff, 0.7);
    scene.add(ambientLight);

    const directionalLight = new THREE.DirectionalLight(0xffffff, 0.8);
    directionalLight.position.set(10, 20, 10);
    directionalLight.target.position.set(0, 0, 0);
    directionalLight.castShadow = true;
    directionalLight.shadow.mapSize.width = 2048;
    directionalLight.shadow.mapSize.height = 2048;
    directionalLight.shadow.camera.near = 0.5;
    directionalLight.shadow.camera.far = 100;
    directionalLight.shadow.camera.left = -20;
    directionalLight.shadow.camera.right = 20;
    directionalLight.shadow.camera.top = 20;
    directionalLight.shadow.camera.bottom = -20;
    scene.add(directionalLight);
    scene.add(directionalLight.target);

    // Water plane (background)
    const waterGeometry = new THREE.PlaneGeometry(50, 50);
    const waterMaterial = new THREE.MeshStandardMaterial({
      color: 0x1f6aa5,
      transparent: true,
      opacity: 0.4,
      roughness: 0.3,
      metalness: 0.1,
      side: THREE.DoubleSide
    });
    const water = new THREE.Mesh(waterGeometry, waterMaterial);
    water.rotation.x = -Math.PI / 2;
    water.position.y = -0.1;
    water.receiveShadow = true;
    scene.add(water);

    // Terrain group
    const terrainGroup = new THREE.Group();
    scene.add(terrainGroup);
    terrainGroupRef.current = terrainGroup;

    // Agent group
    const agentGroup = new THREE.Group();
    scene.add(agentGroup);
    agentGroupRef.current = agentGroup;

    // ============= Generate Terrain Grid =============

    const terrainGrid = generateTerrainGrid(12345); // Fixed seed for consistency
    const terrainScene = buildTerrainScene(terrainGrid, 0.6);
    terrainGroup.add(terrainScene);

    // Store in agent store for later reference
    useAgentStore.setState({
      island: {
        terrainGrid,
        seed: 12345
      }
    });

    // ============= Animation Loop =============

    let animationId;
    const animate = () => {
      animationId = window.requestAnimationFrame(animate);

      controls.update();

      renderer.render(scene, camera);
    };

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

      if (mountRef.current && renderer.domElement.parentNode === mountRef.current) {
        mountRef.current.removeChild(renderer.domElement);
      }

      renderer.dispose();
    };
  }, []);

  // ============= Render Agents =============

  useEffect(() => {
    if (!agentGroupRef.current || !agents || agents.length === 0) return;

    // Clear old agents
    agentGroupRef.current.clear();

    // Add new agents with enhanced models + labels
    agents.forEach((agent, index) => {
      const agentWrapper = new THREE.Group();

      // Create enhanced voxel model
      const agentModel = createAgentModel(agent);
      agentWrapper.add(agentModel);

      // Create label with name + morale bar
      const label = createAgentLabel(agent);
      agentModel.add(label);

      // Position agent on island (starting positions, will be updated by zone assignments)
      const positions = [
        { x: -2, z: -2 },
        { x: 0, z: -2.2 },
        { x: 2, z: -2 }
      ];
      const pos = positions[index % positions.length];
      agentWrapper.position.set(pos.x, 0.5, pos.z);

      agentWrapper.userData.agentId = agent.id;
      agentGroupRef.current.add(agentWrapper);
    });
  }, [agents]);

  return <div ref={mountRef} style={{ width: '100vw', height: '100vh', overflow: 'hidden' }} />;
}
