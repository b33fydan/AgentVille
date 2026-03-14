import { Suspense, lazy, useState, useEffect } from 'react';
const IslandScene = lazy(() => import('./components/scene/IslandScene.jsx'));
import { stateVerification } from './utils/stateVerification';
import AgentPanel from './components/ui/AgentPanel.jsx';
import SeasonHUD from './components/ui/SeasonHUD.jsx';
import CrisisModal from './components/ui/CrisisModal.jsx';
import SaleDay from './components/ui/SaleDay.jsx';
import OnboardingFlow from './components/ui/OnboardingFlow.jsx';
import LandingPage from './components/ui/LandingPage.jsx';
import RiotModal from './components/ui/RiotModal.jsx';
import ConsequencesHandler from './components/ConsequencesHandler.jsx';

const GAME_STARTED_KEY = 'agentville-game-started';

export default function App() {
  const [gameStarted, setGameStarted] = useState(() => {
    return localStorage.getItem(GAME_STARTED_KEY) === 'true';
  });

  // Expose state verification to console for debugging
  useEffect(() => {
    if (typeof window !== 'undefined') {
      window.stateVerification = stateVerification;
      console.log('%c💡 State verification tools loaded!', 'color: #22c55e; font-weight: bold;');
      console.log('%cRun: window.verifyState()', 'color: #3b82f6;');
    }
  }, []);

  const handleStartGame = () => {
    localStorage.setItem(GAME_STARTED_KEY, 'true');
    setGameStarted(true);
  };
  if (!gameStarted) {
    return <LandingPage onStart={handleStartGame} />;
  }

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

      {/* Sale Day Modal */}
      <SaleDay />

      {/* Onboarding Flow */}
      <OnboardingFlow />

      {/* Riot Modal (Viral Feature) */}
      <RiotModal />

      {/* Consequences Handler (Desertions, Strikes, Demands) */}
      <ConsequencesHandler />
    </main>
  );
}
