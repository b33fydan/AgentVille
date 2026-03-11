# AgentVille Phase 2A + 2B — Crisis Engine + Agent Personality

**Target:** Build the "soul" of the game — feedback loops where every action matters.
**Timeline:** 2 weeks of focused work (6-8 hours/day)
**Foundation:** Phase 0 + 1 complete, all stores/scene rendering ready

---

## PHASE 2A: Crisis Engine (Full Integration)

### Overview
Currently: Crises exist, choices are made, outcomes apply morale deltas.
Target: Crises feel **personal**, agent **reactions** differ, **outcomes ripple** through the season.

---

### AV-008: Wire Crisis System (Full) — 6-8 hours

**Objective:** Crisis engine becomes the heartbeat of gameplay. 20+ templates, Claude enrichment, proper outcome propagation.

#### Architecture

**Crisis Queue System** (new in crisisEngine.js)

```javascript
class CrisisQueue {
  constructor(agentStore, gameStore) {
    this.pending = []; // Queue of crises waiting decision
    this.resolved = []; // History this season
    this.maxCrisisPerDay = 2; // Cap concurrent crises
    this.lastTriggerTime = 0;
  }

  // Called on day advance / time of day change
  checkTrigger(season, day, timeOfDay) {
    const triggerChance = this.calculateTriggerChance(season, day);
    if (Math.random() < triggerChance && this.pending.length < this.maxCrisisPerDay) {
      const crisis = generateCrisis(agentStore, gameStore);
      this.pending.push(crisis);
      return crisis;
    }
    return null;
  }

  // Calculate probability based on game state
  calculateTriggerChance(season, day) {
    // Days 2-5: 30% chance per day
    // Day 6: 60% chance (crunch time)
    // Day 7: 0% (sale day, too late)
    if (day <= 2 || day === 7) return 0.1;
    if (day === 6) return 0.6;
    return 0.3;
  }

  resolveCrisis(crisisId, choiceIndex) {
    const crisis = this.pending.find(c => c.id === crisisId);
    if (!crisis) return null;

    const outcome = resolveCrisis(crisis, choiceIndex);
    this.pending = this.pending.filter(c => c.id !== crisisId);
    this.resolved.push({ crisis, choice: choiceIndex, outcome, day: gameStore.day });

    // Apply consequences
    applyOutcome(outcome);

    return outcome;
  }
}
```

**Crisis Templates** (expand from 8 → 20+)

Currently have:
- Pest outbreaks
- Weather events
- Agent morale issues
- Resource scarcity

Add (3-5 per zone type):

**Forest Zone:**
- `forest_drought` — Reduced wood output, agents thirsty (-morale unless watered)
- `forest_wildfire` — Risk losing workers, heavy resource burn
- `forest_poachers` — External threat, defend or lose materials
- `forest_disease` — Trees getting sick, affect long-term yields
- `forest_logging_accident` — Worker injury, legal liability

**Plains Zone:**
- `plains_locusts` — Swarms consuming crops (classic)
- `plains_blight` — Plant disease spreads
- `plains_drought` — No water, resources tank
- `plains_market_crash` — Wheat prices plummet (timing crisis)
- `plains_seed_shortage` — Can't plant next cycle

**Wetlands Zone:**
- `wetlands_flooding` — Water overflows, loss of productivity
- `wetlands_swamp_fever` — Workers get sick
- `wetlands_predators` — Creatures threaten agents
- `wetlands_pollution` — External contamination
- `wetlands_migration` — Migratory animals disrupt work

**Cross-Zone:**
- `bandits_raid` — External theft, resources + morale hit
- `agent_revolt` — Worker demands (pay raise, better conditions)
- `inspector_visit` — Government check (ACA audit, penalties)
- `injury_accident` — Random worker gets hurt

**Crisis Structure** (enhanced)

```javascript
{
  id: 'crisis-uuid',
  type: 'plains_locusts',
  title: 'Locust Swarm Incoming',
  baseDescription: 'A massive swarm has been spotted approaching your fields.',
  zone: 'plains', // Can be null for cross-zone crises
  affectedAgent: agentId || null, // Can be null for area-wide
  severity: 1-3, // 1=minor, 2=major, 3=catastrophic
  
  // Display (can be enriched by Claude)
  description: '', // Filled by enrichCrisisEvent or template
  
  // Choices (2-4 per crisis)
  choices: [
    {
      id: 'choice-0',
      text: 'Spray pesticide aggressively',
      moraleDelta: -5, // Workers unhappy with chemicals
      resourceDelta: { wood: -2, wheat: -1, hay: 0 }, // Short-term loss
      efficiency: -0.1, // Productivity hits
      agentReaction: 'worried_about_safety', // Agent quote key
    },
    {
      id: 'choice-1',
      text: 'Let nature take its course',
      moraleDelta: -15, // Agents angry at inaction
      resourceDelta: { wood: 0, wheat: -5, hay: 0 }, // Heavy loss
      efficiency: 0, // No productivity hit
      agentReaction: 'resigned_defeat',
    },
    {
      id: 'choice-2',
      text: 'Hire pest control specialists',
      moraleDelta: +5, // Agents feel protected
      resourceDelta: { wood: 0, wheat: -2, hay: 0, coins: -30 }, // Costs money
      efficiency: +0.05, // Workers focus better
      agentReaction: 'grateful_management',
    }
  ],

  // Consequences
  consequences: {
    moraleDelta: 0, // Set by chosen outcome
    resourceDelta: {}, // Set by chosen outcome
    agentStatus: null, // 'injured' | 'sick' | 'content' | null
    nextCrisisHint: null, // Can trigger follow-up crisis
  }
}
```

**Outcome Application** (new logic)

```javascript
function applyOutcome(outcome, agents, gameStore, agentStore) {
  // 1. Apply resource deltas
  Object.entries(outcome.resourceDelta).forEach(([resource, delta]) => {
    gameStore.addResource(resource, delta);
  });

  // 2. Apply morale deltas (distributed across agents)
  if (outcome.moraleDelta !== 0) {
    agents.forEach(agent => {
      // Agents in the affected zone get more morale swing
      const multiplier = agent.assignedZone === outcome.zone ? 1.5 : 1.0;
      agentStore.updateMorale(agent.id, outcome.moraleDelta * multiplier);
    });
  }

  // 3. Apply agent-specific consequences
  if (outcome.agentStatus) {
    const agent = agents.find(a => a.id === outcome.affectedAgent);
    if (agent) {
      agentStore.setAgentStatus(agent.id, outcome.agentStatus);
      // Injured/sick agents can't work for 1-2 days
      if (outcome.agentStatus === 'injured') {
        agentStore.unassignAgent(agent.id);
        // Schedule recovery in 2 days
        gameStore.scheduleRecovery(agent.id, 2);
      }
    }
  }

  // 4. Apply efficiency penalties (temporary)
  if (outcome.efficiency !== 0) {
    agents.forEach(agent => {
      agent.efficiency *= (1 + outcome.efficiency);
      // Reset at end of day
      scheduleEfficiencyReset(agent.id, 1); // 1 day later
    });
  }

  // 5. Log the decision
  logStore.addLogEntry({
    agentId: null,
    agentName: 'Management',
    type: 'crisis_resolution',
    message: `Crisis resolved: ${outcome.choiceText}. ${outcome.consequenceText}`
  });

  // 6. Trigger follow-up if specified
  if (outcome.nextCrisisHint) {
    gameStore.scheduleCrisis(outcome.nextCrisisHint, 2); // 2 days later
  }
}
```

**Crisis Enrichment** (Claude integration)

Use Claude to make crisis descriptions more vivid + personalized:

```javascript
async function enrichCrisisEvent(crisis, agents, gameStore) {
  // Only call Claude if API available + within budget
  if (!API_KEY || !isWithinDailyBudget()) {
    return crisis; // Use template description
  }

  const affectedAgent = agents.find(a => a.id === crisis.affectedAgent);
  const prompt = `
    You are a creative writer for AgentVille, a cozy farm sim.
    
    Crisis: ${crisis.title}
    Type: ${crisis.type}
    Base Description: "${crisis.baseDescription}"
    Affected Agent: ${affectedAgent?.name || 'Multiple'}
    Current Resources: Wood=${gameStore.resources.wood}, Wheat=${gameStore.resources.wheat}, Hay=${gameStore.resources.hay}
    
    Rewrite the crisis description in 2-3 sentences, making it dramatic but still humorous.
    Add specific details about the situation (reference resource names, agent personality if known).
    Keep tone: "worried but hopeful" — show the problem is real but solvable.
    Max 150 characters.
  `;

  const response = await callClaude(prompt, CLAUDE_MODEL_HAIKU, 150);
  crisis.description = response.trim();
  return crisis;
}
```

**Integration with CrisisModal**

Update src/components/ui/CrisisModal.jsx:

```javascript
export default function CrisisModal() {
  const [currentCrisis, setCurrentCrisis] = useState(null);
  const [selectedChoice, setSelectedChoice] = useState(null);
  const [isResolving, setIsResolving] = useState(false);
  const [enrichedDescription, setEnrichedDescription] = useState('');

  const agents = useAgentStore((state) => state.agents);
  const resources = useGameStore((state) => state.resources);
  const addCrisisToLog = useGameStore((state) => state.addCrisisToLog);
  const day = useGameStore((state) => state.day);

  // On crisis appearance, enrich description
  useEffect(() => {
    if (!currentCrisis) return;

    const enrich = async () => {
      const enriched = await enrichCrisisEvent(currentCrisis, agents, gameStore);
      setEnrichedDescription(enriched.description || currentCrisis.baseDescription);
    };

    enrich();
  }, [currentCrisis, agents, resources]);

  const handleChoice = (choiceIndex) => {
    setSelectedChoice(choiceIndex);
    setIsResolving(true);

    setTimeout(() => {
      const outcome = resolveCrisis(currentCrisis, choiceIndex);
      if (outcome) {
        // Apply consequences to game state
        applyOutcome(outcome, agents, gameStore, agentStore);

        // Log decision
        addCrisisToLog({
          season: gameStore.season,
          day: gameStore.day,
          crisis: currentCrisis.id,
          choice: choiceIndex,
          outcome
        });

        // Play sound
        if (outcome.moraleDelta > 0) {
          soundManager.playSaleSuccess();
        } else if (outcome.moraleDelta < 0) {
          soundManager.playNegative();
        }
      }

      setCurrentCrisis(null);
      setIsResolving(false);
    }, 800);
  };

  // ... render UI with enrichedDescription
}
```

**Acceptance Criteria:**
- ✅ CrisisQueue system tracks pending + resolved crises
- ✅ 20+ templates defined (5+ per zone, 5+ cross-zone)
- ✅ Crisis trigger chance varies by day (0.1 early, 0.3 mid, 0.6 late)
- ✅ Choices have meaningful consequences (morale, resources, efficiency, status)
- ✅ Claude enrichment optional (templates always fallback)
- ✅ Outcome application cascades properly (morale → agent status → scheduling)
- ✅ Follow-up crises can be triggered (chain events)
- ✅ Integration with CrisisModal complete
- ✅ All outcomes logged to crisisLog
- ✅ npm run build ✓, npm run dev ✓

---

### AV-009: Agent Field Log Commentary — 4-6 hours

**Objective:** Agents react to crises *and their own lives*. Field log becomes a window into their minds.

**Current State:**
- Field log exists (logStore + FieldLog.jsx)
- Displays crisis results + agent assignments
- Missing: **Agent personality in commentary**

**New Features:**

**Agent Reaction System**

```javascript
// In agentStore.js, add agent reaction library:
const AGENT_REACTIONS = {
  // Generic
  idle_bored: "Just standing around. Wish there was work.",
  assigned_confident: "Ready to show what I can do!",
  assigned_uncertain: "Hope I'm doing this right...",
  
  // Crisis responses
  crisis_worried: "Did you see that incoming crisis?",
  choice_agree: "I like that decision.",
  choice_disagree: "I would've done it differently.",
  
  // Morale-based
  morale_high_positive: "Things are going great! Love working here.",
  morale_high_cocky: "We're killing it. Best farm around.",
  morale_mid_neutral: "Okay. Could be better, could be worse.",
  morale_low_frustrated: "This isn't working. I'm starting to doubt things.",
  morale_low_angry: "I've had it. This place is a joke.",
  
  // Consequences
  injured_pained: "Ow... I'm hurt. Gonna need time to recover.",
  sick_worried: "Don't feel so good. Think I caught something.",
  fired_hurt: "Can't believe I got let go. That stung.",
  
  // Trait-specific (override generic)
  work_ethic_high: "Hard work never scared me.", // High work ethic
  work_ethic_low: "Do I really have to work right now?", // Low work ethic
  risk_high: "Let's go big or go home!", // High risk
  risk_low: "Let's play it safe, yeah?", // Low risk
  loyalty_high: "I'm with you no matter what.", // High loyalty
  loyalty_low: "Hmm, heard there are other farms hiring...", // Low loyalty
};

// Trait-weighted reaction selection
function getAgentReaction(agent, context) {
  // context = { type: 'assigned' | 'crisis' | 'morale', morale: 0-100, ... }
  
  // Base reaction from library
  let baseKey = `${context.type}_${context.sentiment}`;
  
  // Trait override
  if (agent.traits.workEthic > 80) {
    baseKey = `work_ethic_high`; // Override to show trait
  } else if (agent.traits.workEthic < 20) {
    baseKey = `work_ethic_low`;
  }
  
  return AGENT_REACTIONS[baseKey] || AGENT_REACTIONS.idle_bored;
}
```

**Event Triggers for Comments**

```javascript
// Trigger points in game loop:

// 1. On agent assignment
agent.assignedZone = zone;
const reaction = getAgentReaction(agent, { type: 'assigned', sentiment: 'confident' });
logStore.addLogEntry({
  agentId: agent.id,
  agentName: agent.name,
  type: 'assignment',
  message: reaction
});

// 2. On crisis resolution
const chosenOutcome = choices[selectedIndex];
const sentiment = chosenOutcome.moraleDelta > 0 ? 'agree' : 'disagree';
const agentReaction = getAgentReaction(affectedAgent, { type: 'choice', sentiment });
logStore.addLogEntry({
  agentId: affectedAgent.id,
  agentName: affectedAgent.name,
  type: 'crisis_reaction',
  message: agentReaction
});

// 3. On morale milestone
if (agent.morale >= 80 && prevMorale < 80) {
  const reaction = getAgentReaction(agent, { type: 'morale', morale: agent.morale });
  logStore.addLogEntry({
    agentId: agent.id,
    agentName: agent.name,
    type: 'morale_update',
    message: reaction
  });
}

// 4. On status change (injured, sick, fired)
if (newStatus && newStatus !== oldStatus) {
  const reaction = getAgentReaction(agent, { type: 'status', status: newStatus });
  logStore.addLogEntry({
    agentId: agent.id,
    agentName: agent.name,
    type: 'status_change',
    message: reaction
  });
}
```

**Claude-Generated Agent Voices** (Optional Layer)

For special moments, use Claude to generate unique agent voice:

```javascript
async function generateAgentVoice(agent, context) {
  // Skip if over API budget
  if (!isWithinDailyBudget()) {
    return getAgentReaction(agent, context);
  }

  const prompt = `
    You are ${agent.name}, a farm worker.
    
    Work Ethic: ${agent.traits.workEthic}/100
    Risk Tolerance: ${agent.traits.risk}/100
    Loyalty: ${agent.traits.loyalty}/100
    Current Morale: ${agent.morale}%
    Specialization: ${agent.traits.specialization}
    
    Event: ${context.type} — ${context.description}
    
    Write a ONE-SENTENCE reaction in first person (under 80 chars).
    Match personality: Low work ethic = lazy, High risk = bold, Low loyalty = considering leaving.
    Keep tone: natural, conversational, authentic to personality.
  `;

  try {
    const response = await callClaude(prompt, CLAUDE_MODEL_HAIKU, 80);
    return response.trim();
  } catch {
    // Fallback to template
    return getAgentReaction(agent, context);
  }
}
```

**Field Log UI Enhancement** (update FieldLog.jsx)

```javascript
export default function FieldLog() {
  const entries = useLogStore((state) => state.getRecentEntries(15));

  return (
    <div className="field-log-container">
      <h2>📜 Field Log</h2>
      
      <div className="log-entries">
        {entries.map((entry, idx) => (
          <div key={idx} className={`log-entry log-type-${entry.type}`}>
            {/* Agent name in color if from agent */}
            {entry.agentId && (
              <div className="agent-badge" style={{ backgroundColor: getAgentColor(entry.agentId) }}>
                {entry.agentName}
              </div>
            )}
            
            {/* Entry message */}
            <div className="entry-message">
              {entry.type === 'crisis_reaction' && '💬 '}
              {entry.type === 'assignment' && '✓ '}
              {entry.type === 'morale_update' && '😊 '}
              {entry.type === 'status_change' && '⚠️ '}
              {entry.message}
            </div>
            
            {/* Timestamp */}
            <div className="entry-time">
              Day {entry.day} {entry.timeOfDay === 'morning' ? '🌅' : '🌙'}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
```

**Acceptance Criteria:**
- ✅ AGENT_REACTIONS library with 30+ reaction strings
- ✅ Trait-weighted selection (high work ethic → different reactions)
- ✅ Trigger points: assignment, crisis, morale, status change
- ✅ Agent comments appear in Field Log with agent color badge
- ✅ Claude voice generation optional (template fallback)
- ✅ All reactions feel authentic to character
- ✅ Log entries display with emoji, agent name, timestamp
- ✅ No errors on build/dev
- ✅ Full game loop tested with comments flowing

---

### AV-015: Morale Consequence Mechanics — 4-5 hours

**Objective:** Low morale has teeth. Agents actually quit, productivity tanks, relationships break.

**Current State:**
- Morale 0-100 tracked
- Affects efficiency multiplier
- Missing: **Serious consequences for neglect**

**Consequence Thresholds**

```javascript
// In agentStore.js

export const MORALE_THRESHOLDS = {
  EXCELLENT: { min: 80, max: 100, name: 'Excellent', color: 0x22c55e },
  GOOD: { min: 60, max: 79, name: 'Good', color: 0xeab308 },
  OKAY: { min: 40, max: 59, name: 'Okay', color: 0xf97316 },
  BAD: { min: 20, max: 39, name: 'Bad', color: 0xef4444 },
  TERRIBLE: { min: 0, max: 19, name: 'Terrible', color: 0xb91c1c },
};

const MORALE_CONSEQUENCES = {
  // >= 80: Bonus, no penalties
  EXCELLENT: {
    efficiency: 1.3, // +30% productivity
    turnoverRisk: 0,
    strikeRisk: 0,
    desertionChance: 0,
  },
  // 60-79: Normal
  GOOD: {
    efficiency: 1.15, // +15%
    turnoverRisk: 0,
    strikeRisk: 0,
    desertionChance: 0,
  },
  // 40-59: Okay, slight issues
  OKAY: {
    efficiency: 1.0, // Baseline
    turnoverRisk: 0.1, // 10% chance to start looking elsewhere
    strikeRisk: 0.05,
    desertionChance: 0.01, // Low risk
  },
  // 20-39: Bad, problems emerge
  BAD: {
    efficiency: 0.75, // -25% productivity
    turnoverRisk: 0.5, // Actively looking
    strikeRisk: 0.2, // Real risk
    desertionChance: 0.05, // Can fire themselves
  },
  // 0-19: Terrible, agent about to quit
  TERRIBLE: {
    efficiency: 0.5, // -50% productivity
    turnoverRisk: 1.0, // Will leave
    strikeRisk: 0.5, // Likely to strike
    desertionChance: 0.2, // 20% chance per day to quit
  },
};
```

**Deserton Logic**

```javascript
// On each day advance, check if agents want to leave:
function checkForDesertions(agents, season, day) {
  agents.forEach(agent => {
    const moraleLevel = Object.values(MORALE_THRESHOLDS).find(
      t => agent.morale >= t.min && agent.morale <= t.max
    );
    
    const consequences = MORALE_CONSEQUENCES[moraleLevel.name];
    
    // Roll for desertion
    const desertionRoll = Math.random();
    if (desertionRoll < consequences.desertionChance) {
      // Agent quits!
      fireAgent(agent.id);
      
      // Log event
      logStore.addLogEntry({
        agentId: agent.id,
        agentName: agent.name,
        type: 'desertion',
        message: `${agent.name} quit and left the farm. (Morale: ${agent.morale}%)`
      });
      
      // Show dramatic modal
      showDesertionModal(agent);
    }
  });
}

// On Sale Day, check for strikes (work stoppage)
function checkForStrikes(agents, season) {
  const strikeRisks = agents.map(agent => {
    const moraleLevel = Object.values(MORALE_THRESHOLDS).find(
      t => agent.morale >= t.min && agent.morale <= t.max
    );
    const consequences = MORALE_CONSEQUENCES[moraleLevel.name];
    return { agent, riskLevel: consequences.strikeRisk };
  });

  const avgStrikeRisk = strikeRisks.reduce((sum, item) => sum + item.riskLevel, 0) / agents.length;
  
  if (Math.random() < avgStrikeRisk) {
    // STRIKE!
    gameStore.applyStrike({
      affectedAgents: strikeRisks.filter(s => s.riskLevel > 0.1).map(s => s.agent.id),
      lostProduction: 0.5, // Lost 50% of harvest
      message: `Agents went on strike. Harvest lost. (Avg morale: ${avgMorale}%)`
    });

    showStrikeModal();
  }
}
```

**Agent Demand System**

When morale is low, agents make demands:

```javascript
// When agent morale drops below 30, they request something
function generateAgentDemand(agent) {
  const demands = {
    workEthic_low: 'Can I take a day off? I\'m exhausted.',
    risk_high: 'Let me work in a riskier zone. This is boring.',
    loyalty_low: 'I heard other farms are hiring. Match their offer?',
    morale_bad: 'You need to fix things here. I\'m considering leaving.',
  };

  // Pick demand based on traits + morale
  let key = 'morale_bad';
  if (agent.traits.workEthic < 30) {
    key = 'workEthic_low';
  } else if (agent.traits.risk > 70 && agent.assignedZone === 'plains') {
    key = 'risk_high';
  } else if (agent.traits.loyalty < 40) {
    key = 'loyalty_low';
  }

  return {
    agentId: agent.id,
    agentName: agent.name,
    demandText: demands[key],
    options: [
      { text: 'Give them a day off', moraleDelta: +10, resourceDelta: { coins: -5 } },
      { text: 'Ignore their complaint', moraleDelta: -15, resourceDelta: {} },
      { text: 'Offer a raise (pay from coins)', moraleDelta: +20, resourceDelta: { coins: -20 } },
    ]
  };
};
```

**Agent Recovery System**

Injured/sick agents need time to recover, then come back with morale boost (or defect if you neglect them):

```javascript
// In gameStore.js
scheduleRecovery(agentId, daysDuration) {
  gameStore.scheduleEvent({
    type: 'agent_recovery',
    agentId,
    triggerDay: gameStore.day + daysDuration,
    onTrigger: () => {
      const agent = agentStore.agents.find(a => a.id === agentId);
      if (agent) {
        agentStore.setAgentStatus(agentId, 'idle');
        // If morale is still good, they're grateful
        if (agent.morale > 50) {
          agentStore.updateMorale(agentId, +15); // Recovery boost
          logStore.addLogEntry({
            agentId,
            agentName: agent.name,
            type: 'recovery',
            message: `${agent.name} is back on their feet and grateful!`
          });
        } else {
          // If morale is bad, they quit while injured
          logStore.addLogEntry({
            agentId,
            agentName: agent.name,
            type: 'desertion',
            message: `${agent.name} quit while recovering. Felt abandoned.`
          });
          agentStore.fireAgent(agentId);
        }
      }
    }
  });
}
```

**Deserton + Strike Modals**

```javascript
// New component: DesertionModal.jsx
export default function DesertionModal({ agent, onComplete }) {
  return (
    <div className="modal-overlay">
      <div className="modal-content modal-type-desertion">
        <h2>😢 {agent.name} Has Left</h2>
        <p>
          {agent.name} packed their bags and walked off the farm.
        </p>
        <p className="reason">
          Their morale was {agent.morale}%. They couldn't take it anymore.
        </p>
        <p className="consequence">
          You've lost a {agent.traits.specialization} specialist.
          Reassign their zone or hire someone new.
        </p>
        <button onClick={onComplete}>Accept Loss</button>
      </div>
    </div>
  );
}

// New component: StrikeModal.jsx
export default function StrikeModal({ season, affectedCount, lostProduction, onComplete }) {
  return (
    <div className="modal-overlay">
      <div className="modal-content modal-type-strike">
        <h2>🪧 STRIKE!</h2>
        <p>
          {affectedCount} agent(s) went on strike. They're refusing to work.
        </p>
        <p className="consequence">
          Harvest Lost: {(lostProduction * 100).toFixed(0)}%
        </p>
        <p className="advice">
          This is serious. You need to fix morale before next season.
        </p>
        <button onClick={onComplete}>Acknowledge</button>
      </div>
    </div>
  );
}
```

**Acceptance Criteria:**
- ✅ Morale thresholds defined (Excellent → Terrible)
- ✅ Each threshold has efficiency multiplier (1.3 to 0.5)
- ✅ Desertion logic (morale < 20, daily random check)
- ✅ Strike logic (avg morale drives strike risk on Sale Day)
- ✅ Agent demands system (low morale → demand something)
- ✅ Recovery scheduling (injured agents heal after N days)
- ✅ Deserton + Strike modals show consequences
- ✅ All events logged to Field Log
- ✅ Agents can be re-hired (next season or special event)
- ✅ Game is harder if you neglect morale
- ✅ Full game loop tested with consequences

---

## PHASE 2B: Agent Personality (Story Layer)

### Overview
Currently: Agents have traits (work ethic, risk, loyalty) but they don't *do* anything.
Target: Traits matter. Agents request things, develop relationships, have arcs.

---

### AV-004: Agent Traits → Decision Preferences — 3-4 hours

**Objective:** Agents react differently to the *same* crisis based on their traits.

**Current State:**
- Traits exist: workEthic (0-100), risk (0-100), loyalty (0-100), specialization
- Missing: Traits affect **crisis choices + decision outcomes**

**Trait-Based Reactions**

When a crisis appears, modify the choices to match agent personality:

```javascript
// In crisisEngine.js

function adaptChoicesForAgent(crisis, agent) {
  if (!agent) return crisis.choices; // Area-wide crisis, no agent adaptation
  
  // Deep clone choices to avoid mutation
  const adaptedChoices = crisis.choices.map(choice => ({...choice}));

  // HIGH WORK ETHIC (70+)
  if (agent.traits.workEthic > 70) {
    // Agents with strong work ethic prefer "keep working" solutions
    const hardWorkChoice = adaptedChoices.find(c => c.text.includes('work') || c.text.includes('push'));
    if (hardWorkChoice) {
      hardWorkChoice.moraleDelta += 5; // Extra morale for hard work approach
      hardWorkChoice.efficiency += 0.05; // Bonus productivity
    }
  }
  
  // LOW WORK ETHIC (< 30)
  if (agent.traits.workEthic < 30) {
    // Lazy agents prefer "take a break" or "avoid effort" solutions
    const easyChoice = adaptedChoices.find(c => c.text.includes('let') || c.text.includes('nature'));
    if (easyChoice) {
      easyChoice.moraleDelta += 5;
    }
  }

  // HIGH RISK (70+)
  if (agent.traits.risk > 70) {
    // Bold agents prefer aggressive/experimental solutions
    const aggressiveChoice = adaptedChoices.find(c => c.text.includes('aggressive') || c.text.includes('big'));
    if (aggressiveChoice) {
      aggressiveChoice.moraleDelta += 8; // BIG bonus for risky choice
    }
  }

  // LOW RISK (< 30)
  if (agent.traits.risk < 30) {
    // Cautious agents prefer safe/conservative solutions
    const safeChoice = adaptedChoices.find(c => c.text.includes('safe') || c.text.includes('carefully'));
    if (safeChoice) {
      safeChoice.moraleDelta += 5;
      safeChoice.resourceDelta = {...safeChoice.resourceDelta, coins: -5}; // Costs more but safer
    }
  }

  // HIGH LOYALTY (70+)
  if (agent.traits.loyalty > 70) {
    // Loyal agents prefer solutions that show you care about them
    const loyalChoice = adaptedChoices.find(c => c.text.includes('help') || c.text.includes('protect'));
    if (loyalChoice) {
      loyalChoice.moraleDelta += 10; // Major morale boost for loyal agents when you protect them
    }
  }

  // LOW LOYALTY (< 30)
  if (agent.traits.loyalty < 30) {
    // Disloyal agents prefer cost-cutting, self-interested solutions
    const cheapChoice = adaptedChoices.find(c => c.text.includes('cheap') || c.text.includes('save'));
    if (cheapChoice) {
      cheapChoice.moraleDelta += 5; // They appreciate saving money
      cheapChoice.moraleDelta -= 0; // Won't reward you extra, but won't punish
    }
  }

  return adaptedChoices;
}
```

**Trait Scores in Decisions**

When displaying a crisis, show which choice each agent would prefer:

```javascript
// In CrisisModal.jsx

function renderChoiceWithAgentPreferences(choice, agents, crisis) {
  const agentScores = agents.map(agent => ({
    agent,
    score: calculateChoiceAffinity(agent, choice, crisis)
  }));

  const bestMatch = agentScores.reduce((best, curr) =>
    curr.score > best.score ? curr : best
  );

  return (
    <div className="choice-option">
      <div className="choice-text">{choice.text}</div>
      
      {/* Show if any agent strongly prefers this */}
      {bestMatch.score > 0.7 && (
        <div className="choice-hint">
          💬 {bestMatch.agent.name} would like this approach
        </div>
      )}
      
      {/* Show trait alignment visually */}
      {bestMatch.score > 0.5 && (
        <div className="trait-alignment">
          <span>{traitIcon(bestMatch.agent)}</span>
        </div>
      )}
      
      <div className="choice-outcome">
        Morale: {choice.moraleDelta > 0 ? '+' : ''}{choice.moraleDelta}
      </div>
    </div>
  );
}

function calculateChoiceAffinity(agent, choice, crisis) {
  let score = 0;
  const text = choice.text.toLowerCase();

  // Work ethic alignment
  if (agent.traits.workEthic > 70 && (text.includes('work') || text.includes('push'))) score += 0.2;
  if (agent.traits.workEthic < 30 && (text.includes('rest') || text.includes('easy'))) score += 0.2;

  // Risk alignment
  if (agent.traits.risk > 70 && (text.includes('aggressive') || text.includes('experiment'))) score += 0.2;
  if (agent.traits.risk < 30 && (text.includes('safe') || text.includes('careful'))) score += 0.2;

  // Loyalty alignment
  if (agent.traits.loyalty > 70 && (text.includes('help') || text.includes('protect'))) score += 0.2;
  if (agent.traits.loyalty < 30 && (text.includes('cheap') || text.includes('save'))) score += 0.2;

  // Specialization alignment
  if (agent.traits.specialization === crisis.zone && text.includes('local')) score += 0.1;

  return Math.min(1, score);
}
```

**Trait Evolution** (Optional Layer)

Over time, agents' traits shift based on experiences:

```javascript
// On choice resolution, traits slightly shift
function updateAgentTraitFromDecision(agent, choice, outcome) {
  const text = choice.text.toLowerCase();

  // If agent worked hard and it paid off, work ethic increases
  if (text.includes('work') && outcome.moraleDelta > 0) {
    agent.traits.workEthic = Math.min(100, agent.traits.workEthic + 2);
  }

  // If you took a risk and it worked, agent's risk tolerance increases
  if ((text.includes('aggressive') || text.includes('gamble')) && outcome.moraleDelta > 0) {
    agent.traits.risk = Math.min(100, agent.traits.risk + 2);
  }

  // If you showed loyalty (spent money on them), loyalty increases
  if (outcome.resourceDelta?.coins < -15 && outcome.moraleDelta > 0) {
    agent.traits.loyalty = Math.min(100, agent.traits.loyalty + 3);
  }

  // If you ignored them/cheap solution, loyalty decreases
  if (outcome.resourceDelta?.coins > -5 && outcome.moraleDelta < 0) {
    agent.traits.loyalty = Math.max(0, agent.traits.loyalty - 3);
  }
}
```

**Acceptance Criteria:**
- ✅ Each trait (workEthic, risk, loyalty) affects choice morale delta (+5 to +10)
- ✅ Choices hint which agent prefers them (💬 Agent would like...)
- ✅ High trait agents get efficiency bonus on matching choices
- ✅ Trait scores affect choice display (visual alignment indicator)
- ✅ No errors on build/dev
- ✅ Full game loop tested with trait-based decisions

---

### AV-013: Dynamic Agent Events — 5-6 hours

**Objective:** Agents aren't static NPCs. They have wants, fears, achievements, life events.

**Current State:**
- Agents exist
- Missing: **Dynamic events that trigger based on game state + personality**

**Event System**

```javascript
// New: eventEngine.js

class AgentEventQueue {
  constructor(agentStore, gameStore, logStore) {
    this.pending = []; // Events waiting to trigger
    this.resolved = []; // History
    this.eventCooldown = new Map(); // agentId → lastEventDay
  }

  // Check if new events should trigger
  checkForEvents(agents, resources, season, day) {
    agents.forEach(agent => {
      // Cooldown: max 1 event per 2 days
      const lastEventDay = this.eventCooldown.get(agent.id) || -10;
      if (day - lastEventDay < 2) return;

      const possibleEvents = this.generateEvents(agent, resources, season);
      possibleEvents.forEach(event => {
        const shouldTrigger = Math.random() < event.probability;
        if (shouldTrigger) {
          this.pending.push(event);
          this.eventCooldown.set(agent.id, day);
        }
      });
    });
  }

  // Generate possible events for an agent
  generateEvents(agent, resources, season) {
    const events = [];

    // ACHIEVEMENT EVENTS
    if (agent.morale > 80 && agent.xp > 100) {
      events.push({
        type: 'achievement_promotion',
        agent,
        probability: 0.1,
        title: `${agent.name} Has Matured`,
        description: `${agent.name} has grown into a skilled worker.`,
        reward: { xp: 50, morale: +10 },
      });
    }

    // REQUEST EVENTS
    if (agent.morale < 40) {
      events.push({
        type: 'request_break',
        agent,
        probability: 0.2,
        title: `${agent.name} Needs a Break`,
        description: `${agent.name}: "Can I take a day off? I'm exhausted."`,
        choices: [
          { text: 'Grant a day off', morale: +15, xp: -10 },
          { text: 'Say no, keep working', morale: -20, xp: 0 },
        ],
      });
    }

    // CONFLICT EVENTS
    if (agent.traits.loyalty < 30 && Math.random() > 0.7) {
      events.push({
        type: 'conflict_wandering',
        agent,
        probability: 0.15,
        title: `${agent.name} Considering Leaving`,
        description: `${agent.name} has been looking at job postings from other farms...`,
        choices: [
          { text: 'Offer a raise', morale: +10, coins: -25 },
          { text: 'Let them go', morale: 0, consequence: 'fire' },
          { text: 'Have a talk', morale: +5, coins: 0 },
        ],
      });
    }

    // RELATIONSHIP EVENTS
    if (season === 1) {
      events.push({
        type: 'relationship_first_day',
        agent,
        probability: 0.5,
        title: `${agent.name}'s First Day`,
        description: `${agent.name} arrives nervous but eager.`,
        choices: [
          { text: 'Give them a warm welcome', morale: +15 },
          { text: 'Get straight to work', morale: +5 },
        ],
      });
    }

    // CRISIS-ADJACENT EVENTS
    if (resources.wood < 2 && agent.assignedZone === 'forest') {
      events.push({
        type: 'scarcity_warning',
        agent,
        probability: 0.3,
        title: `${agent.name} Warns: Wood Running Low`,
        description: `${agent.name}: "We're almost out of wood. We need to log more soon."`,
        choices: [
          { text: 'Increase logging (push harder)', morale: -10, efficiency: +0.1 },
          { text: 'Scale back work', morale: +5, efficiency: -0.1 },
        ],
      });
    }

    // PERSONAL EVENTS (seasonal)
    if (season === 3 && Math.random() > 0.8) {
      events.push({
        type: 'personal_birthday',
        agent,
        probability: 1.0,
        title: `Happy Birthday, ${agent.name}!`,
        description: `It's ${agent.name}'s birthday. A little cake goes a long way.`,
        choices: [
          { text: 'Celebrate with the team', morale: +20, coins: -10 },
          { text: 'Just say happy birthday', morale: +5, coins: 0 },
        ],
      });
    }

    return events;
  }

  // Resolve event choice
  resolveEvent(eventId, choiceIndex) {
    const event = this.pending.find(e => e.id === eventId);
    if (!event) return null;

    const choice = event.choices[choiceIndex];
    const outcome = {
      agent: event.agent,
      eventType: event.type,
      choice: choice.text,
      moraleDelta: choice.morale || 0,
      xpDelta: choice.xp || 0,
      coinsDelta: choice.coins || 0,
      consequence: choice.consequence || null,
    };

    // Apply outcome
    if (outcome.moraleDelta !== 0) {
      agentStore.updateMorale(event.agent.id, outcome.moraleDelta);
    }
    if (outcome.xpDelta !== 0) {
      agentStore.addAgentXP(event.agent.id, outcome.xpDelta);
    }
    if (outcome.coinsDelta !== 0) {
      gameStore.addResource('coins', outcome.coinsDelta);
    }
    if (outcome.consequence === 'fire') {
      agentStore.fireAgent(event.agent.id);
    }

    // Log
    logStore.addLogEntry({
      agentId: event.agent.id,
      agentName: event.agent.name,
      type: 'event',
      message: `${event.title}: ${choice.text}`
    });

    this.pending = this.pending.filter(e => e.id !== eventId);
    this.resolved.push({ event, outcome });

    return outcome;
  }
}
```

**Agent Event Modal**

```javascript
// New: AgentEventModal.jsx
export default function AgentEventModal({ event, onResolve }) {
  const [selectedChoice, setSelectedChoice] = useState(null);

  const handleChoice = (choiceIndex) => {
    setSelectedChoice(choiceIndex);
    setTimeout(() => {
      onResolve(event.id, choiceIndex);
    }, 500);
  };

  return (
    <div className="modal-overlay">
      <div className="modal-content modal-type-event">
        <div className="event-header" style={{ backgroundColor: getAgentColor(event.agent.id) }}>
          {event.agent.name}
        </div>

        <h2>{event.title}</h2>
        <p className="event-description">{event.description}</p>

        {/* Show agent morale/status context */}
        <div className="event-context">
          <span>Morale: {event.agent.morale}%</span>
          <span>Level: {event.agent.level}</span>
        </div>

        {/* Choices */}
        <div className="event-choices">
          {event.choices.map((choice, idx) => (
            <button
              key={idx}
              onClick={() => handleChoice(idx)}
              disabled={selectedChoice !== null}
              className={`choice-button ${selectedChoice === idx ? 'selected' : ''}`}
            >
              {choice.text}
              {choice.morale && <span className="morale-delta">{choice.morale > 0 ? '+' : ''}{choice.morale}</span>}
              {choice.coins && <span className="coin-delta">${choice.coins > 0 ? '+' : ''}{choice.coins}</span>}
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}
```

**Integration with Game Loop**

In IslandScene or main App, add event queue subscription:

```javascript
// In App.jsx or IslandScene.jsx
const eventQueue = useRef(null);

useEffect(() => {
  if (!eventQueue.current) {
    eventQueue.current = new AgentEventQueue(agentStore, gameStore, logStore);
  }

  // Check for new events whenever agents/resources change
  eventQueue.current.checkForEvents(agents, resources, season, day);
  
  const pending = eventQueue.current.pending;
  if (pending.length > 0) {
    setCurrentEvent(pending[0]); // Show first pending event
  }
}, [agents, resources, season, day]);
```

**Acceptance Criteria:**
- ✅ EventQueue system tracks pending + resolved events
- ✅ 6+ event types (achievement, request, conflict, relationship, scarcity, personal)
- ✅ Events trigger based on game state (morale, season, resources)
- ✅ Cooldown prevents event spam (1 per 2 days per agent max)
- ✅ Each event has 2-3 meaningful choices with outcomes
- ✅ AgentEventModal displays event + choices + feedback
- ✅ Outcomes affect morale, XP, coins, or agent status
- ✅ All events logged to Field Log
- ✅ Full game loop tested with events triggering naturally

---

### AV-019: Agent Relationships — 5-7 hours

**Objective:** Agents remember how you treat them. Relationships shift over time.

**Current State:**
- Agents exist
- Missing: **History of interactions, relationship arcs, loyalty shifts**

**Relationship System**

```javascript
// In agentStore.js, add relationship tracking

export const agentStore = create((set, get) => ({
  // ... existing agent state ...
  
  // NEW: Relationship tracking per agent
  relationships: new Map(), // agentId → RelationshipData
  
  // RelationshipData structure:
  // {
  //   firstMeetDay: number,
  //   lastInteractionDay: number,
  //   memorableChoices: [], // Choices they remember
  //   loyaltyHistory: [], // [{day, delta, reason}]
  //   conflictCount: number, // How many times you chose against their interest
  //   appreciationCount: number, // How many times you chose for them
  //   eventHistory: [], // All events involving this agent
  // }

  initializeRelationship: (agentId) => {
    set((state) => {
      const relationships = new Map(state.relationships);
      relationships.set(agentId, {
        firstMeetDay: gameStore.day,
        lastInteractionDay: gameStore.day,
        memorableChoices: [],
        loyaltyHistory: [],
        conflictCount: 0,
        appreciationCount: 0,
        eventHistory: [],
      });
      return { relationships };
    });
  },

  recordInteraction: (agentId, interaction) => {
    set((state) => {
      const relationships = new Map(state.relationships);
      const rel = relationships.get(agentId);
      if (!rel) return state;

      rel.lastInteractionDay = gameStore.day;
      
      // Was this choice good for the agent?
      if (interaction.moraleDelta > 0) {
        rel.appreciationCount += 1;
        rel.loyaltyHistory.push({ day: gameStore.day, delta: +2, reason: interaction.reason });
      } else if (interaction.moraleDelta < 0) {
        rel.conflictCount += 1;
        rel.loyaltyHistory.push({ day: gameStore.day, delta: -3, reason: interaction.reason });
      }

      // Memorable choices (especially good or bad)
      if (Math.abs(interaction.moraleDelta) > 10) {
        rel.memorableChoices.push({
          choice: interaction.choice,
          moraleDelta: interaction.moraleDelta,
          day: gameStore.day,
        });
      }

      rel.eventHistory.push(interaction);
      relationships.set(agentId, rel);
      return { relationships };
    });
  },

  getRelationshipStatus: (agentId) => {
    const rel = get().relationships.get(agentId);
    if (!rel) return 'unknown';

    const daysKnown = gameStore.day - rel.firstMeetDay;
    const balance = rel.appreciationCount - rel.conflictCount;

    if (balance < -5) return 'resentful'; // They hate you
    if (balance < -2) return 'disappointed'; // Disappointed
    if (balance < 1) return 'neutral'; // Neutral
    if (balance < 3) return 'appreciative'; // Likes you
    return 'loyal'; // Strong bond
  },

  getRelationshipText: (agentId) => {
    const status = get().getRelationshipStatus(agentId);
    const rel = get().relationships.get(agentId);

    const texts = {
      resentful: `${rel.agentName} seems to resent you.`,
      disappointed: `${rel.agentName} seems disappointed.`,
      neutral: `${rel.agentName} has no particular feelings about you.`,
      appreciative: `${rel.agentName} seems to appreciate your management.`,
      loyal: `${rel.agentName} is very loyal to you.`,
    };

    return texts[status];
  },
}));
```

**Relationship-Based Behavior**

Agents act differently based on relationship status:

```javascript
// When generating choices for a crisis, modify based on relationship
function adaptChoicesForRelationship(crisis, affectedAgent, agentStore) {
  const relationshipStatus = agentStore.getRelationshipStatus(affectedAgent.id);
  const rel = agentStore.relationships.get(affectedAgent.id);

  // LOYAL agents: More forgiving of mistakes, prefer choices benefiting team
  if (relationshipStatus === 'loyal') {
    const teamChoice = crisis.choices.find(c => c.text.includes('team') || c.text.includes('all'));
    if (teamChoice) {
      teamChoice.moraleDelta += 10; // Extra boost if you keep team together
    }
  }

  // RESENTFUL agents: Willing to quit, prefer selfish choices
  if (relationshipStatus === 'resentful') {
    rel.desertionChance += 0.1; // More likely to leave
    const selfishChoice = crisis.choices.find(c => c.text.includes('save money') || c.text.includes('protect'));
    if (selfishChoice) {
      selfishChoice.moraleDelta += 5; // They appreciate self-interest
    }
  }

  // NEUTRAL agents: Can be swayed either way
  if (relationshipStatus === 'neutral') {
    const choice = crisis.choices[Math.floor(Math.random() * crisis.choices.length)];
    choice.moraleDelta += 3; // They're more receptive
  }

  return crisis.choices;
}
```

**Relationship Arcs**

Over a full season (or multiple seasons), relationships develop narratives:

```javascript
// Relationship progression system
function generateRelationshipArc(agent, rel) {
  const status = getRelationshipStatus(agent.id);

  // EARLY GAME (Days 1-3): First impression
  if (gameStore.day <= 3) {
    return `Day 1: ${agent.name} arrives. How will you treat them?`;
  }

  // MID GAME (Days 4-6): Relationship develops
  if (rel.appreciationCount > rel.conflictCount + 2) {
    return `${agent.name} is starting to trust you.`;
  } else if (rel.conflictCount > rel.appreciationCount + 2) {
    return `${agent.name} is getting frustrated with your choices.`;
  } else {
    return `${agent.name} is undecided about working for you.`;
  }

  // END GAME (Day 7): Culmination
  if (gameStore.day === 7) {
    if (status === 'loyal') {
      return `${agent.name}: "This was a great season. I'd love to stay."`;
    } else if (status === 'resentful') {
      return `${agent.name}: "I don't think this is working out."`;
    } else {
      return `${agent.name}: "This was... okay. We'll see about next season."`;
    }
  }
}
```

**Relationship UI** (Enhancement to AgentPanel)

Show relationship status + history:

```javascript
// In AgentPanel.jsx, add relationship display
function AgentCard({ agent, agentStore }) {
  const relationshipStatus = agentStore.getRelationshipStatus(agent.id);
  const relationshipText = agentStore.getRelationshipText(agent.id);
  const rel = agentStore.relationships.get(agent.id);

  return (
    <div className="agent-card">
      <div className="agent-header">
        <h3>{agent.name}</h3>
        <span className={`relationship-badge relationship-${relationshipStatus}`}>
          {relationshipStatus}
        </span>
      </div>

      <div className="morale-bar">
        {/* Morale bar */}
      </div>

      {/* Relationship summary */}
      <div className="relationship-summary">
        <p className="relationship-text">{relationshipText}</p>
        <p className="relationship-stats">
          Appreciation: {rel.appreciationCount} | Conflicts: {rel.conflictCount}
        </p>
      </div>

      {/* Recent memorable choice */}
      {rel.memorableChoices.length > 0 && (
        <div className="memorable-choice">
          <p className="label">You Once:</p>
          <p className="choice-text">{rel.memorableChoices[rel.memorableChoices.length - 1].choice}</p>
        </div>
      )}

      {/* Assignment dropdown */}
      <div className="assignment-controls">
        {/* ... existing code ... */}
      </div>
    </div>
  );
}
```

**Acceptance Criteria:**
- ✅ RelationshipData structure tracks every interaction
- ✅ getRelationshipStatus: resentful → disappointed → neutral → appreciative → loyal
- ✅ Memorable choices recorded (high morale delta choices)
- ✅ Relationship affects crisis choice morale deltas
- ✅ Loyal agents more forgiving, resentful agents more demanding
- ✅ Relationship arc generated based on game state
- ✅ UI shows relationship status + appreciation/conflict count
- ✅ Agents remember your memorable choices
- ✅ No errors on build/dev
- ✅ Full multi-season test: relationships persist across seasons

---

## SUMMARY: Phase 2A + 2B Deliverables

**Phase 2A: Crisis Engine (Full) — ~15 hours**
1. AV-008: CrisisQueue, 20+ templates, Claude enrichment, outcome application
2. AV-009: Agent reactions, Field Log commentary, trait-weighted responses
3. AV-015: Morale thresholds, desertion, strikes, agent demands

**Phase 2B: Agent Personality — ~17 hours**
1. AV-004: Trait-based choice preferences, efficiency bonuses
2. AV-013: Dynamic events (6+ types), event queue, meaningful choices
3. AV-019: Relationship tracking, arcs, memorable choices, UI display

**Total: ~32 hours of implementation**

**Game Feels Like Farmville When Complete:**
✅ Agents have personalities (traits matter)
✅ Crises feel personal (agent-specific reactions)
✅ Decisions have ripple effects (morale → desertion, strike, recovery)
✅ Relationships develop (loyalty arcs)
✅ Events happen organically (birthdays, requests, conflicts)
✅ History is visible (Field Log, memorable choices)
✅ Consequences matter (low morale = losing workers)

---

**Ready to Start?**

You've got ~6 hours of context left. Start with **AV-008** (Crisis Engine wiring) or want to do something else first?
