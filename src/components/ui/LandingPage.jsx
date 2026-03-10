import { useState } from 'react';

export default function LandingPage({ onStart }) {
  const [showFeatures, setShowFeatures] = useState(false);

  return (
    <div className="min-h-screen bg-gradient-to-b from-slate-900 via-slate-800 to-slate-900 text-white">
      {/* Header */}
      <header className="border-b border-slate-700 bg-slate-900/50 backdrop-blur py-4">
        <div className="max-w-6xl mx-auto px-4 flex items-center justify-between">
          <div className="text-2xl font-bold">🏝️ AgentVille</div>
          <button
            onClick={onStart}
            className="px-6 py-2 rounded-lg bg-blue-600 hover:bg-blue-500 font-semibold transition-all"
          >
            Play Now
          </button>
        </div>
      </header>

      {/* Hero */}
      <section className="max-w-6xl mx-auto px-4 py-20">
        <div className="text-center">
          <h1 className="text-5xl font-bold mb-4">
            You Inherited an Island Farm
          </h1>
          <p className="text-2xl text-slate-300 mb-8">
            Now your agents are judging every decision you make.
          </p>
          <div className="flex gap-4 justify-center">
            <button
              onClick={onStart}
              className="px-8 py-4 rounded-lg bg-green-600 hover:bg-green-500 font-bold text-lg transition-all active:scale-95"
            >
              ▶️ Start Game
            </button>
            <button
              onClick={() => setShowFeatures(!showFeatures)}
              className="px-8 py-4 rounded-lg border border-slate-500 hover:border-slate-400 font-bold text-lg transition-all"
            >
              📖 Learn More
            </button>
          </div>
        </div>
      </section>

      {/* Features */}
      {showFeatures && (
        <section className="max-w-6xl mx-auto px-4 py-12">
          <h2 className="text-3xl font-bold mb-8 text-center">Game Features</h2>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div className="rounded-lg border border-slate-700 bg-slate-800/50 p-6">
              <h3 className="text-xl font-bold mb-2">🎯 Zone Management</h3>
              <p className="text-slate-300">
                Assign your 3 agents to forest, plains, or wetlands. Specialists get +10% efficiency bonus.
              </p>
            </div>
            <div className="rounded-lg border border-slate-700 bg-slate-800/50 p-6">
              <h3 className="text-xl font-bold mb-2">⚠️ Crisis Events</h3>
              <p className="text-slate-300">
                Handle 2 crises per day. Every choice affects morale and resources.
              </p>
            </div>
            <div className="rounded-lg border border-slate-700 bg-slate-800/50 p-6">
              <h3 className="text-xl font-bold mb-2">📊 Profit Cycles</h3>
              <p className="text-slate-300">
                7-day seasons end with Sale Day. Harvest sold, profit calculated, agents reviewed.
              </p>
            </div>
            <div className="rounded-lg border border-slate-700 bg-slate-800/50 p-6">
              <h3 className="text-xl font-bold mb-2">😠 Morale System</h3>
              <p className="text-slate-300">
                Keep agents happy. Low morale leads to inefficiency and potential riots.
              </p>
            </div>
            <div className="rounded-lg border border-slate-700 bg-slate-800/50 p-6">
              <h3 className="text-xl font-bold mb-2">🎵 Audio Feedback</h3>
              <p className="text-slate-300">
                Procedural sound effects react to your decisions in real-time.
              </p>
            </div>
            <div className="rounded-lg border border-slate-700 bg-slate-800/50 p-6">
              <h3 className="text-xl font-bold mb-2">📜 Event Log</h3>
              <p className="text-slate-300">
                Track all crises and decisions. Review the consequences of your management.
              </p>
            </div>
          </div>
        </section>
      )}

      {/* Footer */}
      <footer className="border-t border-slate-700 bg-slate-900/50 mt-20 py-8">
        <div className="max-w-6xl mx-auto px-4 text-center text-slate-400 text-sm">
          <p>🏝️ AgentVille is a fork of Payday Kingdom, built on React + Three.js + Zustand</p>
          <p className="mt-2">Made by Dan (Skyframe Innovations) + Bernie</p>
        </div>
      </footer>
    </div>
  );
}
