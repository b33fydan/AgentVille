import { useEffect, useState } from 'react';
import { useAgentStore } from '../../store/agentStore';
import { useGameStore } from '../../store/gameStore';
import { useLogStore } from '../../store/logStore';
import { soundManager } from '../../utils/soundManager';
import { generateAgentReview } from '../../utils/claudeService';
import { MoraleConsequenceQueue } from '../../utils/moraleConsequences';
import { cardGenerator } from '../../utils/cardGenerator';
import ShareModal from './ShareModal';

const MARKET_PRICES = {
  wood: 2,
  wheat: 5,
  hay: 3
};

export default function SaleDay() {
  const season = useGameStore((state) => state.season);
  const day = useGameStore((state) => state.day);
  const timeOfDay = useGameStore((state) => state.timeOfDay);
  const resources = useGameStore((state) => state.resources);
  const agents = useAgentStore((state) => state.agents);
  const endSeason = useGameStore((state) => state.endSeason);
  const getProfit = useGameStore((state) => state.getProfit);
  const getAverageMorale = useAgentStore((state) => state.getAverageMorale);

  const [stage, setStage] = useState('harvest'); // harvest → sale → review → complete
  const [displayProfit, setDisplayProfit] = useState(0);
  const [review, setReview] = useState('');
  const [reviewSource, setReviewSource] = useState('loading'); // loading | claude | template
  const [strikeActive, setStrikeActive] = useState(false);
  const [resourcePenalty, setResourcePenalty] = useState(0); // 0.5 if strike, 1.0 if normal
  const [seasonCard, setSeasonCard] = useState(null);
  const [showShareModal, setShowShareModal] = useState(false);

  const addLogEntry = useLogStore((state) => state.addLogEntry);
  const addResource = useGameStore((state) => state.addResource);
  const setResource = useGameStore((state) => state.setResource);

  const profit = getProfit();
  const avgMorale = getAverageMorale();

  // Play sounds when stage changes
  useEffect(() => {
    if (stage === 'review') {
      // Play agent review sounds (one per agent)
      agents.forEach((_, idx) => {
        setTimeout(() => {
          soundManager.play('agentReview');
        }, idx * 500);
      });
    } else if (stage === 'complete') {
      // Play season complete fanfare
      soundManager.play('seasonComplete');
    }
  }, [stage, agents]);

  // Generate season card when complete
  useEffect(() => {
    if (stage !== 'complete' || seasonCard) return;

    const generateCard = async () => {
      const screenshotUrl = document.querySelector('canvas')?.toDataURL('image/png');

      const cardData = {
        season,
        islandName: agents[0]?.islandName || 'My Island', // Get from first agent or game state
        profit: displayProfit,
        profitTier: profit > 50 ? 'GREAT SEASON' : profit > 0 ? 'GOOD SEASON' : 'ROUGH SEASON',
        agents: agents.map((a) => ({
          name: a.name,
          level: a.level || 1,
          color: a.appearance?.bodyColor,
          quote: review // Use the season review as agent quote for now
        })),
        resources: resources,
        crisisFaced: crisisLog.length,
        crisisResolved: crisisLog.filter((c) => c.outcome).length,
        avgMorale: Math.round(getAverageMorale()),
        screenshotUrl
      };

      const card = await cardGenerator.generateCard('season', cardData);
      setSeasonCard(card);
      setShowShareModal(true);
    };

    generateCard();
  }, [stage, season, displayProfit, agents, review, crisisLog, resources, getAverageMorale, seasonCard]);

  // Check for strike on first load (harvest phase)
  useEffect(() => {
    if (stage !== 'harvest' || resourcePenalty !== 0) return;

    const queue = new MoraleConsequenceQueue();
    const strike = queue.checkStrike(avgMorale, day);

    if (strike) {
      setStrikeActive(true);
      setResourcePenalty(0.5); // 50% harvest
      
      // Apply penalty to all resources
      setTimeout(() => {
        setResource('wood', Math.floor(resources.wood * 0.5));
        setResource('wheat', Math.floor(resources.wheat * 0.5));
        setResource('hay', Math.floor(resources.hay * 0.5));

        // Log the strike
        addLogEntry({
          agentId: null,
          agentName: 'Team',
          type: 'strike',
          message: `⛔ The team refused to work! Resources harvested at 50% capacity.`,
          emoji: '✊'
        });

        soundManager.playNegative();
      }, 500);
    } else {
      setResourcePenalty(1.0); // Normal harvest
    }
  }, [stage, day]);

  // Fetch Claude review when entering review stage
  useEffect(() => {
    if (stage !== 'review' || review !== '') return;

    const fetchReview = async () => {
      const result = await generateAgentReview({
        agentNames: agents.map(a => a.name).join(', '),
        avgMorale,
        profit,
        season
      });
      setReview(result.review);
      setReviewSource(result.source);
    };

    fetchReview();
  }, [stage, review, agents, avgMorale, profit, season]);

  // Auto-progress through stages
  useEffect(() => {
    if (day !== 7 || timeOfDay !== 'evening') return;

    const timings = {
      harvest: 2000,
      sale: 3000,
      review: 4000
    };

    const timer = setTimeout(() => {
      if (stage === 'harvest') {
        setStage('sale');
      } else if (stage === 'sale') {
        // Play profit reveal sound (play during animation)
        const tickInterval = setInterval(() => {
          soundManager.play('harvestTally');
        }, 100);

        setTimeout(() => {
          clearInterval(tickInterval);
          // Final reveal sound
          if (profit > 0) {
            soundManager.play('profitReveal');
          } else {
            soundManager.play('profitRevealBad');
          }
        }, 1500);

        // Animate profit counter
        if (profit === 0) {
          setDisplayProfit(0);
        } else {
          setDisplayProfit(0);
          let current = 0;
          const step = profit > 0 ? Math.ceil(profit / 20) : Math.floor(profit / 20);
          const interval = setInterval(() => {
            current += step;
            if ((step > 0 && current >= profit) || (step < 0 && current <= profit)) {
              setDisplayProfit(profit);
              clearInterval(interval);
            } else {
              setDisplayProfit(current);
            }
          }, 50);
        }
        setStage('review');
      } else if (stage === 'review') {
        setStage('complete');
      }
    }, timings[stage] || 0);

    return () => clearTimeout(timer);
  }, [day, timeOfDay, stage, profit]);

  // Only show on Day 7 evening (player gets full Day 7 morning first)
  if (day !== 7 || timeOfDay !== 'evening') {
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
            
            {strikeActive && (
              <div className="mt-6 rounded-lg border-2 border-red-600 bg-red-900/20 p-4">
                <div className="text-2xl font-bold text-red-400 mb-2">⛔ STRIKE!</div>
                <div className="text-sm text-red-200">
                  Your team refused to work due to low morale.
                </div>
                <div className="text-xs text-red-300 mt-2">
                  Resources harvested at 50% capacity instead of 100%.
                </div>
              </div>
            )}
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
                onClick={() => endSeason({ profit, finalMorale: avgMorale, events: [] })}
                className="w-full rounded-lg bg-blue-600 hover:bg-blue-500 text-white font-bold py-3 transition-all active:scale-95"
              >
                🔄 Start Next Season
              </button>
            )}
          </div>
        )}

        {/* Season Info */}
        <div className="mt-6 text-center text-xs text-slate-400">
          Season {season} Complete • Sale Day
        </div>
      </div>

      {/* Share Modal */}
      {showShareModal && (
        <ShareModal
          card={seasonCard}
          title="📸 Your Season Card"
          onClose={() => setShowShareModal(false)}
        />
      )}
    </div>
  );
}
