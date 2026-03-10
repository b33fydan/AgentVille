import { useAgentStore } from '../../store/agentStore';

export default function FieldLog() {
  const crisisLog = useAgentStore((state) => state.crisisLog);
  const agents = useAgentStore((state) => state.agents);
  const season = useAgentStore((state) => state.season);

  // Generate log entries from crisis history + agent updates
  const getLogEntries = () => {
    const entries = [];

    // Add crisis entries
    crisisLog.forEach((log) => {
      entries.push({
        type: 'crisis',
        season: log.season,
        day: log.day,
        title: `Crisis Resolved: ${log.crisis}`,
        choice: log.choice,
        moraleDelta: log.outcome?.moraleDelta || 0,
        text: `Choice: "${log.outcome?.choiceText}"`
      });
    });

    // Add agent status updates
    agents.forEach((agent) => {
      if (agent.zoneName) {
        entries.push({
          type: 'status',
          agent: agent.name,
          title: `${agent.name} assigned to ${agent.zoneName}`,
          morale: agent.morale,
          efficiency: Math.round(agent.efficiency * 100),
          text: `Working in ${agent.zoneName} zone (${Math.round(agent.efficiency * 100)}% efficiency)`
        });
      }
    });

    // Sort by reverse order (newest first)
    return entries.reverse();
  };

  const entries = getLogEntries();
  const hasContent = entries.length > 0;

  return (
    <div className="flex flex-col rounded-lg border border-slate-700 bg-slate-900 p-4">
      <h2 className="mb-4 text-lg font-bold text-white">📜 Field Log</h2>

      <div className="flex flex-col gap-2 max-h-96 overflow-y-auto">
        {hasContent ? (
          entries.map((entry, index) => (
            <div
              key={index}
              className={`rounded-md border px-3 py-2 text-sm ${
                entry.type === 'crisis'
                  ? 'border-amber-600/50 bg-amber-900/20 text-amber-100'
                  : 'border-blue-600/50 bg-blue-900/20 text-blue-100'
              }`}
            >
              <div className="font-semibold">{entry.title}</div>
              <div className="text-xs opacity-75 mt-1">{entry.text}</div>
              {entry.moraleDelta !== undefined && (
                <div className={`text-xs mt-1 font-bold ${
                  entry.moraleDelta > 0 ? 'text-green-400' :
                  entry.moraleDelta < 0 ? 'text-red-400' : 'text-slate-400'
                }`}>
                  Morale: {entry.moraleDelta > 0 ? '+' : ''}{entry.moraleDelta}
                </div>
              )}
              {entry.efficiency !== undefined && (
                <div className="text-xs mt-1 text-slate-300">
                  Efficiency: {entry.efficiency}%
                </div>
              )}
            </div>
          ))
        ) : (
          <div className="rounded-md border border-slate-600 bg-slate-800 p-3 text-center text-sm text-slate-400">
            📝 No events yet. Assign agents and advance days to log activity.
          </div>
        )}
      </div>

      {/* Season Info */}
      <div className="mt-4 rounded-md border border-slate-700 bg-slate-800 p-2 text-xs text-slate-300">
        <div>Season {season.seasonNumber}, Day {season.currentDay}/7</div>
        <div>Total events: {entries.length}</div>
      </div>
    </div>
  );
}
