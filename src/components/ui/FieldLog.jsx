import { useEffect, useState } from 'react';
import { useAgentStore } from '../../store/agentStore';
import { useGameStore } from '../../store/gameStore';
import { useLogStore } from '../../store/logStore';
import { soundManager } from '../../utils/soundManager';
import { cardGenerator } from '../../utils/cardGenerator';
import ShareModal from './ShareModal';

export default function FieldLog() {
  const crisisLog = useGameStore((state) => state.crisisLog);
  const agents = useAgentStore((state) => state.agents);
  const season = useGameStore((state) => state.season);
  const day = useGameStore((state) => state.day);
  const logEntries = useLogStore((state) => state.entries);
  const [quoteCard, setQuoteCard] = useState(null);
  const [showQuoteModal, setShowQuoteModal] = useState(false);

  // Play sound when new log entry appears
  useEffect(() => {
    if (logEntries.length > 0) {
      const lastEntry = logEntries[logEntries.length - 1];
      if (lastEntry.type === 'crisis_reaction' || lastEntry.type === 'assignment' || lastEntry.type === 'ambient') {
        soundManager.play('agentReaction');
      }
    }
  }, [logEntries]);

  const handleShareQuote = async (entry) => {
    soundManager.play('shareCapture');
    const agent = agents.find((a) => a.id === entry.agentId);

    const cardData = {
      agentName: entry.agentName,
      agentLevel: agent?.level || 1,
      agentColor: agent?.appearance?.bodyColor || '#888888',
      quote: entry.message,
      season: entry.season,
      day: entry.day,
      morale: agent?.morale || 75
    };

    const card = await cardGenerator.generateCard('quote', cardData);
    setQuoteCard(card);
    setShowQuoteModal(true);
  };

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
                      : entry.type === 'morale_crisis'
                        ? 'border-red-600/50 bg-red-900/20 text-red-100'
                        : entry.type === 'morale_recovery'
                          ? 'border-green-600/50 bg-green-900/20 text-green-100'
                          : entry.type === 'assignment'
                            ? 'border-blue-600/50 bg-blue-900/20 text-blue-100'
                            : entry.type === 'autonomous_decision'
                              ? 'border-cyan-600/50 bg-cyan-900/20 text-cyan-100'
                              : entry.type === 'need_crisis'
                                ? 'border-red-600/50 bg-red-900/30 text-red-200'
                                : entry.type === 'work_failure'
                                  ? 'border-orange-600/50 bg-orange-900/20 text-orange-100'
                                  : entry.type === 'price_change'
                                    ? 'border-yellow-600/50 bg-yellow-900/20 text-yellow-200'
                                    : entry.type === 'resource_production'
                                      ? 'border-emerald-600/50 bg-emerald-900/20 text-emerald-100'
                                      : entry.type === 'market_trade' || entry.type === 'market_sale' || entry.type === 'trade'
                                        ? 'border-teal-600/50 bg-teal-900/20 text-teal-100'
                                        : entry.type === 'economy_alert' || entry.type === 'economy_collapse'
                                          ? 'border-red-600/50 bg-red-900/40 text-red-200'
                                          : entry.type === 'economic_event'
                                            ? 'border-indigo-600/50 bg-indigo-900/20 text-indigo-100'
                                            : entry.type === 'alliance_formed'
                                              ? 'border-green-600/50 bg-green-900/30 text-green-100'
                                              : entry.type?.includes('conflict')
                                                ? 'border-red-600/50 bg-red-900/25 text-red-150'
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
                <div className="mt-1 text-xs opacity-90 leading-relaxed flex items-start justify-between gap-2">
                  <span className="flex-1">{entry.message}</span>
                  {entry.agentId && entry.type !== 'ambient' && (
                    <button
                      onClick={() => handleShareQuote(entry)}
                      className="opacity-60 hover:opacity-100 transition-opacity flex-shrink-0 text-sm"
                      title="Share quote"
                    >
                      📤
                    </button>
                  )}
                </div>
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

      {/* Quote Share Modal */}
      {showQuoteModal && (
        <ShareModal
          card={quoteCard}
          title="📸 Agent Quote"
          onClose={() => setShowQuoteModal(false)}
        />
      )}
    </div>
  );
}
