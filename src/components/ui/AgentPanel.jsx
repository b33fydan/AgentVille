import { useAgentStore } from '../../store/agentStore';
import { useLogStore } from '../../store/logStore';
import { selectReaction } from '../../utils/agentReactions';
import { soundManager } from '../../utils/soundManager';
import FieldLog from './FieldLog';

export default function AgentPanel() {
  const agents = useAgentStore((state) => state.agents);
  const assignAgentToZone = useAgentStore((state) => state.assignAgentToZone);
  const unassignAgent = useAgentStore((state) => state.unassignAgent);
  const updateMorale = useAgentStore((state) => state.updateMorale);
  const addLogEntry = useLogStore((state) => state.addLogEntry);

  const zones = ['forest', 'plains', 'wetlands'];

  // Handle assignment with reaction
  const handleAssignAgent = (agentId, zone) => {
    const agent = agents.find((a) => a.id === agentId);
    if (!agent) return;

    // Determine reaction type (positive, neutral, negative)
    let reactionType = 'neutral';
    if (agent.traits.specialization === zone || agent.traits.workEthic > 70) {
      reactionType = 'positive';
    } else if (agent.traits.workEthic < 30 || agent.traits.risk < 20) {
      reactionType = 'negative';
    }

    // Select appropriate reaction
    const reaction = selectReaction('assignment', `${zone}_${reactionType}`, null);

    // Log the reaction
    if (reaction) {
      addLogEntry({
        agentId,
        agentName: agent.name,
        type: 'assignment',
        message: reaction.text,
        emoji: reaction.emoji
      });
    }

    // Perform the assignment
    soundManager.play('agentAssign');
    assignAgentToZone(agentId, zone);
  };

  const handleUnassignAgent = (agentId) => {
    unassignAgent(agentId);
  };

  const getMoraleColor = (morale) => {
    if (morale >= 70) return 'bg-green-500';
    if (morale >= 40) return 'bg-yellow-500';
    return 'bg-red-500';
  };

  const getMoraleLabel = (morale) => {
    if (morale >= 70) return 'Happy';
    if (morale >= 40) return 'Neutral';
    return 'Unhappy';
  };

  return (
    <div className="flex flex-col gap-4">
      {/* Agents Section */}
      <div className="flex flex-col gap-4 rounded-lg border border-slate-700 bg-slate-900 p-4">
        <h2 className="text-lg font-bold text-white">👥 Agents</h2>

        <div className="flex flex-col gap-3">
          {agents.map((agent) => (
          <div key={agent.id} className="rounded-md border border-slate-600 bg-slate-800 p-3">
            {/* Agent Name & Morale */}
            <div className="mb-2 flex items-center justify-between">
              <h3 className="font-semibold text-white">{agent.name}</h3>
              <div className="flex items-center gap-2">
                <span className={`rounded px-2 py-1 text-xs font-bold text-white ${getMoraleColor(agent.morale)}`}>
                  {agent.morale}% {getMoraleLabel(agent.morale)}
                </span>
              </div>
            </div>

            {/* Morale Bar */}
            <div className="mb-3 h-2 rounded-full bg-slate-700">
              <div
                className={`h-full rounded-full transition-all ${getMoraleColor(agent.morale)}`}
                style={{ width: `${agent.morale}%` }}
              />
            </div>

            {/* AUTONOMOUS NEEDS DISPLAY */}
            <div className="mb-3 flex flex-col gap-2">
              {/* Hunger */}
              <div className="flex items-center justify-between text-xs">
                <span className="text-slate-400">🍖 Hunger</span>
                <span className={`${agent.hunger > 80 ? 'text-red-400 font-bold' : 'text-slate-300'}`}>
                  {agent.hunger}%
                </span>
              </div>
              <div className="h-1.5 rounded-full bg-slate-700">
                <div
                  className={`h-full rounded-full transition-all ${
                    agent.hunger > 80 ? 'bg-red-600' : agent.hunger > 60 ? 'bg-orange-500' : 'bg-yellow-500'
                  }`}
                  style={{ width: `${agent.hunger}%` }}
                />
              </div>

              {/* Fatigue */}
              <div className="flex items-center justify-between text-xs">
                <span className="text-slate-400">😴 Fatigue</span>
                <span className={`${agent.fatigue > 90 ? 'text-red-400 font-bold' : 'text-slate-300'}`}>
                  {agent.fatigue}%
                </span>
              </div>
              <div className="h-1.5 rounded-full bg-slate-700">
                <div
                  className={`h-full rounded-full transition-all ${
                    agent.fatigue > 90 ? 'bg-red-600' : agent.fatigue > 70 ? 'bg-orange-500' : 'bg-blue-500'
                  }`}
                  style={{ width: `${agent.fatigue}%` }}
                />
              </div>

              {/* Equipment Wear */}
              <div className="flex items-center justify-between text-xs">
                <span className="text-slate-400">🔧 Equipment</span>
                <span className={`${agent.equipmentWear > 90 ? 'text-red-400 font-bold' : 'text-slate-300'}`}>
                  {agent.equipmentWear}%
                </span>
              </div>
              <div className="h-1.5 rounded-full bg-slate-700">
                <div
                  className={`h-full rounded-full transition-all ${
                    agent.equipmentWear > 90 ? 'bg-red-600' : agent.equipmentWear > 70 ? 'bg-orange-500' : 'bg-yellow-600'
                  }`}
                  style={{ width: `${agent.equipmentWear}%` }}
                />
              </div>

              {/* Current Decision */}
              {agent.currentDecision && agent.currentDecision !== 'idle' && (
                <div className="mt-1 rounded bg-cyan-900/30 px-2 py-1 text-xs text-cyan-300">
                  💭 {agent.currentDecision === 'working' ? `Working in ${agent.decidedZone}` : `${agent.currentDecision.charAt(0).toUpperCase() + agent.currentDecision.slice(1)}`}
                </div>
              )}
            </div>

            {/* Traits Display */}
            {agent.traits && (
              <div className="mt-2 grid grid-cols-2 gap-1 text-xs text-slate-400">
                <div>💪 Work: {agent.traits.workEthic}%</div>
                <div>🎲 Risk: {agent.traits.risk}%</div>
                <div>🤝 Loyalty: {agent.traits.loyalty}%</div>
                <div>🎯 Spec: {agent.traits.specialization}</div>
              </div>
            )}
          </div>
        ))}
        </div>
      </div>

      {/* Field Log Section */}
      <FieldLog />
    </div>
  );
}
