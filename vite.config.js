import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  build: {
    // The three-chunk will be >500 KB, but that's intentional for code-splitting
    chunkSizeWarningLimit: 800,
    rollupOptions: {
      output: {
        // Manual chunks: Extract Three.js to a separate file for parallel loading
        // THREE.JS: Lazy-loaded on component mount via dynamic import() in IslandScene.jsx
        //   - File: dist/assets/three-chunk-*.js (~722 KB uncompressed, ~184 KB gzip)
        //   - Only loaded when user starts the game (Suspense fallback shown while loading)
        //   - Enables browsers to load Three.js independently from main app bundle
        //   - Reduces critical path and initial page load time
        // REACT-DOM: Separated for better caching
        //   - File: dist/assets/react-chunk-*.js (~130 KB uncompressed, ~41 KB gzip)
        // VENDOR: Other node_modules (Zustand, Tone.js, etc.)
        //   - File: dist/assets/vendor-*.js (~14 KB uncompressed, ~5 KB gzip)
        // MAIN APP: Game UI and state management
        //   - File: dist/assets/index-*.js (~110 KB uncompressed, ~30 KB gzip)
        // ISLAND SCENE: Lazily loaded component with Three.js utilities
        //   - File: dist/assets/IslandScene-*.js (~23 KB uncompressed, ~8 KB gzip)
        manualChunks: (id) => {
          if (id.includes('node_modules/three')) {
            return 'three-chunk';
          }
          if (id.includes('node_modules/react-dom')) {
            return 'react-chunk';
          }
          if (id.includes('node_modules')) {
            return 'vendor';
          }
        },
      },
    },
  },
});
