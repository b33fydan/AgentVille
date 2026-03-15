# PHASE1-003: Social Relationships & Factions

**Status:** READY FOR DEVELOPMENT
**Priority:** High
**Complexity:** High
**Estimated Timeline:** 4-5 hours

---

## Overview

Build a social layer on top of the economy. Agents form friendships, rivalries, and factions. Factions compete for territory and resources. Agent motivation and job satisfaction now tied to social bonds.

**Outcome:** Agents succeed or fail based on both economic decisions AND social relationships.

---

## Requirements

### 1. Friendship/Rivalry System (New)
- **Relationship types:** friend, neutral, rival, enemy
- **Triggers:**
  - Successful trade → +friendship
  - Successful theft → +rivalry (thief wins)
  - Failed theft → +rivalry (victim wins)
  - Shared alliance → +friendship
  - Boycott → -rivalry → enemy
  - Long cooperation → +friendship
  - Market exploitation (buying cheap, selling high) → rival

- **Effects:**
  - Friends: trade at +20% discount, share resources in crisis
  - Rivals: negotiate at disadvantage (-20% rate), refuse trades
  - Enemies: all-out conflict (theft, sabotage, boycott)

- **Stability:**
  - Relationships drift: +1 or -1 per day without interaction
  - Can't have positive relationship with someone you're boycotting
  - Reputation affects relationship formation (bad agents hard to befriend)

### 2. Faction System (New)
**Factions are groups of agents united by common purpose:**

#### Faction Creation
```
Trigger: 2+ agents in alliance
Faction name: Auto-generated (e.g., "Forest Guild", "Wheat Cartel", "The Outcasts")
Leader: Agent with highest reputation in group
Members: 2-8 agents
```

#### Faction Types
1. **Resource Cartel**
   - Purpose: Control prices of one resource
   - Behavior: Agents hoard that resource, manipulate prices
   - Strength: High control, can crash/boom markets
   - Weakness: Vulnerable to flooding (new supply)

2. **Mutual Defense**
   - Purpose: Protect members from theft/conflict
   - Behavior: Guard each other, retaliate against attackers
   - Strength: Safe trading environment
   - Weakness: Defensive (don't accumulate wealth)

3. **Production Guild**
   - Purpose: Specialize in one resource zone
   - Behavior: All work in same zone (high efficiency)
   - Strength: Consistent production, low competition
   - Weakness: Vulnerable to price crashes

4. **Scavenger Band**
   - Purpose: Survive through theft and trade
   - Behavior: Steal from others, trade stolen goods
   - Strength: High reward (stolen resources free)
   - Weakness: High conflict, reputation damage

#### Faction Benefits
- **Shared treasury:** Members pool coins for group purchases
- **Bulk trading:** Faction sells to market in large batches (price bonuses)
- **Territory control:** Faction claims zone, members get +15% output there
- **Cooperative hoarding:** Can protect large inventories together

#### Faction Wars
```
Trigger: Factions compete for same zone or resources
Conflict types:
  - Territory dispute (two factions claim same forest)
  - Market manipulation (undercut each other's prices)
  - Recruitment war (poach members)
  - Sabotage (steal from rival faction)

Resolution:
  - Negotiation (faction leaders trade, make peace)
  - Economic war (price dumping, bankruptcy)
  - Theft war (steal faction treasury)
  - Exodus (members leave weaker faction)
```

### 3. Agent Motivation Enhancement
**Job satisfaction now tied to social factors:**

```javascript
jobSatisfaction = (
  morale * 0.3 +
  friendCount * 10 +
  factionBonus * 0.2 +
  leadershipBonus * 5 +
  reputation * 0.1
) / 100

// If satisfaction < 30%, agent considers leaving
// If satisfaction > 80%, agent is productive (+20% work output)
```

**Bonuses:**
- Work in faction territory: +15% output
- Work alongside friend: +10% output
- Lead faction: +25% morale
- Protect faction: accept lower wages

### 4. Social Events

#### Ambient Interactions (every 2-3 days)
```
"Agent A and Agent B are chatting about harvest"
"Agent X compliments Agent Y's work"
"Agent Z complains about Agent W to Agent V"
```

Effects:
- +friendship if compliment
- +rivalry if complaint (witness gains bad opinion too)
- Can spread rumors (-reputation if false)

#### Celebration Events
```
Trigger: Agent reaches high morale, faction achieves goal, economic boom
Effects:
  - +5 friendship to all nearby agents
  - Shared celebration (morale boost +10)
  - New agent may join faction
```

#### Crisis Events
```
Trigger: Economic collapse, agent starving, agent injured
Effects:
  - Friends offer emergency resources
  - Rivals abandon (or betray)
  - Enemies attack
  - Faction may rescue member
```

### 5. Reputation System (Enhancement)

**Current:** 0-100 scale, affects trade willingness

**Enhanced:**
- **Public reputation:** Everyone knows your history (visible to all)
- **Reputation sources:**
  - Successful trades: +1 per 10 coins traded
  - Theft: -10 per theft attempt, +5 per successful steal (social)
  - Leadership: +5 per faction member following you
  - Betrayal: -20 per betrayed ally
  - Generosity: +3 per gift to agent in need
  - Hoarding: -5 if sitting on resources while others starve

- **Effects:**
  - High rep (>70): Agents want to be your friend, join your faction
  - Low rep (<30): Agents refuse to trade, organize against you
  - Zero rep (0): Agents attack on sight, total ostracism

---

## Implementation Tasks

### 1. New Files

**src/utils/socialSystem.js** (500 lines)
```javascript
class SocialGraph {
  // Manages all relationships between agents
  getRelationship(agentA, agentB) → { type, strength, history }
  addInteraction(agentA, agentB, type) → updates relationship
  getAgentNetwork(agentId) → { friends, rivals, neutrals, enemies }
}

class FactionEngine {
  // Manages faction creation, membership, territory, wars
  createFaction(agents, type) → faction
  addMember(factionId, agentId)
  removeMember(factionId, agentId)
  getFactionTreasury(factionId) → coins
  startFactionWar(faction1, faction2) → war
  simulateWar(war) → resolution
}

class AmbientSocial {
  // Generates social events and interactions
  generateInteraction(agent) → { text, emoji, effects }
  spreadRumor(agent, target) → affects reputation
  celebrateEvent(agents) → morale boost
}
```

**src/utils/factionConflict.js** (400 lines)
```javascript
class FactionWar {
  // Handles faction conflicts (market, territory, recruitment)
  engage(faction1, faction2) → conflict state
  applyCosts() → treasury damage, member casualties
  resolve() → winner, peace, merger, or extinction
}
```

### 2. Modified Files

**src/store/agentStore.js**
```javascript
// Add to agent:
relationships: {
  [agentId]: {
    type: 'friend'|'neutral'|'rival'|'enemy',
    strength: -100..100,  // How strong the relationship
    interactionCount: number,
    lastInteraction: timestamp,
    history: [ { type, day, impact } ]  // Relationship events
  }
},
factionId: string || null,  // Which faction agent belongs to
leadershipLevel: number,    // How good a leader (0=member, 100=founder)
publicReputation: number,   // Global reputation (visible to all)
socialMotivation: number,   // 0-100: satisfaction with social situation
```

**src/utils/advanceDayHandler.js**
```javascript
// In day advance:
1. Generate ambient social interactions
2. Simulate faction conflicts if any exist
3. Update social motivations
4. Check for faction recruitment/exodus
5. Apply social morale bonuses/penalties
```

**src/utils/agentDecisions.js**
```javascript
// Enhance evaluatePriority() to consider:
- Is my faction leader in trouble? → Help them (even risky)
- Are my friends struggling? → Share resources
- Are my rivals thriving? → Work harder to outpace
- Is my reputation tanking? → Do good deeds to recover

// New decision type: SOCIAL_ACTION
- 'protect_friend'
- 'betray_rival'
- 'join_faction'
- 'leave_faction'
```

**src/components/ui/FieldLog.jsx**
```jsx
// Add styling for social events:
- social_interaction (blue)
- faction_formed (green)
- faction_war (red)
- reputation_change (purple)
- ambush/betrayal (dark red)
```

**src/components/ui/SeasonHUD.jsx**
```jsx
// Add section showing:
- Active factions (if any)
- Agent's faction status
- Relationship summary (X friends, Y rivals, Z enemies)
- Personal reputation score
```

**src/components/ui/AgentPanel.jsx**
```jsx
// Show when clicking on agent:
- Friends/rivals/enemies (clickable, shows relationships)
- Faction affiliation and rank
- Reputation score and history
- Recent social interactions
```

### 3. New Components

**src/components/ui/FactionPanel.jsx**
```jsx
// Floating panel showing:
- Faction name, leader, members
- Shared treasury, production stats
- Active wars/conflicts
- Territory claims
- Button to join (if not member)
```

**src/components/ui/SocialGraph.jsx**
```jsx
// Visualization showing:
- Agents as nodes
- Relationships as edges (green=friend, red=rival)
- Factions as clusters
- Click to explore relationships
```

---

## Testing Strategy

### Unit Tests
```javascript
// test-social-system.js
✓ Relationship formation (trade → friendship)
✓ Rivalry escalation (theft → enemies)
✓ Faction creation (2+ agents → faction)
✓ Faction benefits (territory control, treasury)
✓ Faction wars (resolution, casualties)
✓ Reputation changes (theft, betrayal, leadership)
✓ Ambient interactions (rumors, celebrations)
```

### Integration Tests
```javascript
// test-full-season-social.js
✓ Full 7-day season with factions
✓ Agents forming alliances
✓ Factions competing for zone
✓ Reputation affecting trades
✓ Social motivation affecting work output
✓ Faction member leaving/joining
✓ Crisis triggering social events
```

### Scenario Testing
```
Scenario 1: Cooperative Season
- 3 agents form faction naturally
- Share territory, boom together
- Even distribution of wealth

Scenario 2: Conflict Season
- 2 agents form cartel, exclude 1
- Cartel manipulates wheat prices
- Outsider steals, cartel retaliates
- Civil war (faction war)

Scenario 3: Social Collapse
- Agent betrays faction
- Reputation crashes
- Friends stop trading
- Agent forced to leave/starve
```

---

## Acceptance Criteria

- [ ] Friendship/rivalry system functional
- [ ] Factions can be created and managed
- [ ] Faction territory control affects production
- [ ] Faction wars create conflict
- [ ] Social motivation affects job output
- [ ] Ambient interactions generate naturally
- [ ] Reputation system expanded and visible
- [ ] Full 7-day season playable with factions
- [ ] No console errors
- [ ] 60 FPS maintained
- [ ] UI panels show social status
- [ ] Relationship graph visualizable

---

## Gameplay Examples

### Example 1: Friendly Cartel (Positive Outcome)
```
Day 1: Forest agent and Wetlands agent trade regularly (+friendship)
Day 3: Plains agent joins trades (now 3-agent friend group)
Day 4: Agents form "The Producers" faction
       Leader: Forest agent (highest reputation)
       Benefit: +15% output when working in faction territory
Day 5-7: Agents coordinate work, control wheat market
       Result: All three prosper, faction wealth = $2000
```

### Example 2: Economic War (Conflict Outcome)
```
Day 1: Plains agent and Wetlands agent form "Wheat Cartel"
       Forest agent excluded (old rivalry)
Day 2: Cartel hoards wheat, prices spike to $15
Day 3: Forest agent desperate, steals wheat from Wetlands
Day 4: Wetlands retaliates, burns forest resources
       War declared!
Day 5: Cartel cuts off forest agent completely (boycott + theft war)
Day 6: Forest agent recruits new agent (hire), rebuilds
Day 7: Stalemate - forest controls forest zone, cartel controls plains
       Result: Divided island, economic tension
```

### Example 3: Reputation Recovery (Redemption Arc)
```
Day 1: Shady agent steals from everyone (reputation = 10)
Day 2: Gets caught, public shame
Day 3-5: Desperately tries to help (give resources to starving agents)
       Slowly rebuilds reputation (+5/day)
Day 6: Reputation reaches 40, agent offers apology gifts
Day 7: One agent accepts friend request, reputation at 55
       Next season: Can start fresh with some allies
```

---

## Performance Considerations

- **Relationship matrix:** O(n²) agents, but sparse (not all relationships used)
- **Faction wars:** O(n) simulation per war (not many concurrent wars)
- **Ambient interactions:** O(n) agents per day (generate 1-2 interactions)
- **Reputation updates:** O(1) per agent
- **Social graph visualization:** Pre-computed, update on day change

**Total overhead:** <2% of frame budget

---

## Phase 1 Timeline

| Task | Status | Timeline | Impact |
|------|--------|----------|--------|
| Task 1: Autonomous Needs | ✅ Complete | 3 hours | Foundation |
| Task 2: Economy & Trading | ✅ Complete | 2.5 hours | Emergent gameplay |
| **Task 3: Social & Factions** | 📋 Ready | **4-5 hours** | **Unpredictable outcomes** |

---

## Vision: End of Phase 1

At the end of Phase 1, AgentVille will be a fully **emergent economic + social simulation** where:

1. **Every season is different** (economy, conflicts, faction dynamics)
2. **Success requires both skills:** Economic acumen + social diplomacy
3. **Multiple viable strategies:** Cartel, mutual defense, production, scavenger
4. **Natural storytelling:** "This season, the farmers formed a cartel and starved the forest workers"
5. **Player decisions matter:** Who you hire, where you assign them, shapes faction dynamics

---

## Next Steps (After Phase 1)

- **Phase 2:** Diplomacy & Trade Routes (agents travel, negotiate)
- **Phase 3:** Leadership & Rebellion (agents challenge authority, coups)
- **Phase 4:** Culture & Legacy (agents pass down genes, history, culture)

---

Prepared by: Subagent edd0e7c3-ef59-4e95-9062-69a2bc10a4eb
Date: 2026-03-14 22:35 EDT
Ready for: Next development cycle
