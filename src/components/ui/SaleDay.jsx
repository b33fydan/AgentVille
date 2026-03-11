import { useEffect, useState } from 'react';
import { useAgentStore } from '../../store/agentStore';
import { soundManager } from '../../utils/soundManager';
import { generateAgentReview } from '../../utils/claudeService';

const MARKET_PRICES = {
  wood: 2,
  wheat: 5,
  hay: 3
};

export default function SaleDay() {
  const season = useAgentStore((state) => state.season);
  const resources = useAgentStore((state) => state.resources);
  const agents = useAgentStore((state) => state.agents);
  const completeSeason = useAgentStore((state) => state.completeSeason);
  const getProfit = useAgentStore((state) => state.getProfit);
  const getAverageMorale = useAgentStore((state) => state.getAverageMorale);

  const [stage, setStage] = useState('harvest'); // harvest → sale → review → complete
  const [displayProfit, setDisplayProfit] = useState(0);
  const [review, setReview] = useState('');
  const [reviewSource, setReviewSource] = useState('loading'); // loading | claude | template
  const profit = getProfit();
  const avgMorale = getAverageMorale();

  // Fetch Claude review when entering review stage
  useEffect(() => {
    if (stage !== 'review' || review !== '') return;

    const fetchReview = async () => {
      const result = await generateAgentReview({
        agentNames: agents.map(a => a.name).join(', '),
        avgMorale,
        profit,
        season: season.seasonNumber
      });
      setReview(result.review);
      setReviewSource(result.source);
    };

    fetchReview();
  }, [stage, review, agents, avgMorale, profit, season.seasonNumber]);

  // Auto-progress through stages
  useEffect(() => {
    if (season.currentDay !== 7) return;

    const timings = {
      harvest: 2000,
      sale: 3000,
      review: 4000
    };

    const timer = setTimeout(() => {
      if (stage === 'harvest') {
        setStage('sale');
      } else if (stage === 'sale') {
        // Play sale sound
        if (profit > 0) {
          soundManager.playSaleSuccess();
        } else {
          soundManager.playNegative();
        }

        // Animate profit counter
        setDisplayProfit(0);
        let current = 0;
        const interval = setInterval(() => {
          current += Math.ceil(profit / 20);
          if (current >= profit) {
            setDisplayProfit(profit);
            clearInterval(interval);
          } else {
            setDisplayProfit(current);
          }
        }, 50);
        setStage('review');
      } else if (stage === 'review') {
        setStage('complete');
      }
    }, timings[stage] || 0);

    return () => clearTimeout(timer);
  }, [season.currentDay, stage, profit]);

  if (season.currentDay !== 7) {
    return null;
  }

  const getProfitTier = () => {
    if (profit > 50) return { tier: 'Excellent', color: 'text-green-400', bg: 'bg-green-900/30' };
    if (profit > 20) return { tier: 'Good', color: 'text-yellow-400', bg: 'bg-yellow-900/30' };
    if (profit > 0) return { tier: 'Decent', color: 'text-blue-400', bg: 'bg-blue-900/30' };
    return { tier: 'Loss', color: 'text-red-400', bg: 'bg-red-900/30' };
  };

  const profitTier = getProfitTier();

  return (
    <div className="fixed inset-0 flex items-center justify-center bg-black/80 backdrop-blur-sm">
      <div className="w-full max-w-2xl rounded-lg border-2 border-yellow-600 bg-slate-900 p-8 shadow-2xl">
        {/* Stage 1: Harvest Tally */}
        {stage === 'harvest' && (
          <div className="animate-pulse text-center">
            <h1 className="text-4xl font-bold text-yellow-400 mb-4">🌾 HARVEST TIME</h1>
            <p className="text-lg text-slate-300">Tallying your crops...</p>
          </div>
        )}

        {/* Stage 2: Profit Calculation */}
        {(stage === 'sale' || stage === 'review' || stage === 'complete') && (
          <div className="space-y-6">
            {/* Resources Display */}
            <div className="grid grid-cols-3 gap-4">
              <div className="rounded-lg bg-green-900/30 p-4 text-center border border-green-700">
                <div className="text-sm text-green-300">🌲 Wood</div>
                <div className="text-2xl font-bold text-green-400">{resources.wood}</div>
                <div className="text-xs text-green-300">${resources.wood * MARKET_PRICES.wood}</div>
              </div>
              <div className="rounded-lg bg-amber-900/30 p-4 text-center border border-amber-700">
                <div className="text-sm text-amber-300">🌾 Wheat</div>
                <div className="text-2xl font-bold text-amber-400">{resources.wheat}</div>
                <div className="text-xs text-amber-300">${resources.wheat * MARKET_PRICES.wheat}</div>
              </div>
              <div className="rounded-lg bg-blue-900/30 p-4 text-center border border-blue-700">
                <div className="text-sm text-blue-300">🌊 Hay</div>
                <div className="text-2xl font-bold text-blue-400">{resources.hay}</div>
                <div className="text-xs text-blue-300">${resources.hay * MARKET_PRICES.hay}</div>
              </div>
            </div>

            {/* Sale Animation */}
            {stage === 'sale' && (
              <div className="text-center">
                <h2 className="text-2xl font-bold text-yellow-400 mb-2">💰 SELLING AT MARKET</h2>
                <p className="text-slate-300">Converting crops to coin...</p>
                <div className="mt-4 inline-flex items-center gap-2 text-yellow-300">
                  <div className="h-3 w-3 animate-spin rounded-full border-2 border-yellow-400 border-t-transparent" />
                  Calculating profit...
                </div>
              </div>
            )}

            {/* Profit Display */}
            {(stage === 'review' || stage === 'complete') && (
              <div className={`rounded-lg border-2 ${profitTier.bg} p-6 text-center`}>
                <div className="text-sm uppercase tracking-widest text-slate-300 mb-2">Season Profit</div>
                <div className={`text-5xl font-bold ${profitTier.color} mb-2`}>
                  {profit >= 0 ? '+' : ''}${displayProfit}
                </div>
                <div className={`text-lg font-semibold ${profitTier.color}`}>
                  {profitTier.tier} Season
                </div>
              </div>
            )}

            {/* Agent Review */}
            {(stage === 'review' || stage === 'complete') && (
              <div className="rounded-lg border border-slate-600 bg-slate-800 p-4">
                <div className="text-sm font-semibold text-slate-300 mb-2">👥 Agent Review</div>
                {reviewSource === 'loading' ? (
                  <div className="text-center text-slate-400 text-sm">
                    <div className="inline-flex items-center gap-2">
                      <div className="h-3 w-3 animate-spin rounded-full border-2 border-yellow-400 border-t-transparent" />
                      Gathering thoughts...
                    </div>
                  </div>
                ) : (
                  <>
                    <p className="text-slate-200 text-center">{review}</p>
                    <div className="mt-3 text-xs text-slate-500 text-center">
                      {reviewSource === 'claude' && '✨ Powered by Claude'}
                    </div>
                  </>
                )}
                <div className="mt-3 text-xs text-slate-400 text-center">
                  Average Morale: <span className="font-bold text-slate-200">{avgMorale}%</span>
                </div>
              </div>
            )}

            {/* Complete Button */}
            {stage === 'complete' && (
              <button
                onClick={completeSeason}
                className="w-full rounded-lg bg-blue-600 hover:bg-blue-500 text-white font-bold py-3 transition-all active:scale-95"
              >
                🔄 Start Next Season
              </button>
            )}
          </div>
        )}

        {/* Season Info */}
        <div className="mt-6 text-center text-xs text-slate-400">
          Season {season.seasonNumber} Complete • Sale Day
        </div>
      </div>
    </div>
  );
}
