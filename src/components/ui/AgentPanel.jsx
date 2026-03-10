import { useAgentStore } from '../../store/agentStore';

export default function AgentPanel() {
  const agents = useAgentStore((state) => state.agents);
  const setAgentZone = useAgentStore((state) => state.setAgentZone);
  const updateAgentMorale = useAgentStore((state) => state.updateAgentMorale);

  const zones = ['forest', 'plains', 'wetlands'];

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

            {/* Zone Assignment */}
            <div className="flex flex-col gap-2">
              <label className="text-xs font-semibold uppercase tracking-wider text-slate-300">
                Assign Zone
              </label>
              <select
                value={agent.zoneName || ''}
                onChange={(e) => setAgentZone(agent.id, e.target.value || null)}
                className="rounded border border-slate-600 bg-slate-700 px-2 py-1 text-sm text-white"
              >
                <option value="">— None —</option>
                {zones.map((zone) => (
                  <option key={zone} value={zone}>
                    {zone.charAt(0).toUpperCase() + zone.slice(1)}
                  </option>
                ))}
              </select>
            </div>

            {/* Traits Display */}
            {agent.traits && (
              <div className="mt-2 grid grid-cols-2 gap-1 text-xs text-slate-400">
                <div>Work: {agent.traits.workEthic}%</div>
                <div>Risk: {agent.traits.risk}%</div>
                <div>Loyalty: {agent.traits.loyalty}%</div>
                <div>Spec: {agent.traits.specialization}</div>
              </div>
            )}

            {/* Zone Info */}
            {agent.zoneName && (
              <div className="mt-2 rounded bg-blue-900/30 px-2 py-1 text-xs text-blue-300">
                ✓ Working: {agent.zoneName}
              </div>
            )}
          </div>
        ))}
      </div>
    </div>
  );
}
