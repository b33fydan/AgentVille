// ============= AGENT AI ENGINE =============
// Per-agent task state machine driven by GameTicker.
// Manages: task decisions, movement targets, resource trickle, wandering.
// Runs on tick events (throttled), NOT every RAF frame.

import { useAgentStore } from '../store/agentStore';
import { useGameStore } from '../store/gameStore';
import { useLogStore } from '../store/logStore';
import { soundManager } from '../utils/soundManager';
import { setAgentTarget, recallAgentToCenter, getAgentPosition } from '../utils/agentMovement';
import { selectReaction } from '../utils/agentReactions';

// ─── Constants ───
const WORK_CYCLE_HOURS = 2; // Game-hours per work cycle (produce resources)
const WANDER_INTERVAL_HOURS = 1.5; // Game-hours between random wanders
const WANDER_RADIUS = 1.5; // World units from center for idle wandering
const RESOURCE_PER_CYCLE = 2; // Base resources per work cycle

const ZONE_POSITIONS = {
  forest: { x: -2.5, z: -0.5 },
  plains: { x: 0, z: 1 },
  wetlands: { x: 2.5, z: -0.5 }
};

const ZONE_RESOURCES = {
  forest: 'wood',
  plains: 'wheat',
  wetlands: 'hay'
};

// ─── Agent Task States ───
// Each agent has a task state tracked here (not in the store — purely visual/AI layer)
// Map<agentId, { state, workAccum, wanderAccum, lastZone }>
const agentTasks = new Map();

function getTask(agentId) {
  if (!agentTasks.has(agentId)) {
    agentTasks.set(agentId, {
      state: 'idle', // 'idle' | 'walking_to_zone' | 'working' | 'wandering' | 'reacting'
      workAccum: 0, // Game-hours accumulated working
      wanderAccum: 0, // Game-hours since last wander
      lastZone: null,
      prevState: null // For restoring after crisis reaction
    });
  }
  return agentTasks.get(agentId);
}

// ─── Public API ───

/**
 * Initialize AgentAI — call once on game start.
 * Sets up initial task states for all agents.
 */
export function initAgentAI() {
  const agents = useAgentStore.getState().agents;
  agents.forEach((agent) => {
    const task = getTask(agent.id);
    if (agent.assignedZone) {
      task.state = 'walking_to_zone';
      task.lastZone = agent.assignedZone;
    } else {
      task.state = 'idle';
    }
  });
  console.log('[AgentAI] Initialized for', agents.length, 'agents');
}

/**
 * Tick the AI for all agents.
 * Called from GameTicker on each tick with delta game-hours.
 *
 * @param {number} deltaHours - Game-hours elapsed since last tick
 * @param {number} gameHour - Current game hour (0-24)
 */
export function tickAgentAI(deltaHours, gameHour) {
  const agents = useAgentStore.getState().agents;
  const gamePhase = useGameStore.getState().gamePhase;

  // During crisis/saleDay, set all agents to reacting
  if (gamePhase === 'crisis') {
    agents.forEach((agent) => {
      const task = getTask(agent.id);
      if (task.state !== 'reacting') {
        task.prevState = task.state;
        task.state = 'reacting';
      }
    });
    return;
  }

  agents.forEach((agent) => {
    const task = getTask(agent.id);

    // Restore from reacting state
    if (task.state === 'reacting' && gamePhase === 'playing') {
      task.state = task.prevState || 'idle';
      task.prevState = null;
    }

    // Detect zone assignment changes
    if (agent.assignedZone !== task.lastZone) {
      onAssignmentChanged(agent, task);
    }

    // Run per-state logic
    switch (task.state) {
      case 'idle':
        tickIdle(agent, task, deltaHours);
        break;
      case 'walking_to_zone':
        tickWalkingToZone(agent, task);
        break;
      case 'working':
        tickWorking(agent, task, deltaHours);
        break;
      case 'wandering':
        tickWandering(agent, task, deltaHours);
        break;
      default:
        break;
    }
  });

  // Clean up tasks for agents that no longer exist
  const agentIds = new Set(agents.map((a) => a.id));
  agentTasks.forEach((_, id) => {
    if (!agentIds.has(id)) agentTasks.delete(id);
  });
}

// ─── State Handlers ───

function onAssignmentChanged(agent, task) {
  task.lastZone = agent.assignedZone;

  if (agent.assignedZone) {
    // Assigned to a zone — walk there
    const zonePos = ZONE_POSITIONS[agent.assignedZone];
    if (zonePos) {
      // Add slight random offset to avoid stacking
      const offset = { x: (Math.random() - 0.5) * 0.6, z: (Math.random() - 0.5) * 0.6 };
      setAgentTarget(agent.id, zonePos.x + offset.x, zonePos.z + offset.z);
      task.state = 'walking_to_zone';
      task.workAccum = 0;
    }
  } else {
    // Unassigned — recall to center and idle
    recallAgentToCenter(agent.id);
    task.state = 'idle';
    task.wanderAccum = 0;
  }
}

function tickIdle(agent, task, deltaHours) {
  // If assigned to a zone, start walking
  if (agent.assignedZone) {
    onAssignmentChanged(agent, task);
    return;
  }

  // Accumulate wander timer
  task.wanderAccum += deltaHours;

  if (task.wanderAccum >= WANDER_INTERVAL_HOURS) {
    task.wanderAccum = 0;
    // Pick random nearby position
    const angle = Math.random() * Math.PI * 2;
    const dist = Math.random() * WANDER_RADIUS;
    setAgentTarget(agent.id, Math.cos(angle) * dist, Math.sin(angle) * dist);
    task.state = 'wandering';
  }
}

function tickWalkingToZone(agent, task) {
  // Check if arrived (position close to target)
  // The actual arrival is detected by agentMovement.js and applied in IslandScene,
  // which sets animState to 'working'. We mirror that here.
  const pos = getAgentPosition(agent.id);
  const zonePos = ZONE_POSITIONS[agent.assignedZone];

  if (!zonePos) {
    task.state = 'idle';
    return;
  }

  const dx = pos.x - zonePos.x;
  const dz = pos.z - zonePos.z;
  const dist = Math.sqrt(dx * dx + dz * dz);

  if (dist < 1.0) {
    // Close enough — start working
    task.state = 'working';
    task.workAccum = 0;
  }
}

function tickWorking(agent, task, deltaHours) {
  // If unassigned mid-work, go idle
  if (!agent.assignedZone) {
    task.state = 'idle';
    return;
  }

  // Mutinous agents don't work
  if (agent.morale < 20) {
    return;
  }

  // Accumulate work time
  const moraleMultiplier = agent.morale >= 80 ? 1.2 : agent.morale >= 50 ? 1.0 : 0.6;
  task.workAccum += deltaHours * moraleMultiplier;

  // Complete a work cycle
  if (task.workAccum >= WORK_CYCLE_HOURS) {
    task.workAccum -= WORK_CYCLE_HOURS;
    produceResources(agent);
  }
}

function tickWandering(agent, task, deltaHours) {
  // If assigned, redirect to zone
  if (agent.assignedZone) {
    onAssignmentChanged(agent, task);
    return;
  }

  // Check if arrived at wander target (rough check)
  const pos = getAgentPosition(agent.id);
  // Just go back to idle after a bit — agentMovement handles the actual arrival
  task.wanderAccum += deltaHours;
  if (task.wanderAccum >= WANDER_INTERVAL_HOURS * 0.5) {
    task.state = 'idle';
    task.wanderAccum = 0;
  }
}

// ─── Resource Production ───

function produceResources(agent) {
  const zone = agent.assignedZone;
  const resourceType = ZONE_RESOURCES[zone];
  if (!resourceType) return;

  // Calculate output
  const moraleEff = 0.2 + (agent.morale / 100) * 0.8;
  const workEthicBonus = ((agent.traits?.workEthic || 50) / 100) * 0.2;
  const zoneFitBonus = agent.traits?.specialization === zone ? 0.15 : 0;
  const efficiency = Math.max(0.1, moraleEff + workEthicBonus + zoneFitBonus);

  // Get needs multiplier
  const needsMultiplier = useAgentStore.getState().getAgentEfficiencyMultiplier(agent.id);
  const output = Math.max(1, Math.floor(RESOURCE_PER_CYCLE * efficiency * needsMultiplier));

  // Split: 60% agent inventory, 40% global pool
  const agentShare = Math.floor(output * 0.6);
  const globalShare = Math.max(1, output - agentShare);

  useAgentStore.getState().addResourceToInventory(agent.id, resourceType, agentShare);
  useGameStore.getState().addResource(resourceType, globalShare);

  soundManager.play('resourceGain');

  // Occasional field log entry (not every cycle — ~30% chance)
  if (Math.random() < 0.3) {
    const emoji = resourceType === 'wood' ? '🌲' : resourceType === 'wheat' ? '🌾' : '🌊';
    useLogStore.getState().addLogEntry({
      agentId: agent.id,
      agentName: agent.name,
      type: 'resource_production',
      message: `${agent.name} gathered ${output} ${resourceType}`,
      emoji,
      season: useGameStore.getState().season,
      day: useGameStore.getState().day
    });
  }
}

/**
 * Get current AI state for an agent (for debug/UI)
 */
export function getAgentAIState(agentId) {
  return agentTasks.get(agentId) || null;
}

/**
 * Reset all AI state (for new season)
 */
export function resetAgentAI() {
  agentTasks.clear();
}
