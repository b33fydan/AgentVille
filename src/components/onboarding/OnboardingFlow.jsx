import { useEffect, useMemo, useState } from 'react';
import { useBudgetStore } from '../../store/budgetStore.js';
import { KINGDOM_COLOR_OPTIONS } from '../../utils/kingdomTheme.js';

const BILL_CATEGORIES = [
  { value: 'housing', label: 'Housing' },
  { value: 'utilities', label: 'Utilities' },
  { value: 'phone', label: 'Phone' },
  { value: 'transport', label: 'Transport' },
  { value: 'food', label: 'Food' },
  { value: 'entertainment', label: 'Entertainment' },
  { value: 'other', label: 'Other' }
];

function toNumber(value) {
  const next = Number(value);
  return Number.isFinite(next) ? next : 0;
}

function lerp(start, end, t) {
  return start + (end - start) * t;
}

export default function OnboardingFlow({ isOpen, captureContext, onComplete }) {
  const kingdomName = useBudgetStore((state) => state.kingdomName || 'My Payday Kingdom');
  const bannerColor = useBudgetStore((state) => state.bannerColor || 'gold');
  const income = useBudgetStore((state) => state.income);
  const bills = useBudgetStore((state) => state.bills);
  const setKingdomName = useBudgetStore((state) => state.setKingdomName);
  const setBannerColor = useBudgetStore((state) => state.setBannerColor);
  const setIncome = useBudgetStore((state) => state.setIncome);
  const addBill = useBudgetStore((state) => state.addBill);
  const removeBill = useBudgetStore((state) => state.removeBill);

  const [step, setStep] = useState(0);
  const [nameDraft, setNameDraft] = useState(kingdomName);
  const [colorDraft, setColorDraft] = useState(bannerColor);
  const [incomeDraft, setIncomeDraft] = useState(income > 0 ? String(income) : '');
  const [billDraft, setBillDraft] = useState({
    name: '',
    amount: '',
    category: 'housing'
  });
  const [error, setError] = useState('');

  const floatingCubes = useMemo(
    () =>
      Array.from({ length: 16 }, (_, index) => ({
        id: index,
        size: 10 + (index % 5) * 6,
        left: `${(index * 17) % 97}%`,
        top: `${(index * 29) % 88}%`,
        delay: `${(index * 0.4).toFixed(2)}s`,
        duration: `${6 + (index % 6)}s`
      })),
    []
  );

  useEffect(() => {
    if (!isOpen) {
      return;
    }

    setStep(0);
    setNameDraft(kingdomName);
    setColorDraft(bannerColor);
    setIncomeDraft(income > 0 ? String(income) : '');
    setBillDraft({ name: '', amount: '', category: 'housing' });
    setError('');
  }, [isOpen]);

  useEffect(() => {
    if (!isOpen || step !== 4 || !captureContext?.camera) {
      return;
    }

    const camera = captureContext.camera;
    const controls = captureContext.controls;

    const start = {
      x: camera.position.x,
      y: camera.position.y,
      z: camera.position.z
    };
    const from = {
      x: start.x * 1.9,
      y: start.y * 1.9,
      z: start.z * 1.9
    };
    const to = {
      x: 7.8,
      y: 7.8,
      z: 7.8
    };

    camera.position.set(from.x, from.y, from.z);
    controls?.target?.set(0, 0.4, 0);
    controls?.update?.();

    const duration = 1200;
    let rafId = 0;
    const startTime = performance.now();

    const tick = (now) => {
      const t = Math.min(1, (now - startTime) / duration);
      const eased = 1 - (1 - t) ** 3;

      camera.position.set(lerp(from.x, to.x, eased), lerp(from.y, to.y, eased), lerp(from.z, to.z, eased));
      controls?.target?.set(0, 0.4, 0);
      controls?.update?.();

      if (t < 1) {
        rafId = window.requestAnimationFrame(tick);
      }
    };

    rafId = window.requestAnimationFrame(tick);

    return () => {
      window.cancelAnimationFrame(rafId);
    };
  }, [isOpen, step, captureContext]);

  if (!isOpen) {
    return null;
  }

  const goNext = () => {
    setError('');

    if (step === 1 && !nameDraft.trim()) {
      setError('Name your kingdom before continuing.');
      return;
    }

    if (step === 1) {
      setKingdomName(nameDraft);
      setBannerColor(colorDraft);
    }

    if (step === 2) {
      const parsed = toNumber(incomeDraft);
      if (parsed <= 0) {
        setError('Enter a monthly income greater than 0.');
        return;
      }
      setIncome(parsed);
    }

    if (step === 3 && bills.length < 1) {
      setError('Add at least one monster to continue.');
      return;
    }

    if (step >= 4) {
      onComplete?.();
      return;
    }

    setStep((current) => current + 1);
  };

  const addMonster = () => {
    const trimmedName = billDraft.name.trim();
    const parsedAmount = toNumber(billDraft.amount);

    if (!trimmedName || parsedAmount <= 0) {
      setError('Enter a valid bill name and amount.');
      return;
    }

    addBill({
      name: trimmedName,
      amount: parsedAmount,
      category: billDraft.category,
      dueDay: 1
    });

    setBillDraft((current) => ({
      ...current,
      name: '',
      amount: ''
    }));
    setError('');
  };

  const headingClass = 'font-pixel text-base leading-relaxed text-white sm:text-xl';

  return (
    <div className={`fixed inset-0 z-[80] overflow-y-auto ${step === 4 ? 'bg-black/60' : 'bg-black/90'}`}>
      <div className="pointer-events-none absolute inset-0 overflow-hidden">
        {floatingCubes.map((cube) => (
          <span
            key={cube.id}
            className="absolute block rounded-sm border border-white/20 bg-white/5 onboarding-cube"
            style={{
              width: cube.size,
              height: cube.size,
              left: cube.left,
              top: cube.top,
              animationDelay: cube.delay,
              animationDuration: cube.duration
            }}
          />
        ))}
      </div>

      <div className="relative flex min-h-screen items-center justify-center p-4">
        <section className="onboarding-fade-in w-full max-w-2xl rounded-2xl border border-white/20 bg-slate-950/90 p-5 text-white shadow-2xl sm:p-8">
          {step === 0 && (
            <div>
              <h1 className={headingClass}>Welcome, Brave Soul.</h1>
              <p className="mt-4 text-sm leading-7 text-slate-200 sm:text-base">
                In Payday Kingdom, your financial discipline builds a thriving world.
                <br />
                Turn bills into epic battles. Watch your kingdom grow.
                <br />
                Every payday is a chance to level up.
              </p>
            </div>
          )}

          {step === 1 && (
            <div>
              <h1 className={headingClass}>What Is Your Kingdom Called?</h1>
              <input
                type="text"
                value={nameDraft}
                onChange={(event) => setNameDraft(event.target.value)}
                placeholder="My Payday Kingdom"
                className="mt-4 min-h-11 w-full rounded-lg border border-white/25 bg-slate-900 px-3 py-2 text-sm text-white outline-none focus:border-amber-300"
              />

              <div className="mt-4 grid grid-cols-3 gap-2 sm:grid-cols-6">
                {KINGDOM_COLOR_OPTIONS.map((option) => {
                  const selected = colorDraft === option.id;
                  return (
                    <button
                      key={option.id}
                      type="button"
                      onClick={() => setColorDraft(option.id)}
                      className={`min-h-11 rounded-lg border px-2 py-2 text-xs font-semibold uppercase tracking-wide transition ${
                        selected ? 'border-amber-200 ring-2 ring-amber-300/70' : 'border-white/25'
                      }`}
                      style={{ backgroundColor: option.hex, color: option.id === 'gold' ? '#111827' : '#ffffff' }}
                    >
                      {option.label}
                    </button>
                  );
                })}
              </div>
            </div>
          )}

          {step === 2 && (
            <div>
              <h1 className={headingClass}>How Much Treasure Arrives Each Month?</h1>
              <p className="mt-3 text-sm text-slate-300">Enter your monthly income.</p>
              <div className="mt-4 flex min-h-11 items-center gap-2 rounded-lg border border-white/25 bg-slate-900 px-3 py-2">
                <span className="text-amber-300">$</span>
                <input
                  type="number"
                  min="0"
                  inputMode="decimal"
                  value={incomeDraft}
                  onChange={(event) => setIncomeDraft(event.target.value)}
                  className="w-full bg-transparent text-lg text-white outline-none"
                  placeholder="3000"
                />
              </div>
            </div>
          )}

          {step === 3 && (
            <div>
              <h1 className={headingClass}>What Monsters Threaten Your Realm?</h1>
              <p className="mt-3 text-sm text-slate-300">Add your monthly bills. At least one required.</p>

              <div className="mt-4 grid grid-cols-1 gap-2 sm:grid-cols-3">
                <input
                  type="text"
                  placeholder="Name"
                  value={billDraft.name}
                  onChange={(event) => setBillDraft((current) => ({ ...current, name: event.target.value }))}
                  className="min-h-11 rounded-lg border border-white/25 bg-slate-900 px-3 text-sm outline-none focus:border-amber-300"
                />
                <input
                  type="number"
                  min="0"
                  inputMode="decimal"
                  placeholder="Amount"
                  value={billDraft.amount}
                  onChange={(event) => setBillDraft((current) => ({ ...current, amount: event.target.value }))}
                  className="min-h-11 rounded-lg border border-white/25 bg-slate-900 px-3 text-sm outline-none focus:border-amber-300"
                />
                <select
                  value={billDraft.category}
                  onChange={(event) => setBillDraft((current) => ({ ...current, category: event.target.value }))}
                  className="min-h-11 rounded-lg border border-white/25 bg-slate-900 px-3 text-sm outline-none focus:border-amber-300"
                >
                  {BILL_CATEGORIES.map((category) => (
                    <option key={category.value} value={category.value}>
                      {category.label}
                    </option>
                  ))}
                </select>
              </div>

              <button
                type="button"
                onClick={addMonster}
                className="mt-3 min-h-11 rounded-lg border border-emerald-200/30 bg-emerald-600/85 px-4 text-sm font-semibold text-white hover:bg-emerald-500"
              >
                + Add Another Monster
              </button>

              <div className="mt-3 max-h-32 overflow-y-auto rounded-lg border border-white/15 bg-black/35 p-2">
                {bills.length === 0 ? (
                  <p className="text-xs text-slate-400">No monsters added yet.</p>
                ) : (
                  bills.map((bill) => (
                    <div key={bill.id} className="flex items-center justify-between gap-3 py-1 text-xs text-slate-100 sm:text-sm">
                      <span>
                        {bill.name} (${Math.round(toNumber(bill.amount))})
                      </span>
                      <button
                        type="button"
                        onClick={() => removeBill(bill.id)}
                        className="rounded border border-rose-300/40 px-2 py-1 text-xs text-rose-200 hover:bg-rose-600/20"
                      >
                        Remove
                      </button>
                    </div>
                  ))
                )}
              </div>
            </div>
          )}

          {step === 4 && (
            <div>
              <h1 className={headingClass}>Your Kingdom Awaits.</h1>
              <p className="mt-4 text-sm leading-7 text-slate-200 sm:text-base">
                The island rises. Your hero stands ready.
                <br />
                Monsters gather as your first payday nears.
              </p>
            </div>
          )}

          {error ? <p className="mt-4 text-sm text-rose-300">{error}</p> : null}

          <div className="mt-6">
            <button
              type="button"
              onClick={goNext}
              className="min-h-11 w-full rounded-xl border border-amber-300/60 bg-amber-500/90 px-4 py-3 text-sm font-semibold text-slate-950 shadow-[0_0_20px_rgba(245,158,11,0.35)] transition hover:bg-amber-400 focus:outline-none focus:ring-2 focus:ring-amber-200/80 sm:text-base"
            >
              {step === 0 && 'Begin Your Journey'}
              {step === 1 && 'Continue'}
              {step === 2 && 'Continue'}
              {step === 3 && 'Forge My Kingdom'}
              {step === 4 && 'Ready for Payday?'}
            </button>
          </div>
        </section>
      </div>
    </div>
  );
}
