// ============= AGENT TRADING SYSTEM =============
// Price discovery, trading engine, barter logic

import { useAgentStore } from '../store/agentStore';
import { useLogStore } from '../store/logStore';

/**
 * TradeMarket: Central trading hub with supply/demand pricing
 */
export class TradeMarket {
  constructor() {
    this.basePrices = {
      wood: 2,
      wheat: 5,
      hay: 3
    };

    // Supply tracking (per resource)
    this.supply = {
      wood: 0,
      wheat: 0,
      hay: 0
    };

    // Price history for trends
    this.priceHistory = {
      wood: [2],
      wheat: [5],
      hay: [3]
    };

    // Trading log
    this.trades = [];
  }

  /**
   * Calculate supply across all agents
   */
  calculateSupply(agents) {
    this.supply = {
      wood: 0,
      wheat: 0,
      hay: 0
    };

    agents.forEach((agent) => {
      this.supply.wood += agent.inventory?.wood || 0;
      this.supply.wheat += agent.inventory?.wheat || 0;
      this.supply.hay += agent.inventory?.hay || 0;
    });

    return this.supply;
  }

  /**
   * Calculate current prices based on supply/demand
   * Formula: basePrice * (1 + (demandLevel / 100))
   * Where demandLevel = (targetSupply - currentSupply) / targetSupply * 100
   */
  calculatePrices(agents, targetSupply = 100) {
    this.calculateSupply(agents);

    const prices = {};
    const resourceTypes = ['wood', 'wheat', 'hay'];

    resourceTypes.forEach((resource) => {
      const currentSupply = this.supply[resource];
      const shortage = Math.max(-100, Math.min(100, ((targetSupply - currentSupply) / targetSupply) * 100));
      
      // Price multiplier: -100% shortage = 0.5x price (oversupply)
      //                    0% shortage = 1.0x price (balanced)
      //                  +100% shortage = 2.0x price (severe scarcity)
      const multiplier = 1 + (shortage / 200); // Softer curve
      prices[resource] = Math.max(0.5, this.basePrices[resource] * multiplier);
    });

    // Track history for trends
    Object.keys(prices).forEach((resource) => {
      if (!this.priceHistory[resource]) this.priceHistory[resource] = [];
      this.priceHistory[resource].push(prices[resource]);
      
      // Keep last 20 days
      if (this.priceHistory[resource].length > 20) {
        this.priceHistory[resource].shift();
      }
    });

    return prices;
  }

  /**
   * Get price trend (up/down/stable)
   */
  getPriceTrend(resource) {
    const history = this.priceHistory[resource];
    if (history.length < 3) return 'stable';

    const prev = history[history.length - 2];
    const current = history[history.length - 1];

    if (current > prev * 1.1) return 'up';
    if (current < prev * 0.9) return 'down';
    return 'stable';
  }

  /**
   * Execute direct barter trade between two agents
   * Returns: { success, reason, tradeLogEntry }
   */
  executeBarter(sellerAgent, buyerAgent, sellerResource, sellerAmount, buyerResource, buyerAmount, gameState) {
    const agentStore = useAgentStore.getState();
    const logStore = useLogStore.getState();

    // Check if buyer wants to trade with seller
    if (buyerAgent.boycottList?.includes(sellerAgent.id)) {
      return {
        success: false,
        reason: `${buyerAgent.name} is boycotting ${sellerAgent.name}`,
        tradeLogEntry: null
      };
    }

    // Check inventory
    const sellerHas = (sellerAgent.inventory[sellerResource] || 0) >= sellerAmount;
    const buyerHas = (buyerAgent.inventory[buyerResource] || 0) >= buyerAmount;

    if (!sellerHas || !buyerHas) {
      return {
        success: false,
        reason: 'Insufficient inventory',
        tradeLogEntry: null
      };
    }

    // Execute trade
    agentStore.removeResourceFromInventory(sellerAgent.id, sellerResource, sellerAmount);
    agentStore.addResourceToInventory(sellerAgent.id, buyerResource, buyerAmount);

    agentStore.removeResourceFromInventory(buyerAgent.id, buyerResource, buyerAmount);
    agentStore.addResourceToInventory(buyerAgent.id, sellerResource, sellerAmount);

    // Update trust
    agentStore.updateAgentRelationship(sellerAgent.id, buyerAgent.id, 5);
    agentStore.updateAgentRelationship(buyerAgent.id, sellerAgent.id, 5);

    // Record trade
    agentStore.recordTrade(sellerAgent.id, true, sellerResource, sellerAmount, buyerAmount);
    agentStore.recordTrade(buyerAgent.id, true, buyerResource, buyerAmount, sellerAmount);

    // Log entry
    const entry = {
      id: `trade-${Date.now()}`,
      agentName1: sellerAgent.name,
      agentName2: buyerAgent.name,
      type: 'trade',
      message: `${sellerAgent.name} traded ${sellerAmount} ${sellerResource} to ${buyerAgent.name} for ${buyerAmount} ${buyerResource}`,
      emoji: '🤝',
      season: gameState?.season || 1,
      day: gameState?.day || 1,
      tradeDetails: {
        seller: sellerAgent.name,
        buyer: buyerAgent.name,
        itemsGiven: { [sellerResource]: sellerAmount },
        itemsReceived: { [buyerResource]: buyerAmount }
      }
    };

    logStore.addLogEntry(entry);

    return {
      success: true,
      reason: 'Trade successful',
      tradeLogEntry: entry
    };
  }

  /**
   * Execute market trade (agent buys from market at current price)
   * Returns: { success, reason, tradeLogEntry }
   */
  executeMarketTrade(agent, buyResource, buyAmount, prices, gameState) {
    const agentStore = useAgentStore.getState();
    const logStore = useLogStore.getState();

    const costInCoins = Math.ceil(prices[buyResource] * buyAmount);
    const agentCoins = agent.inventory?.coins || 0;

    if (agentCoins < costInCoins) {
      return {
        success: false,
        reason: `${agent.name} needs ${costInCoins} coins but only has ${agentCoins}`,
        tradeLogEntry: null
      };
    }

    // Execute trade
    agentStore.removeResourceFromInventory(agent.id, 'coins', costInCoins);
    agentStore.addResourceToInventory(agent.id, buyResource, buyAmount);

    // Record trade
    agentStore.recordTrade(agent.id, true, buyResource, buyAmount, -costInCoins);

    // Log entry
    const entry = {
      id: `market-trade-${Date.now()}`,
      agentId: agent.id,
      agentName: agent.name,
      type: 'market_trade',
      message: `${agent.name} bought ${buyAmount} ${buyResource} from market for ${costInCoins} coins (${prices[buyResource].toFixed(2)}/unit)`,
      emoji: '🏪',
      season: gameState?.season || 1,
      day: gameState?.day || 1
    };

    logStore.addLogEntry(entry);

    return {
      success: true,
      reason: 'Market purchase successful',
      tradeLogEntry: entry
    };
  }

  /**
   * Execute market sale (agent sells to market at current price)
   * Returns: { success, reason, tradeLogEntry }
   */
  executeMarketSale(agent, sellResource, sellAmount, prices, gameState) {
    const agentStore = useAgentStore.getState();
    const logStore = useLogStore.getState();

    const earningsInCoins = Math.floor(prices[sellResource] * sellAmount);
    const agentHas = (agent.inventory[sellResource] || 0) >= sellAmount;

    if (!agentHas) {
      return {
        success: false,
        reason: `${agent.name} doesn't have ${sellAmount} ${sellResource}`,
        tradeLogEntry: null
      };
    }

    // Execute sale
    agentStore.removeResourceFromInventory(agent.id, sellResource, sellAmount);
    agentStore.addResourceToInventory(agent.id, 'coins', earningsInCoins);

    // Record trade
    agentStore.recordTrade(agent.id, true, sellResource, -sellAmount, earningsInCoins);

    // Log entry
    const entry = {
      id: `market-sale-${Date.now()}`,
      agentId: agent.id,
      agentName: agent.name,
      type: 'market_sale',
      message: `${agent.name} sold ${sellAmount} ${sellResource} to market for ${earningsInCoins} coins (${prices[sellResource].toFixed(2)}/unit)`,
      emoji: '💰',
      season: gameState?.season || 1,
      day: gameState?.day || 1
    };

    logStore.addLogEntry(entry);

    return {
      success: true,
      reason: 'Market sale successful',
      tradeLogEntry: entry
    };
  }

  /**
   * Determine if agent will trade with another (based on reputation/trust)
   */
  willTrade(agent1, agent2) {
    // Check boycott
    if (agent1.boycottList?.includes(agent2.id)) {
      return false;
    }

    // Check trust relationship
    const trust = agent1.relationships?.[agent2.id]?.trust || 0;
    const reputation = agent2.reputation || 50;

    // Probability to trade decreases with low trust/reputation
    const willingness = (trust + 100) / 200 * (reputation / 100); // 0-1
    return Math.random() < willingness;
  }

  /**
   * Get current prices
   */
  getPrices() {
    return {
      wood: this.priceHistory.wood[this.priceHistory.wood.length - 1],
      wheat: this.priceHistory.wheat[this.priceHistory.wheat.length - 1],
      hay: this.priceHistory.hay[this.priceHistory.hay.length - 1]
    };
  }
}

// ============= SINGLETON =============
export const tradeMarket = new TradeMarket();

/**
 * Calculate negotiation outcome between two agents
 * Returns fair exchange ratio based on their negotiation skills
 */
export function negotiateExchange(agent1, agent2, resource1, resource2, prices) {
  // Base fair ratio
  const fairRatio = prices[resource1] / prices[resource2];

  // Negotiation skill based on traits
  const agent1Skill = (agent1.traits?.risk || 50) / 100; // Risk-takers negotiate better
  const agent2Skill = (agent2.traits?.risk || 50) / 100;

  // Outcome: closer to skill difference = better negotiation
  const skillDifference = agent1Skill - agent2Skill;
  const outcome = fairRatio * (1 + skillDifference * 0.2); // ±20% swing

  return outcome;
}
