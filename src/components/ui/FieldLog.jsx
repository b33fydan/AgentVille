import { useAgentStore } from '../../store/agentStore';
import { useGameStore } from '../../store/gameStore';
import { useLogStore } from '../../store/logStore';

export default function FieldLog() {
  const crisisLog = useGameStore((state) => state.crisisLog);
  const agents = useAgentStore((state) => state.agents);
  const season = useGameStore((state) => state.season);
  const day = useGameStore((state) => state.day);
  const logEntries = useLogStore((state) => state.entries);

  // Get agent color by ID
  const getAgentColor = (agentId) => {
    const agent = agents.find((a) => a.id === agentId);
    return agent ? agent.appearance.bodyColor : '#888888';
  };

  // Format timestamp
  const formatTime = (entry) => {
    if (!entry.day) return '';
    const timeLabel = entry.timeOfDay === 'morning' ? '🌅' : entry.timeOfDay === 'evening' ? '🌙' : '📍';
    return `S${entry.season}D${entry.day} ${timeLabel}`;
  };

  // Get log entries from store (already includes reactions)
  const displayEntries = logEntries.slice(-15).reverse(); // Show last 15, newest first
  const hasContent = displayEntries.length > 0;

  return (
    <div className="flex flex-col rounded-lg border border-slate-700 bg-slate-900 p-4">
      <h2 className="mb-4 text-lg font-bold text-white">📜 Field Log</h2>

      <div className="flex flex-col gap-2 max-h-96 overflow-y-auto">
        {hasContent ? (
          displayEntries.map((entry) => {
            const agentColor = entry.agentId ? getAgentColor(entry.agentId) : null;
            const timeStr = formatTime(entry);

            return (
              <div
                key={entry.id}
                className={`rounded-md border px-3 py-2 text-sm transition-colors ${
                  entry.type === 'crisis' || entry.type === 'crisis_resolution'
                    ? 'border-amber-600/50 bg-amber-900/20 text-amber-100'
                    : entry.type === 'crisis_reaction'
                      ? 'border-purple-600/50 bg-purple-900/20 text-purple-100'
                      : 'border-slate-600/50 bg-slate-800/50 text-slate-200'
                }`}
              >
                {/* Header: Agent badge + Time */}
                <div className="flex items-center justify-between gap-2">
                  <div className="flex items-center gap-2">
                    {entry.agentId && (
                      <div
                        className="h-3 w-3 rounded-full border border-white/30"
                        style={{ backgroundColor: agentColor }}
                        title={entry.agentName}
                      />
                    )}
                    <span className="font-semibold text-sm">{entry.agentName}</span>
                    {entry.emoji && <span className="text-lg">{entry.emoji}</span>}
                  </div>
                  {timeStr && (
                    <span className="text-xs text-slate-400">{timeStr}</span>
                  )}
                </div>

                {/* Message */}
                <div className="mt-1 text-xs opacity-90 leading-relaxed">{entry.message}</div>
              </div>
            );
          })
        ) : (
          <div className="rounded-md border border-slate-600 bg-slate-800 p-3 text-center text-sm text-slate-400">
            📝 No events yet. Assign agents and advance days to log activity.
          </div>
        )}
      </div>

      {/* Season Info */}
      <div className="mt-4 rounded-md border border-slate-700 bg-slate-800 p-2 text-xs text-slate-300">
        <div>Season {season}, Day {day}/7</div>
        <div>Total log entries: {logEntries.length}</div>
      </div>
    </div>
  );
}
