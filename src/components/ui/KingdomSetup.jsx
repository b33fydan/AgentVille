import { useEffect, useMemo, useState } from 'react';
import { useBudgetStore } from '../../store/budgetStore.js';
import { KINGDOM_COLOR_OPTIONS } from '../../utils/kingdomTheme.js';

export default function KingdomSetup({
  isOpen,
  mode = 'create',
  allowClose = true,
  onClose,
  onCancel,
  onSaved,
  showReplayOnboarding = false,
  onReplayOnboarding
}) {
  const kingdomName = useBudgetStore((state) => state.kingdomName || 'My Payday Kingdom');
  const bannerColor = useBudgetStore((state) => state.bannerColor || 'gold');
  const setKingdomName = useBudgetStore((state) => state.setKingdomName);
  const setBannerColor = useBudgetStore((state) => state.setBannerColor);

  const [draftName, setDraftName] = useState(kingdomName);
  const [draftColor, setDraftColor] = useState(bannerColor);

  useEffect(() => {
    if (!isOpen) {
      return;
    }

    setDraftName(kingdomName);
    setDraftColor(bannerColor);
  }, [isOpen, kingdomName, bannerColor]);

  useEffect(() => {
    if (!isOpen || !allowClose) {
      return;
    }

    const handleKeyDown = (event) => {
      if (event.key !== 'Escape') {
        return;
      }

      event.preventDefault();
      onCancel?.();
      onClose?.();
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => {
      window.removeEventListener('keydown', handleKeyDown);
    };
  }, [isOpen, allowClose, onCancel, onClose]);

  const isCreate = mode === 'create';
  const canSubmit = useMemo(() => draftName.trim().length > 0, [draftName]);

  if (!isOpen) {
    return null;
  }

  const handleSave = () => {
    if (!canSubmit) {
      return;
    }

    setKingdomName(draftName);
    setBannerColor(draftColor);

    if (isCreate) {
      onSaved?.();
      onClose?.();
      return;
    }

    onSaved?.();
    onClose?.();
  };

  const handleCancel = () => {
    onCancel?.();
    onClose?.();
  };

  return (
    <div
      className="pointer-events-auto fixed inset-0 z-[70] flex items-center justify-center bg-black/80 p-4"
      role="dialog"
      aria-modal="true"
      onClick={(event) => {
        if (!allowClose || event.target !== event.currentTarget) {
          return;
        }

        handleCancel();
      }}
    >
      <div
        className="w-full max-w-lg rounded-2xl border border-white/15 bg-slate-950 p-5 shadow-2xl sm:p-6"
        onClick={(event) => event.stopPropagation()}
      >
        <h2 className="font-pixel text-xs text-amber-300 sm:text-sm">{isCreate ? 'Name Your Kingdom' : 'Edit Kingdom'}</h2>
        <p className="mt-3 text-xs text-slate-300 sm:text-sm">
          {isCreate
            ? 'Choose a name and banner color for your realm.'
            : 'Update your kingdom identity. Changes are saved to local storage.'}
        </p>

        <label htmlFor="kingdom-name-input" className="mt-4 block text-xs font-semibold uppercase tracking-wide text-slate-400">
          Kingdom Name
        </label>
        <input
          id="kingdom-name-input"
          type="text"
          value={draftName}
          onChange={(event) => setDraftName(event.target.value)}
          placeholder="e.g., Fort Savings"
          className="mt-2 min-h-11 w-full rounded-lg border border-slate-600 bg-slate-900 px-3 py-2 text-sm text-slate-100 outline-none transition-colors focus:border-amber-300"
        />

        <p className="mt-4 text-xs font-semibold uppercase tracking-wide text-slate-400">Banner Color</p>
        <div className="mt-2 grid grid-cols-3 gap-2 sm:grid-cols-6">
          {KINGDOM_COLOR_OPTIONS.map((option) => {
            const selected = draftColor === option.id;
            return (
              <button
                key={option.id}
                type="button"
                onClick={() => setDraftColor(option.id)}
                className={`min-h-11 rounded-lg border px-2 py-2 text-xs font-semibold uppercase tracking-wide transition-transform hover:-translate-y-0.5 ${
                  selected ? 'border-amber-200 ring-2 ring-amber-300/70' : 'border-white/20'
                }`}
                style={{ backgroundColor: option.hex, color: option.id === 'gold' ? '#111827' : '#ffffff' }}
              >
                {option.label}
              </button>
            );
          })}
        </div>

        <div className="mt-5 flex flex-col gap-2 sm:flex-row">
          <button
            type="button"
            onClick={handleSave}
            disabled={!canSubmit}
            className="min-h-11 flex-1 rounded-lg bg-emerald-600 px-3 text-sm font-semibold text-white transition-colors hover:bg-emerald-500 disabled:cursor-not-allowed disabled:bg-slate-700 disabled:text-slate-400"
          >
            {isCreate ? 'Create Kingdom' : 'Save'}
          </button>

          {!isCreate && allowClose && (
            <button
              type="button"
              onClick={handleCancel}
              className="min-h-11 flex-1 rounded-lg border border-slate-500 bg-slate-800 px-3 text-sm font-semibold text-slate-100 transition-colors hover:bg-slate-700"
            >
              Cancel
            </button>
          )}
        </div>

        {showReplayOnboarding && !isCreate && (
          <button
            type="button"
            onClick={onReplayOnboarding}
            className="mt-3 min-h-11 w-full rounded-lg border border-sky-300/30 bg-sky-700/60 px-3 text-sm font-semibold text-white transition-colors hover:bg-sky-600"
          >
            Replay Onboarding
          </button>
        )}

        {allowClose && isCreate && (
          <button
            type="button"
            onClick={handleCancel}
            className="mt-3 min-h-11 w-full rounded-lg border border-slate-500 bg-slate-800 px-3 text-sm font-semibold text-slate-100 transition-colors hover:bg-slate-700"
          >
            Maybe Later
          </button>
        )}
      </div>
    </div>
  );
}
