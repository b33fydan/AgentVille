// ============= ECONOMIC ENGINE =============
// Supply/demand tracking, inflation, economic cycles, collapse detection

import { useGameStore } from '../store/gameStore';
import { useAgentStore } from '../store/agentStore';
import { useLogStore } from '../store/logStore';
import { tradeMarket } from './agentTrading';

export class EconomicEngine {
  constructor() {
    this.economicState = {
      inflationRate: 0, // Percentage change in price level
      totalWealth: 0,
      resourceScarcity: { wood: 0, wheat: 0, hay: 0 }, // -100 (oversupply) to +100 (critical shortage)
      economicHealth: 100, // 0-100, determines collapse risk
      isCollapsing: false,
      cyclePhase: 'stable' // 'stable', 'boom', 'bust'
    };

    // History for trend analysis
    this.priceHistory = { wood: [], wheat: [], hay: [] };
    this.wealthHistory = [];
    this.healthHistory = [];
  }

  /**
   * Update economic state each day
   * Calculates supply/demand, adjusts prices, detects collapse
   */
  updateEconomy(agents, gameState) {
    const logStore = useLogStore.getState();

    // Calculate total wealth
    this.economicState.totalWealth = agents.reduce((sum, agent) => {
      const prices = tradeMarket.getPrices();
      return sum + (
        (agent.inventory?.wood || 0) * prices.wood +
        (agent.inventory?.wheat || 0) * prices.wheat +
        (agent.inventory?.hay || 0) * prices.hay +
        (agent.inventory?.coins || 0)
      );
    }, 0);

    // Calculate resource scarcity
    this.calculateScarcity(agents);

    // Update prices based on supply/demand
    const prices = tradeMarket.calculatePrices(agents, 300); // Target supply: 300 units per resource

    // Detect inflation/deflation
    this.calculateInflation(prices);

    // Detect economic cycle
    this.detectEconomicCycle(agents);

    // Check for collapse
    this.checkForCollapse(agents, gameState, logStore);

    // Track history
    this.recordHistory(prices);

    return {
      prices,
      scarcity: this.economicState.resourceScarcity,
      health: this.economicState.economicHealth,
      inflationRate: this.economicState.inflationRate,
      cyclePhase: this.economicState.cyclePhase
    };
  }

  /**
   * Calculate resource scarcity (-100 to +100)
   * -100 = massive oversupply, +100 = critical shortage
   */
  calculateScarcity(agents) {
    const targetPerAgent = 100; // Target: each agent has 100 units per resource
    const totalAgents = Math.max(1, agents.length);
    const targetTotal = targetPerAgent * totalAgents;

    // Calculate actual supply
    const supply = {
      wood: agents.reduce((sum, a) => sum + (a.inventory?.wood || 0), 0),
      wheat: agents.reduce((sum, a) => sum + (a.inventory?.wheat || 0), 0),
      hay: agents.reduce((sum, a) => sum + (a.inventory?.hay || 0), 0)
    };

    // Scarcity: 0 = perfect, 100 = critical shortage, -100 = massive oversupply
    Object.keys(supply).forEach((resource) => {
      const shortage = (targetTotal - supply[resource]) / targetTotal * 100;
      this.economicState.resourceScarcity[resource] = Math.max(-100, Math.min(100, shortage));
    });
  }

  /**
   * Calculate inflation rate from price trends
   */
  calculateInflation(prices) {
    if (this.priceHistory.wood.length < 2) {
      this.economicState.inflationRate = 0;
      return;
    }

    const prevWood = this.priceHistory.wood[this.priceHistory.wood.length - 1];
    const currWood = prices.wood;
    const woodInflation = ((currWood - prevWood) / prevWood) * 100;

    // Average with other resources
    const prevWheat = this.priceHistory.wheat[this.priceHistory.wheat.length - 1] || prices.wheat;
    const currWheat = prices.wheat;
    const wheatInflation = ((currWheat - prevWheat) / prevWheat) * 100;

    const prevHay = this.priceHistory.hay[this.priceHistory.hay.length - 1] || prices.hay;
    const currHay = prices.hay;
    const hayInflation = ((currHay - prevHay) / prevHay) * 100;

    this.economicState.inflationRate = (woodInflation + wheatInflation + hayInflation) / 3;
  }

  /**
   * Detect economic cycle (boom/bust/stable)
   * Based on inflation rate and wealth trend
   */
  detectEconomicCycle(agents) {
    const inflation = this.economicState.inflationRate;
    const avgWealth = this.economicState.totalWealth / Math.max(1, agents.length);

    if (this.wealthHistory.length > 2) {
      const prevWealth = this.wealthHistory[this.wealthHistory.length - 2];
      const wealthGrowth = ((avgWealth - prevWealth) / prevWealth) * 100;

      if (inflation > 5 && wealthGrowth > 5) {
        this.economicState.cyclePhase = 'boom'; // Prices rising, wealth growing
      } else if (inflation < -5 || wealthGrowth < -5) {
        this.economicState.cyclePhase = 'bust'; // Prices falling or wealth shrinking
      } else {
        this.economicState.cyclePhase = 'stable';
      }
    } else {
      this.economicState.cyclePhase = 'stable';
    }
  }

  /**
   * Check for economic collapse
   * Triggered when: critical food shortage, negative wealth, mass unemployment
   */
  checkForCollapse(agents, gameState, logStore) {
    const wheatScarcity = this.economicState.resourceScarcity.wheat;
    const avgMorale = agents.reduce((sum, a) => sum + a.morale, 0) / Math.max(1, agents.length);
    const unemployed = agents.filter((a) => !a.assignedZone).length;
    const unemploymentRate = unemployed / Math.max(1, agents.length);

    // Health score (0-100)
    let health = 100;

    // Critical food shortage (-40 points)
    if (wheatScarcity > 75) {
      health -= 40;
      if (logStore && Math.random() < 0.5) {
        logStore.addLogEntry({
          id: `economy-alert-${Date.now()}`,
          agentName: 'System',
          type: 'economy_alert',
          message: '🚨 CRITICAL: Wheat shortage! Agents are starving!',
          emoji: '🚨',
          season: gameState.season,
          day: gameState.day
        });
      }
    } else if (wheatScarcity > 50) {
      health -= 20;
    }

    // Low morale (-30 points)
    if (avgMorale < 30) {
      health -= 30;
    } else if (avgMorale < 50) {
      health -= 15;
    }

    // High unemployment (-25 points)
    if (unemploymentRate > 0.7) {
      health -= 25;
    } else if (unemploymentRate > 0.5) {
      health -= 10;
    }

    // Severe inflation (-20 points)
    if (this.economicState.inflationRate > 20) {
      health -= 20;
    }

    // Deflation (goods worthless) (-20 points)
    if (this.economicState.inflationRate < -20) {
      health -= 20;
    }

    this.economicState.economicHealth = Math.max(0, Math.min(100, health));

    // Collapse threshold: health < 20
    if (this.economicState.economicHealth < 20) {
      this.economicState.isCollapsing = true;

      if (logStore) {
        logStore.addLogEntry({
          id: `economy-collapse-${Date.now()}`,
          agentName: 'System',
          type: 'economy_collapse',
          message: '💀 ECONOMIC COLLAPSE: The economy is in freefall!',
          emoji: '💀',
          season: gameState.season,
          day: gameState.day
        });
      }
    }
  }

  /**
   * Apply random economic event (crop failure, bountiful harvest, market crash, etc.)
   */
  applyRandomEvent(agents, gameState, logStore) {
    const eventChance = Math.random();
    const event = {
      triggered: false,
      type: '',
      message: '',
      priceMultiplier: {}
    };

    // 20% chance of event each day
    if (eventChance > 0.8) {
      const eventType = Math.random();

      if (eventType < 0.3) {
        // Crop failure: wheat prices spike
        event.triggered = true;
        event.type = 'crop_failure';
        event.message = '🌾 Crop failure! Wheat prices spike to 2x!';
        event.priceMultiplier = { wheat: 2.0 };

        // Affected agents lose half their wheat
        agents.forEach((agent) => {
          const loss = Math.floor((agent.inventory?.wheat || 0) * 0.5);
          if (loss > 0) {
            const agentStore = useAgentStore.getState();
            agentStore.removeResourceFromInventory(agent.id, 'wheat', loss);
            agentStore.updateMorale(agent.id, -10);
          }
        });
      } else if (eventType < 0.6) {
        // Bountiful harvest: wheat prices crash
        event.triggered = true;
        event.type = 'bountiful_harvest';
        event.message = '🌾 Bountiful harvest! Wheat prices crash to 0.5x!';
        event.priceMultiplier = { wheat: 0.5 };

        // All agents gain wheat
        agents.forEach((agent) => {
          const agentStore = useAgentStore.getState();
          agentStore.addResourceToInventory(agent.id, 'wheat', 20);
          agentStore.updateMorale(agent.id, 5);
        });
      } else if (eventType < 0.8) {
        // Market crash: all prices drop
        event.triggered = true;
        event.type = 'market_crash';
        event.message = '📉 Market crash! All prices drop 40%!';
        event.priceMultiplier = { wood: 0.6, wheat: 0.6, hay: 0.6 };

        agents.forEach((agent) => {
          const agentStore = useAgentStore.getState();
          agentStore.updateMorale(agent.id, -15);
        });
      } else {
        // Economic boom: all prices rise
        event.triggered = true;
        event.type = 'economic_boom';
        event.message = '📈 Economic boom! All prices surge 40%!';
        event.priceMultiplier = { wood: 1.4, wheat: 1.4, hay: 1.4 };

        agents.forEach((agent) => {
          const agentStore = useAgentStore.getState();
          agentStore.updateMorale(agent.id, 10);
        });
      }

      if (event.triggered && logStore) {
        logStore.addLogEntry({
          id: `economic-event-${Date.now()}`,
          agentName: 'System',
          type: 'economic_event',
          message: event.message,
          emoji: '📊',
          season: gameState.season,
          day: gameState.day
        });
      }
    }

    return event;
  }

  /**
   * Record price and wealth history
   */
  recordHistory(prices) {
    this.priceHistory.wood.push(prices.wood);
    this.priceHistory.wheat.push(prices.wheat);
    this.priceHistory.hay.push(prices.hay);
    this.wealthHistory.push(this.economicState.totalWealth);
    this.healthHistory.push(this.economicState.economicHealth);

    // Keep last 20 days
    const maxDays = 20;
    if (this.priceHistory.wood.length > maxDays) {
      this.priceHistory.wood.shift();
      this.priceHistory.wheat.shift();
      this.priceHistory.hay.shift();
      this.wealthHistory.shift();
      this.healthHistory.shift();
    }
  }

  /**
   * Get economic summary
   */
  getSummary() {
    return {
      health: this.economicState.economicHealth,
      inflationRate: this.economicState.inflationRate,
      cyclePhase: this.economicState.cyclePhase,
      isCollapsing: this.economicState.isCollapsing,
      totalWealth: this.economicState.totalWealth,
      scarcity: this.economicState.resourceScarcity,
      priceHistory: this.priceHistory
    };
  }
}

// ============= SINGLETON =============
export const economicEngine = new EconomicEngine();
