# Payday Kingdom - Bug Fixes (Post-Launch)

Reported by Dan after live deployment. All bugs reproduced on desktop + mobile.

---

## BUG 1: Settings Modal Trap (CRITICAL)

**Severity:** Critical UX blocker
**Location:** `src/components/ui/KingdomSetup.jsx` or HUD settings integration
**Repro:**
1. Click settings gear icon in HUD
2. Settings panel/modal appears
3. Try clicking "Save", "Cancel", or "Replay Onboarding" buttons
4. Nothing happens. Buttons don't respond.
5. Can't escape modal. Must kill browser tab.

**Root Cause:** Likely the modal is rendering but onClick handlers aren't wired, or state isn't being passed correctly.

**Fix:**
- Check `KingdomSetup.jsx` — ensure modal has `onClose`, `onSave`, `onCancel` callbacks wired
- Verify `HUD.jsx` is passing these callbacks to the settings modal
- Test all three buttons: Save (close + persist), Cancel (close without change), Replay (reset onboarding flag)
- Ensure keyboard escape key also closes modal (`onKeyDown` handler)

**Acceptance:**
- ✅ Click settings gear → modal opens
- ✅ Click "Save" → modal closes, changes persist
- ✅ Click "Cancel" → modal closes, changes revert
- ✅ Click "Replay Onboarding" → modal closes, onboarding-complete flag resets, page reload shows onboarding
- ✅ Press ESC key → modal closes
- ✅ Can click outside modal to close (if using backdrop)

---

## BUG 2: Onboarding Income Input Resets Flow (CRITICAL)

**Severity:** Critical UX blocker
**Location:** `src/components/onboarding/OnboardingFlow.jsx` (Screen 3: Set Your Income)
**Repro:**
1. Complete onboarding screens 1-2 (Welcome, Name Kingdom)
2. Reach Screen 3: "Set Your Income"
3. Click on income input field
4. Type first digit (e.g., "3")
5. **RESET:** Flow jumps back to Screen 1 (Welcome)
6. Repeat — same issue on every digit

**Root Cause:** Input onChange handler is likely triggering a state update that's resetting the step counter. Could be:
- Unintended re-render of parent component
- Step counter being reset in useEffect somewhere
- Input handler calling wrong state setter
- Form validation triggering a reset

**Fix:**
- Check `OnboardingFlow.jsx` — Screen 3 income input handler
- Verify `setStep` is NOT being called from input handlers
- Ensure input handler ONLY updates income state, not step state
- Check for any useEffect that might be resetting step on income change
- Verify `onChange` handler is properly debounced/memoized if needed

**Acceptance:**
- ✅ Screen 3 input field appears
- ✅ Click input → focus (no reset)
- ✅ Type digit "3" → "3" appears in field (no reset)
- ✅ Type digit "2" → "32" appears in field (no reset)
- ✅ Type full amount "$3200" → stays on Screen 3
- ✅ Click "Continue →" → moves to Screen 4 (Add Monsters)

---

## BUG 3: XP Bar Depletes After Payday (Visual Feedback)

**Severity:** Important (cosmetic, but confusing feedback)
**Location:** `src/components/ui/HUD.jsx` (XP bar display)
**Repro:**
1. Enter income, add bills
2. Trigger payday
3. XP bar fills up as expected
4. **AFTER battle completes:** XP bar visibly depletes/resets
5. Trigger payday again → bar fills again
6. Repeat — bar always depletes after each battle

**Expected Behavior:** XP bar should show cumulative progress toward next level. After defeating monsters, XP should ADD to existing XP (never deplete).

**Root Cause:** XP bar is probably resetting its internal state or being calculated as `currentXP % xpThreshold` instead of showing absolute progress.

**Fix:**
- Check `HUD.jsx` — XP bar calculation/display
- Check `gameStore.js` — verify XP is CUMULATIVE (never resets, only increments)
- Verify HUD is showing `(currentXP / xpThresholdForNextLevel) * 100%` for bar width
- After payday, XP should visibly accumulate toward next level threshold
- Visual feedback: bar should fill continuously, never empty (except on level up, where it resets to 0 and starts climbing again for the NEW level)

**Acceptance:**
- ✅ Start at Level 1, 0 XP
- ✅ Trigger payday (e.g., gain 1000 XP)
- ✅ XP bar fills to show ~30% (1000/3000 threshold for level 2)
- ✅ Bar STAYS at 30% (no depletion)
- ✅ Trigger payday again (gain 1000 more XP = 2000 total)
- ✅ Bar fills to ~67% (2000/3000)
- ✅ Trigger payday again (gain 1000 more XP = 3000 total)
- ✅ Level up triggers → bar resets to 0%, level is now 2
- ✅ Next XP gain visibly starts filling bar from 0% again (toward 6000 threshold for level 3)

---

## BUG 4: Island Crowding (Visual/Gameplay)

**Severity:** Medium (gameplay usability)
**Location:** `src/components/scene/IslandScene.jsx` + `src/utils/budgetSceneBuilder.js`
**Repro:**
1. Add 5-6 bills
2. Trigger payday multiple times (level up, island grows)
3. As island stage increases, more objects spawn (trees, buildings, decorations)
4. **RESULT:** Island gets visually crowded, hard to see hero or monsters

**Expected Behavior:** Island should remain visually manageable at all stages.

**Possible Fixes (choose one or combine):**
- **Zoom out slightly** as island stage increases (camera position adjustment)
- **Increase island grid size** so objects have more space (e.g., 8x8 → 12x12)
- **Cull/remove old objects** as new ones spawn (keep max object count)
- **Scale objects smaller** as island stage increases
- **Improve camera view** — allow user to zoom/pan to see full island

**Acceptance:**
- ✅ Island stage 0 (barren) — clear, easy to see hero/monsters
- ✅ Island stage 3 (town) — still visible, not overcrowded
- ✅ Island stage 5+ (kingdom) — can still see most objects, hero is visible
- ✅ Camera angle/zoom automatically adjusts to fit island content
- ✅ No visual clipping or overlapping that obscures gameplay

---

## Build Order

**DO THIS FIRST (critical UX blockers):**
1. BUG 1: Settings modal escape
2. BUG 2: Onboarding income input

**THEN (nice-to-have polish):**
3. BUG 3: XP bar depletion
4. BUG 4: Island crowding

---

## Testing After Fixes

1. Fresh incognito browser
2. Go through full onboarding (should not reset on input)
3. Set income $3200, add bills
4. Trigger payday 3-4 times, watch XP bar accumulate smoothly
5. Open settings gear → change kingdom name → save → verify it persists
6. Open settings again → click cancel → verify changes don't persist
7. Mobile: Same flow, plus verify settings modal can be closed on mobile
8. Build + deploy to Vercel, test live

---

## Git Workflow

```bash
git add src/components/ui/KingdomSetup.jsx src/components/onboarding/OnboardingFlow.jsx src/components/ui/HUD.jsx src/utils/budgetSceneBuilder.js
git commit -m "Fix: Settings modal escape, onboarding input reset, XP bar display, island crowding"
git push origin main
# Vercel auto-deploys
```

---

## Notes

- All bugs are post-launch and non-critical (app is playable)
- Dan's assessment: "solid flow, not glitchy or cheap, looks snappy, feels snappy" — good sign
- Focus on UX blockers first (Settings modal, Onboarding input)
- Visual polish (XP bar, island crowding) can be iterated on based on user feedback
