import { Suspense } from 'react';
import IslandScene from './components/scene/IslandScene.jsx';
import AgentPanel from './components/ui/AgentPanel.jsx';
import SeasonHUD from './components/ui/SeasonHUD.jsx';
import CrisisModal from './components/ui/CrisisModal.jsx';

export default function App() {
  return (
    <main className="flex min-h-screen w-full min-w-0 flex-col overflow-x-hidden bg-slate-900 text-white md:flex-row">
      {/* Island Scene (Main) */}
      <section className="relative w-full min-w-0 md:order-2 md:h-screen md:w-[65vw]">
        <Suspense fallback={<div className="p-4 text-white">Loading island...</div>}>
          <IslandScene />
        </Suspense>
        
        {/* Season HUD Overlay (Resources, Day Counter) */}
        <SeasonHUD />
      </section>

      {/* Agent Panel Sidebar (Desktop Only) */}
      <section className="hidden md:order-1 md:block md:h-screen md:w-[35vw] md:min-w-[300px] overflow-y-auto border-r border-slate-700 bg-slate-900/80 p-4 backdrop-blur">
        <AgentPanel />
      </section>

      {/* Mobile Agent Panel (Below Scene) */}
      <section className="md:hidden w-full border-t border-slate-700 bg-slate-900/95 p-4">
        <AgentPanel />
      </section>

      {/* Crisis Modal */}
      <CrisisModal />
    </main>
  );
}
