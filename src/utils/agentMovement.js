/**
 * Agent Movement Manager
 * Tracks agent positions and targets, handles smooth walking logic.
 * Updated by IslandScene animation loop every frame.
 */

const MOVE_SPEED = 2.0; // units per second
const ARRIVAL_THRESHOLD = 0.15; // close enough = arrived
const CENTER_POSITION = { x: 0, z: 0 }; // island center (idle point)

// Map<agentId, { current: {x, z}, target: {x, z}, isMoving: boolean }>
const agentPositions = new Map();

/**
 * Initialize agent position tracking
 * Called once when agent mesh is created
 */
export function initAgentPosition(agentId, x = 0, z = 0) {
  agentPositions.set(agentId, {
    current: { x, z },
    target: { x, z },
    isMoving: false
  });
}

/**
 * Set target position for agent (triggers walk)
 * Called when zone assignment changes
 */
export function setAgentTarget(agentId, targetX, targetZ) {
  const pos = agentPositions.get(agentId);
  if (!pos) {
    initAgentPosition(agentId, 0, 0);
    return setAgentTarget(agentId, targetX, targetZ);
  }

  pos.target = { x: targetX, z: targetZ };
  pos.isMoving = true;
}

/**
 * Recall agent to island center (unassigned)
 */
export function recallAgentToCenter(agentId) {
  setAgentTarget(agentId, CENTER_POSITION.x, CENTER_POSITION.z);
}

/**
 * Get zone world position from terrain grid
 * Maps zone index (0-255 for 16×16 grid) to world coordinates
 */
export function getZoneWorldPosition(zoneIndex) {
  if (zoneIndex === null || zoneIndex === undefined) {
    return CENTER_POSITION;
  }

  // 16×16 grid, 0.5 units per cell
  const gridSize = 16;
  const cellSize = 0.5;
  const gridWidth = gridSize * cellSize; // 8 units
  const gridHeight = gridSize * cellSize; // 8 units
  const offsetX = gridWidth / 2; // 4 units
  const offsetZ = gridHeight / 2; // 4 units

  const row = Math.floor(zoneIndex / gridSize);
  const col = zoneIndex % gridSize;

  const x = col * cellSize - offsetX + cellSize / 2;
  const z = row * cellSize - offsetZ + cellSize / 2;

  return { x, z };
}

/**
 * Update all agent positions (called every frame)
 * Returns map of updated positions with arrival status
 */
export function updateAgentPositions(deltaTime) {
  const updates = new Map();

  agentPositions.forEach((pos, agentId) => {
    if (!pos.isMoving) {
      updates.set(agentId, {
        x: pos.current.x,
        z: pos.current.z,
        arrived: false
      });
      return;
    }

    // Calculate direction to target
    const dx = pos.target.x - pos.current.x;
    const dz = pos.target.z - pos.current.z;
    const distance = Math.sqrt(dx * dx + dz * dz);

    // Check if arrived
    if (distance < ARRIVAL_THRESHOLD) {
      pos.current.x = pos.target.x;
      pos.current.z = pos.target.z;
      pos.isMoving = false;

      updates.set(agentId, {
        x: pos.current.x,
        z: pos.current.z,
        arrived: true
      });
      return;
    }

    // Move toward target
    const dirX = dx / distance;
    const dirZ = dz / distance;
    const step = MOVE_SPEED * deltaTime;

    pos.current.x += dirX * step;
    pos.current.z += dirZ * step;

    updates.set(agentId, {
      x: pos.current.x,
      z: pos.current.z,
      arrived: false,
      direction: { x: dirX, z: dirZ } // For facing direction
    });
  });

  return updates;
}

/**
 * Get current position of agent (read-only)
 */
export function getAgentPosition(agentId) {
  const pos = agentPositions.get(agentId);
  return pos ? { ...pos.current } : { x: 0, z: 0 };
}

/**
 * Reset all positions (for new game/restart)
 */
export function resetAllPositions() {
  agentPositions.clear();
}

/**
 * Debug: log all agent positions
 */
export function debugPositions() {
  console.log('=== Agent Positions ===');
  agentPositions.forEach((pos, id) => {
    console.log(`${id}: current(${pos.current.x.toFixed(2)}, ${pos.current.z.toFixed(2)}) → target(${pos.target.x.toFixed(2)}, ${pos.target.z.toFixed(2)}) moving=${pos.isMoving}`);
  });
}
