import { useEffect, useMemo, useState, useSyncExternalStore } from 'react';
import { useBudgetStore } from '../../store/budgetStore.js';
import { LEVEL_THRESHOLDS, useGameStore } from '../../store/gameStore.js';
import CaptureButton from './CaptureButton.jsx';
import KingdomSetup from './KingdomSetup.jsx';
import { soundManager } from '../../utils/soundManager.js';

const ARMOR_LABELS = {
  peasant: 'Peasant',
  recruit: 'Recruit',
  soldier: 'Soldier',
  knight: 'Knight',
  champion: 'Champion',
  legend: 'Legend'
};

const ARMOR_COLORS = {
  peasant: '#b0885a',
  recruit: '#b8a17f',
  soldier: '#cd7f32',
  knight: '#c0c0c0',
  champion: '#d4af37',
  legend: '#dbeafe'
};

const STAGE_LABELS = ['Barren', 'Sprout', 'Settlement', 'Village', 'Town', 'Castle', 'Kingdom'];

function formatCurrency(value) {
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD',
    maximumFractionDigits: 0
  }).format(Number(value) || 0);
}

function formatNumber(value) {
  return new Intl.NumberFormat('en-US').format(Number(value) || 0);
}

function computeXPWindow(xp, level) {
  const previousThreshold = level <= 1 ? 0 : LEVEL_THRESHOLDS[level - 2] ?? LEVEL_THRESHOLDS.at(-1) ?? 0;
  const nextThreshold = LEVEL_THRESHOLDS[level - 1] ?? previousThreshold;
  return {
    current: Math.max(0, Math.round(xp)),
    next: nextThreshold,
    progress: nextThreshold <= previousThreshold ? 100 : ((xp - previousThreshold) / (nextThreshold - previousThreshold)) * 100
  };
}

export default function HUD({ captureContext = null, onReplayOnboarding = null }) {
  const level = useGameStore((state) => state.level);
  const armorTier = useGameStore((state) => state.armorTier);
  const xp = useGameStore((state) => state.xp);
  const battleDisplayXP = useGameStore((state) => state.battleDisplayXP);
  const islandStage = useGameStore((state) => state.islandStage);
  const monthsCompleted = useGameStore((state) => state.monthsCompleted);
  const totalBillsSlain = useGameStore((state) => state.totalBillsSlain);
  const hudAnnouncement = useGameStore((state) => state.hudAnnouncement);
  const clearHUDAnnouncement = useGameStore((state) => state.clearHUDAnnouncement);

  const history = useBudgetStore((state) => state.history);
  const kingdomName = useBudgetStore((state) => state.kingdomName || 'My Payday Kingdom');

  const [overlay, setOverlay] = useState(null);
  const [isCaptureInProgress, setIsCaptureInProgress] = useState(false);
  const [isSettingsOpen, setIsSettingsOpen] = useState(false);

  const muted = useSyncExternalStore(
    (listener) => soundManager.subscribe(listener),
    () => soundManager.isMuted(),
    () => soundManager.isMuted()
  );

  const hasBattleDisplayXP = battleDisplayXP !== null && battleDisplayXP !== undefined;
  const visualXP = hasBattleDisplayXP && Number.isFinite(Number(battleDisplayXP)) ? Number(battleDisplayXP) : xp;
  const xpWindow = useMemo(() => computeXPWindow(visualXP, level), [visualXP, level]);

  const totalSaved = useMemo(
    () => history.reduce((sum, month) => sum + (Number(month?.surplus) || 0), 0),
    [history]
  );

  const armorLabel = ARMOR_LABELS[armorTier] ?? 'Peasant';
  const armorColor = ARMOR_COLORS[armorTier] ?? ARMOR_COLORS.peasant;
  const stageLabel = STAGE_LABELS[Math.max(0, Math.min(STAGE_LABELS.length - 1, islandStage))] ?? STAGE_LABELS[0];

  useEffect(() => {
    if (!hudAnnouncement) {
      return undefined;
    }

    const holdMs = hudAnnouncement.type === 'level-up' ? 2200 : 2000;
    setOverlay({ ...hudAnnouncement, visible: true });

    const fadeTimer = window.setTimeout(() => {
      setOverlay((current) => (current ? { ...current, visible: false } : current));
    }, holdMs - 350);

    const clearTimer = window.setTimeout(() => {
      setOverlay(null);
      clearHUDAnnouncement();
    }, holdMs);

    return () => {
      window.clearTimeout(fadeTimer);
      window.clearTimeout(clearTimer);
    };
  }, [hudAnnouncement, clearHUDAnnouncement]);

  return (
    <>
      <div
        className={`pointer-events-none absolute inset-0 z-30 p-3 transition-opacity duration-150 sm:p-4 ${
          isCaptureInProgress ? 'pointer-events-none opacity-0' : 'opacity-100'
        }`}
      >
        <div className="flex items-start justify-between gap-3">
          <section className="max-w-[72%] rounded-lg border border-white/20 bg-black/50 px-3 py-2 shadow-lg sm:max-w-sm">
            <p className="font-pixel text-[0.58rem] leading-relaxed text-amber-200 sm:text-[0.65rem]">{kingdomName}</p>
            <p className="font-pixel text-[0.62rem] leading-relaxed text-white sm:text-xs">LEVEL {level}</p>
            <p className="mt-1 font-pixel text-[0.68rem] leading-relaxed sm:text-sm" style={{ color: armorColor }}>
              {armorLabel}
            </p>
            <div className="mt-2 font-sans text-[0.68rem] text-slate-100 sm:text-xs">
              XP: {formatNumber(xpWindow.current)}/{formatNumber(xpWindow.next)}
            </div>
            <div className="mt-1 h-3 w-full overflow-hidden rounded-full bg-slate-900/80">
              <div
                className="h-full transition-[width] duration-500 ease-out"
                style={{
                  width: `${Math.max(0, Math.min(100, xpWindow.progress))}%`,
                  backgroundImage: 'linear-gradient(90deg, #22c55e 0%, #facc15 100%)'
                }}
              />
            </div>
          </section>

          <section className="pointer-events-none flex flex-col items-end gap-2">
            <div className="pointer-events-auto flex items-center gap-2 rounded-lg border border-white/20 bg-black/50 p-1.5 shadow-lg">
              <CaptureButton captureContext={captureContext} onCaptureStateChange={setIsCaptureInProgress} />
              <button
                type="button"
                onClick={() => soundManager.toggleMuted()}
                className="min-h-11 min-w-11 rounded-md border border-white/25 bg-slate-800/80 px-2 text-lg leading-none text-white transition-colors hover:bg-slate-700"
                aria-label={muted ? 'Unmute sounds' : 'Mute sounds'}
                title={muted ? 'Unmute sounds' : 'Mute sounds'}
              >
                {muted ? '🔇' : '🔊'}
              </button>
              <button
                type="button"
                onClick={() => setIsSettingsOpen(true)}
                className="min-h-11 min-w-11 rounded-md border border-white/25 bg-slate-800/80 px-2 text-lg leading-none text-white transition-colors hover:bg-slate-700"
                aria-label="Open settings"
                title="Settings"
              >
                ⚙️
              </button>
            </div>
          </section>
        </div>

        <div className="absolute bottom-3 left-3 max-w-[85%] rounded-lg border border-white/20 bg-black/50 px-3 py-2 shadow-lg sm:bottom-4 sm:left-4 sm:max-w-sm">
          <p className="font-pixel text-[0.62rem] leading-relaxed text-white sm:text-xs">
            {stageLabel.toUpperCase()} (STAGE {islandStage})
          </p>
          <div className="mt-1 space-y-0.5 font-sans text-[0.68rem] text-slate-100 sm:text-xs">
            <p>Month #{monthsCompleted}</p>
            <p>Bills Slain: {formatNumber(totalBillsSlain)}</p>
            <p>Total Saved: {formatCurrency(totalSaved)}</p>
          </div>
        </div>

        {overlay && (
          <div className="absolute inset-0 flex items-center justify-center px-4">
            <div
              className={`rounded-xl border px-4 py-3 text-center shadow-[0_10px_30px_rgba(0,0,0,0.4)] transition-opacity duration-300 sm:px-6 sm:py-4 ${
                overlay.type === 'level-up'
                  ? 'border-amber-200/70 bg-amber-200/20 text-amber-100'
                  : 'border-white/60 bg-slate-950/75 text-white'
              } ${overlay.visible ? 'opacity-100' : 'opacity-0'}`}
            >
              <p className="font-pixel text-sm leading-relaxed sm:text-lg">{overlay.headline}</p>
              {overlay.subtitle ? <p className="mt-2 font-sans text-xs sm:text-sm">{overlay.subtitle}</p> : null}
            </div>
          </div>
        )}
      </div>

      <KingdomSetup
        isOpen={isSettingsOpen}
        mode="edit"
        onClose={() => setIsSettingsOpen(false)}
        onCancel={() => setIsSettingsOpen(false)}
        onSaved={() => {
          setIsSettingsOpen(false);
        }}
        showReplayOnboarding={typeof onReplayOnboarding === 'function'}
        onReplayOnboarding={() => {
          setIsSettingsOpen(false);
          onReplayOnboarding?.();
        }}
      />
    </>
  );
}
