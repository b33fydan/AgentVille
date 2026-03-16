// ============= VOXEL BATCHER =============
// Collects box/sphere/cone geometry instances, groups by material,
// and creates InstancedMesh objects for efficient rendering.
// Reduces thousands of draw calls to ~20-30.

import * as THREE from 'three';

const _dummy = new THREE.Object3D();

export class VoxelBatcher {
  constructor() {
    // Map<geometryKey, Map<colorHex, Array<{position, rotation, scale}>>>
    this.batches = new Map();
  }

  /**
   * Add a box instance to the batch.
   * @param {number} x - World X
   * @param {number} y - World Y
   * @param {number} z - World Z
   * @param {string} color - Hex color string
   * @param {number} width - Box width
   * @param {number} height - Box height
   * @param {number} depth - Box depth
   * @param {object} opts - Optional { rotX, rotY, rotZ, scaleX, scaleY, scaleZ, opacity, transparent }
   */
  addBox(x, y, z, color, width = 0.1, height = 0.1, depth = 0.1, opts = {}) {
    const geoKey = `box_${width.toFixed(3)}_${height.toFixed(3)}_${depth.toFixed(3)}`;
    const matKey = opts.transparent ? `${color}_t${(opts.opacity || 0.6).toFixed(1)}` : color;

    if (!this.batches.has(geoKey)) {
      this.batches.set(geoKey, new Map());
    }
    const colorMap = this.batches.get(geoKey);
    if (!colorMap.has(matKey)) {
      colorMap.set(matKey, []);
    }

    colorMap.get(matKey).push({
      x, y, z,
      rotX: opts.rotX || 0,
      rotY: opts.rotY || 0,
      rotZ: opts.rotZ || 0,
      scaleX: opts.scaleX || 1,
      scaleY: opts.scaleY || 1,
      scaleZ: opts.scaleZ || 1,
      transparent: opts.transparent || false,
      opacity: opts.opacity || 1.0
    });
  }

  /**
   * Add a cone instance to the batch.
   */
  addCone(x, y, z, color, radius = 0.15, height = 0.2, segments = 6, opts = {}) {
    const geoKey = `cone_${radius.toFixed(3)}_${height.toFixed(3)}_${segments}`;
    const matKey = color;

    if (!this.batches.has(geoKey)) {
      this.batches.set(geoKey, new Map());
    }
    const colorMap = this.batches.get(geoKey);
    if (!colorMap.has(matKey)) {
      colorMap.set(matKey, []);
    }

    colorMap.get(matKey).push({
      x, y, z,
      rotX: opts.rotX || 0, rotY: opts.rotY || 0, rotZ: opts.rotZ || 0,
      scaleX: opts.scaleX || 1, scaleY: opts.scaleY || 1, scaleZ: opts.scaleZ || 1
    });
  }

  /**
   * Add a sphere instance to the batch.
   */
  addSphere(x, y, z, color, radius = 0.15, wSeg = 4, hSeg = 4, opts = {}) {
    const geoKey = `sphere_${radius.toFixed(3)}_${wSeg}_${hSeg}`;
    const matKey = color;

    if (!this.batches.has(geoKey)) {
      this.batches.set(geoKey, new Map());
    }
    const colorMap = this.batches.get(geoKey);
    if (!colorMap.has(matKey)) {
      colorMap.set(matKey, []);
    }

    colorMap.get(matKey).push({
      x, y, z,
      rotX: opts.rotX || 0, rotY: opts.rotY || 0, rotZ: opts.rotZ || 0,
      scaleX: opts.scaleX || 1, scaleY: opts.scaleY || 1, scaleZ: opts.scaleZ || 1
    });
  }

  /**
   * Flush all batches into InstancedMesh objects and add to scene.
   * @param {THREE.Scene|THREE.Group} parent - Where to add the meshes
   * @returns {number} Total instance count
   */
  flush(parent) {
    let totalInstances = 0;
    let totalMeshes = 0;

    this.batches.forEach((colorMap, geoKey) => {
      const geometry = this._createGeometry(geoKey);

      colorMap.forEach((instances, matKey) => {
        if (instances.length === 0) return;

        const isTransparent = matKey.includes('_t');
        const color = isTransparent ? matKey.split('_t')[0] : matKey;
        const opacity = isTransparent ? parseFloat(matKey.split('_t')[1]) : 1.0;

        const material = new THREE.MeshStandardMaterial({
          color,
          roughness: 0.8,
          metalness: 0.1,
          transparent: isTransparent,
          opacity
        });

        const mesh = new THREE.InstancedMesh(geometry, material, instances.length);
        mesh.castShadow = true;
        mesh.receiveShadow = true;

        instances.forEach((inst, idx) => {
          _dummy.position.set(inst.x, inst.y, inst.z);
          _dummy.rotation.set(inst.rotX, inst.rotY, inst.rotZ);
          _dummy.scale.set(inst.scaleX, inst.scaleY, inst.scaleZ);
          _dummy.updateMatrix();
          mesh.setMatrixAt(idx, _dummy.matrix);
        });

        mesh.instanceMatrix.needsUpdate = true;
        parent.add(mesh);

        totalInstances += instances.length;
        totalMeshes++;
      });
    });

    console.log(`[VoxelBatcher] Flushed ${totalInstances} instances across ${totalMeshes} InstancedMeshes`);
    this.batches.clear();
    return totalInstances;
  }

  _createGeometry(geoKey) {
    const parts = geoKey.split('_');
    const type = parts[0];

    if (type === 'box') {
      return new THREE.BoxGeometry(parseFloat(parts[1]), parseFloat(parts[2]), parseFloat(parts[3]));
    } else if (type === 'cone') {
      return new THREE.ConeGeometry(parseFloat(parts[1]), parseFloat(parts[2]), parseInt(parts[3]));
    } else if (type === 'sphere') {
      return new THREE.SphereGeometry(parseFloat(parts[1]), parseInt(parts[2]), parseInt(parts[3]));
    }

    return new THREE.BoxGeometry(0.1, 0.1, 0.1);
  }
}
