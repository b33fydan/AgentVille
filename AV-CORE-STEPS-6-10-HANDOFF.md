# AV-CORE Steps 6-10 Handoff Document

**Status:** Steps 1-5 COMPLETE ✅ Game loop functional, sky blue background, animated water
**Remaining:** Steps 6-10 (visual polish) — Ready for Codex handoff

---

## What's Done (Steps 1-5)

✅ State verification + game loop wiring  
✅ Advance Day button working  
✅ Crisis system triggering + resolving  
✅ Sale Day sequence complete + season reset  
✅ Sky blue background + animated dual-layer water + camera improvements  

**Current State:** Game is fully playable. 7-day season → crisis → sale → repeat works without crashes.

---

## What's Remaining (Steps 6-10)

### **Step 6: Ground Grid Overhaul** (30 min)
**File:** `src/components/scene/IslandScene.jsx` (terrain setup section)

Current: 8×8 flat grid with uniform tiles  
Target: 16×16 grid with smaller cubes (0.5 unit each), terrain-based elevation, organic edges

**Implementation:**
1. Update `generateTerrainGrid()` in `terrainBuilder.js` to create 16×16 grid (256 tiles)
2. Each ground cube: BoxGeometry(0.5, 0.25, 0.5)
3. Elevation by terrain type:
   - Forest: Y = 0.15 to 0.35 (hilly, randomized per cube)
   - Plains: Y = 0.0 to 0.1 (mostly flat)
   - Wetlands: Y = -0.1 to 0.05 (low, some below water)
   - Barren: Y = 0.05 to 0.2 (rocky bumps)
4. Color per terrain (pick randomly from array per cube):
   - Forest: ['#15803d', '#166534', '#14532d', '#22c55e']
   - Plains: ['#ca8a04', '#a16207', '#eab308', '#d4a017']
   - Wetlands: ['#0891b2', '#0e7490', '#155e75', '#22d3ee']
   - Barren: ['#78716c', '#57534e', '#a8a29e', '#6b7280']
5. Add 3 cliff layers beneath (island edge treatment):
   - Layer 1: Edge cubes, Y offset -0.25, dirt brown, 20% random skip
   - Layer 2: Inset 1 cube from edge, Y offset -0.5, darker brown, 30% skip
   - Layer 3: Inset 2 cubes from edge, Y offset -0.75 to -1.0, stone, 40% skip
6. Use InstancedMesh for ground cubes (big win: 256 cubes → 1 draw call)

**Test:** Island should have visible depth, cliff edges, and no longer look like flat checkerboard.

---

### **Step 7: Terrain Props** (45 min)
**File:** `src/utils/terrainPropsBuilder.js` (refactor + expand)

Current: Basic terrain props exist  
Target: Rich visual identifiers for each zone

**Per Zone:**

**Forest:**
- 2-3 trees per tile (pine + oak variants)
- Pine: trunk (3 cubes brown) + 3-tier leaves (dark/medium/light green)
- Oak: thick trunk + 8-cube sphere canopy cluster
- Ground cover: 3-5 bushes, 1-2 rock clusters
- Log piles (scaled by wood count): 0→nothing, 1-5→2-3 cubes, 6-15→5-6, 16+→8-10

**Plains:**
- Wheat field: thin yellow rectangles (0.05×0.4×0.05), 8-12 per tile, rows
- Colors: ['#eab308', '#ca8a04', '#fbbf24'] randomized
- Optional: gentle sway animation (rotate Z ±3°)
- Farmhouse: 6w × 4d × 3h (0.25 unit cubes), warm brown, pitched roof, door/window
- Hay bales: 2×1×1 cluster of tan cubes, 1-3 per zone

**Wetlands:**
- Reeds: thin green rectangles (0.04×0.5×0.04), 6-10 per tile
- Colors: ['#22d3ee', '#0891b2', '#15803d'] (blue-green mix)
- Shallow water: 2-3 flat blue cubes at ground level, semi-transparent
- Optional: small dock (3-4 brown plank cubes)
- Hay bales with green tint

**Barren:**
- Rock clusters: 3-5 gray cubes (irregular piles), 1-2 per tile
- Dead trees: trunk only (no leaves), lean, 1 per 2-3 tiles
- Optional: bare branch

---

### **Step 8: Agent Character Upgrade** (20 min)
**File:** `src/utils/agentBuilder.js` (refactor agent models)

Current: Basic colored rectangles  
Target: 8-cube characters with hats, tools, proportions

**Per Agent Build (~8 cubes):**
- Legs: 2 cubes (0.12×0.25×0.12), gap between, darker than body
- Body: 1 cube (0.3×0.35×0.2), agent's bodyColor
- Arms: 2 cubes (0.08×0.25×0.08), body sides, body color
- Head: 1 cube (0.25×0.25×0.25), skin tone #fcd34d
- Eyes: 2 tiny cubes (0.06), dark #1e293b on head front
- Hat (based on specialization):
  - Wood: yellow hard hat (flat wide cube)
  - Wheat: tan straw hat
  - Hay: blue bandana
  - Generalist: none
- Tool (held to right, below arm):
  - Wood: axe (L-shape, 3 cubes)
  - Wheat: scythe (curved, 3 cubes)
  - Hay: pitchfork (3 prongs)
  - Generalist: nothing

**Height:** ~1.2 units (taller than wheat, shorter than trees)

**Animations:**
- Idle (unassigned): gentle Y bob (amplitude 0.05, period 2s)
- Working: arm rotation forward/back 30° on 1.5s loop
- Low morale (<40): body tilt Z 5°, slower work
- Very low (<20): no animation, standing still

**Morale Bar:**
- Floating above head (0.4 wide × 0.05 tall, 0.2 above)
- Green #22c55e >60%, yellow #eab308 30-60%, red #ef4444 <30%
- Billboard behavior (faces camera)

---

### **Step 9: Resource Piles** (15 min)
**File:** `src/utils/islandSceneManager.js` (add resource mesh management)

Current: Resources tracked in store  
Target: Visual piles on island, scaled by quantity

**Per Zone:**
- **Wood (forest):** Brown cubes stacked in pyramid
  - 0: nothing
  - 1-5: 2-3 cubes
  - 6-15: 5-6 cubes (small pile)
  - 16+: 8-10 cubes (visible stack)
- **Wheat (plains):** Golden cube clusters in neat rows
- **Hay (wetlands):** Tan rounded clusters, scattered

**Update trigger:** When `gameStore.resources` changes, rebuild piles (efficient: diffing)

---

### **Step 10: Camera + Lighting Tweaks** (10 min)
**File:** `src/components/scene/IslandScene.jsx` (already partially done in Step 5)

**What's Done:**
✅ FOV: 75 → 45
✅ Position: [10,10,10]
✅ Auto-rotate: enabled (0.3 speed)
✅ Min/max polar angles: set
✅ Hemisphere light: added

**What's Left (minimal):**
- Fine-tune directional light intensity (currently 0.8, try 0.7)
- Test shadow quality (reduce mapSize if FPS drops below 60)
- Verify camera zoom range feels natural (5-22 distance)

---

## Acceptance Criteria (After Steps 6-10)

- [ ] Island has visible cliff/earth layers beneath ground
- [ ] Water surrounds island with gentle animation
- [ ] Forest zones have 2+ trees per tile
- [ ] Plains zones have visible wheat stalks + farmhouse
- [ ] Wetlands zones have reeds/water patches
- [ ] Agents look like characters (head, body, legs, hat, tool)
- [ ] Agents animate when working (arm movement)
- [ ] Morale bars visible above agents
- [ ] Resource piles visible on island, scale with harvests
- [ ] Island reads as "miniature farm" from default camera
- [ ] 60 FPS maintained on modern browsers
- [ ] Full 7-day season playable without lag/crashes
- [ ] Can play 3+ consecutive seasons

---

## Code Structure Notes

**Key Files to Modify:**
- `src/components/scene/IslandScene.jsx` — main Three.js setup
- `src/utils/terrainBuilder.js` — 16×16 grid + elevation
- `src/utils/terrainPropsBuilder.js` — forest/plains/wetlands props
- `src/utils/agentBuilder.js` — character models + animations
- `src/utils/islandSceneManager.js` — resource pile management

**Performance Targets:**
- Total meshes: ~600-800 (ground 256 + props ~300 + agents/resources ~100-200)
- Draw calls: <50 (with InstancedMesh for ground)
- FPS: 60 (test on MacBook Air baseline)

---

## Next Phase After Step 10

Once visuals complete:
- **Phase 3A:** Bundle optimization (lazy-load Three.js, chunk splitting)
- **Phase 3B:** Game balance testing
- **Phase 3C:** Content expansion (more crisis templates, reactions)

---

**Status:** Ready for handoff. Steps 1-5 verified working. Git main branch is clean and deployable. All requirements for AV-CORE articulated above.

**Handoff Ready:** Yes ✅
