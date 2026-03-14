// ============= State Verification Utility =============
// Run this in console to audit all store values
// window.verifyState()

import { useGameStore } from '../store/gameStore';
import { useAgentStore } from '../store/agentStore';
import { useLogStore } from '../store/logStore';

export function verifyState() {
  console.clear();
  console.log('%c🔍 STATE VERIFICATION', 'font-size: 16px; font-weight: bold; color: #22c55e;');
  console.log('Timestamp:', new Date().toISOString());
  console.log('');

  // ===== GAME STORE =====
  console.log('%c📊 GAME STORE', 'font-size: 14px; font-weight: bold; color: #3b82f6;');
  const gameState = useGameStore.getState();

  console.log('Island:');
  console.log('  ✓ islandName:', gameState.islandName);
  console.log('  ✓ islandSeed:', gameState.islandSeed);
  console.log('  ✓ terrain tiles:', gameState.terrain?.length || 0);

  console.log('Season & Time:');
  console.log('  ✓ season:', gameState.season);
  console.log('  ✓ day:', gameState.day);
  console.log('  ✓ timeOfDay:', gameState.timeOfDay);
  console.log('  ✓ gamePhase:', gameState.gamePhase);

  console.log('Resources:');
  console.log('  ✓ wood:', gameState.resources?.wood || 0);
  console.log('  ✓ wheat:', gameState.resources?.wheat || 0);
  console.log('  ✓ hay:', gameState.resources?.hay || 0);
  console.log('  ✓ coins:', gameState.resources?.coins || 0);

  console.log('Market:');
  console.log('  ✓ wood price:', gameState.prices?.wood);
  console.log('  ✓ wheat price:', gameState.prices?.wheat);
  console.log('  ✓ hay price:', gameState.prices?.hay);

  console.log('History:');
  console.log('  ✓ crisisLog entries:', gameState.crisisLog?.length || 0);
  console.log('  ✓ seasonHistory entries:', gameState.seasonHistory?.length || 0);
  console.log('  ✓ riotHistory entries:', gameState.riotHistory?.length || 0);

  console.log('');

  // ===== AGENT STORE =====
  console.log('%c👥 AGENT STORE', 'font-size: 14px; font-weight: bold; color: #6366f1;');
  const agentState = useAgentStore.getState();

  console.log('Agents:');
  console.log('  ✓ Count:', agentState.agents?.length || 0);

  if (agentState.agents && agentState.agents.length > 0) {
    agentState.agents.forEach((agent, idx) => {
      console.log(`  Agent ${idx + 1}:`);
      console.log(`    id: ${agent.id}`);
      console.log(`    name: ${agent.name}`);
      console.log(`    level: ${agent.level}`);
      console.log(`    morale: ${agent.morale}%`);
      console.log(`    assignedZone: ${agent.assignedZone || 'null'}`);
      console.log(`    status: ${agent.status}`);
      console.log(`    traits:`, agent.traits);
      console.log(`    appearance:`, agent.appearance);
    });
  }

  console.log('');

  // ===== LOG STORE =====
  console.log('%c📝 LOG STORE', 'font-size: 14px; font-weight: bold; color: #f59e0b;');
  const logState = useLogStore.getState();

  console.log('Log entries:', logState.entries?.length || 0);
  if (logState.entries && logState.entries.length > 0) {
    console.log('Recent 5:');
    logState.entries.slice(-5).forEach((entry, idx) => {
      console.log(`  ${idx + 1}. [S${entry.season}D${entry.day}] ${entry.agentName}: ${entry.type}`);
      console.log(`     "${entry.message.substring(0, 60)}..."`);
    });
  }

  console.log('');

  // ===== METHOD VERIFICATION =====
  console.log('%c🔧 METHOD VERIFICATION', 'font-size: 14px; font-weight: bold; color: #ec4899;');

  const methods = [
    // Game Store
    ['gameStore.advanceTime', typeof gameState.advanceTime === 'function'],
    ['gameStore.addResource', typeof gameState.addResource === 'function'],
    ['gameStore.setResource', typeof gameState.setResource === 'function'],
    ['gameStore.setGamePhase', typeof gameState.setGamePhase === 'function'],
    ['gameStore.addCrisisToLog', typeof gameState.addCrisisToLog === 'function'],
    ['gameStore.getProfit', typeof gameState.getProfit === 'function'],
    // Agent Store
    ['agentStore.updateMorale', typeof agentState.updateMorale === 'function'],
    ['agentStore.assignAgentToZone', typeof agentState.assignAgentToZone === 'function'],
    ['agentStore.unassignAgent', typeof agentState.unassignAgent === 'function'],
    ['agentStore.fireAgent', typeof agentState.fireAgent === 'function'],
    ['agentStore.getAverageMorale', typeof agentState.getAverageMorale === 'function'],
    // Log Store
    ['logStore.addLogEntry', typeof logState.addLogEntry === 'function'],
  ];

  methods.forEach(([name, exists]) => {
    const icon = exists ? '✓' : '✗';
    const color = exists ? 'color: #22c55e;' : 'color: #ef4444;';
    console.log(`  %c${icon} ${name}`, color);
  });

  console.log('');

  // ===== QUICK TEST =====
  console.log('%c🧪 QUICK TEST', 'font-size: 14px; font-weight: bold; color: #10b981;');
  console.log('Run these commands to test:');
  console.log('  window.testAddResource()');
  console.log('  window.testAdvanceTime()');
  console.log('  window.testUpdateMorale()');
  console.log('  window.testFullGameLoop()');
  console.log('');

  return {
    gameState,
    agentState,
    logState,
    allMethodsValid: methods.every(([_, exists]) => exists)
  };
}

// ===== TEST FUNCTIONS =====

export function testAddResource() {
  console.log('%c🧪 Testing addResource...', 'color: #3b82f6;');
  const before = useGameStore.getState().resources.wood;
  useGameStore.getState().addResource('wood', 10);
  const after = useGameStore.getState().resources.wood;
  const passed = after === before + 10;
  console.log(`  Before: ${before}, After: ${after}, Expected: ${before + 10}`);
  console.log(`  %c${passed ? '✓ PASS' : '✗ FAIL'}`, passed ? 'color: #22c55e;' : 'color: #ef4444;');
  return passed;
}

export function testAdvanceTime() {
  console.log('%c🧪 Testing advanceTime...', 'color: #3b82f6;');
  const beforeDay = useGameStore.getState().day;
  const beforeTime = useGameStore.getState().timeOfDay;

  useGameStore.getState().advanceTime();
  const afterDay = useGameStore.getState().day;
  const afterTime = useGameStore.getState().timeOfDay;

  let passed = false;
  if (beforeTime === 'morning') {
    passed = afterTime === 'evening' && afterDay === beforeDay;
  } else {
    passed = afterTime === 'morning' && afterDay === beforeDay + 1;
  }

  console.log(`  Before: Day ${beforeDay} ${beforeTime}`);
  console.log(`  After: Day ${afterDay} ${afterTime}`);
  console.log(`  %c${passed ? '✓ PASS' : '✗ FAIL'}`, passed ? 'color: #22c55e;' : 'color: #ef4444;');
  return passed;
}

export function testUpdateMorale() {
  console.log('%c🧪 Testing updateMorale...', 'color: #3b82f6;');
  if (!useAgentStore.getState().agents || useAgentStore.getState().agents.length === 0) {
    console.log('  ✗ No agents found');
    return false;
  }

  const agent = useAgentStore.getState().agents[0];
  const beforeMorale = agent.morale;
  useAgentStore.getState().updateMorale(agent.id, 10);
  const afterMorale = useAgentStore.getState().agents[0].morale;
  const passed = afterMorale === beforeMorale + 10;

  console.log(`  Agent: ${agent.name}`);
  console.log(`  Before: ${beforeMorale}%, After: ${afterMorale}%`);
  console.log(`  %c${passed ? '✓ PASS' : '✗ FAIL'}`, passed ? 'color: #22c55e;' : 'color: #ef4444;');
  return passed;
}

export function testFullGameLoop() {
  console.log('%c🧪 Testing Full Game Loop (5 days)...', 'color: #3b82f6;');

  const results = [];
  for (let i = 0; i < 5; i++) {
    const gameState = useGameStore.getState();
    console.log(`  Day ${gameState.day} ${gameState.timeOfDay}: wood=${gameState.resources.wood}`);

    // Assign first agent if unassigned
    const agents = useAgentStore.getState().agents;
    if (agents && agents[0] && !agents[0].assignedZone) {
      useAgentStore.getState().assignAgentToZone(agents[0].id, 'forest');
    }

    // Add resources (simulate work)
    useGameStore.getState().addResource('wood', 5);

    // Advance time
    useGameStore.getState().advanceTime();
    results.push(true);
  }

  const passed = results.length === 5;
  console.log(`  %c${passed ? '✓ PASS' : '✗ FAIL'} — Looped 5 times`, passed ? 'color: #22c55e;' : 'color: #ef4444;');
  return passed;
}

// ===== EXPOSE TO WINDOW =====
if (typeof window !== 'undefined') {
  window.verifyState = verifyState;
  window.testAddResource = testAddResource;
  window.testAdvanceTime = testAdvanceTime;
  window.testUpdateMorale = testUpdateMorale;
  window.testFullGameLoop = testFullGameLoop;
}

export const stateVerification = {
  verifyState,
  testAddResource,
  testAdvanceTime,
  testUpdateMorale,
  testFullGameLoop
};
