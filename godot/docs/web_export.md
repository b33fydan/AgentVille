# AgentVille Web Export

AgentVille can ship as a static Godot Web build. The browser version uses the same local-first game code and stores player progress in the browser's IndexedDB-backed `user://` storage. It does not add a game server, runtime API, or model call.

## Build contract

- Engine and export templates: Godot 4.6.3 stable.
- Renderer: desktop remains Forward+; the `web` feature override selects Compatibility/WebGL 2.
- Camera: depth of field remains enabled on supported desktop renderers and is skipped on Compatibility, where Godot does not support it.
- Export mode: single-threaded and without GDExtensions, so the host does not need cross-origin-isolation headers.
- Texture target: desktop browser compression only. Mobile Web texture imports are not part of this checkpoint.
- Public assets: `assets/megavoxpack_local_preview/` is excluded. The browser build intentionally uses the procedural voxel fallbacks.
- Output: `build/web/index.html`, `index.js`, `index.wasm`, and `index.pck`.
- Hosting: `web/vercel.json` is copied into the artifact. Vercel must target the generated artifact directory, never the repository root's legacy Vite app.

## Export locally

Install the matching Godot 4.6.3 export templates, then run from the repository root:

```bash
export GODOT="${GODOT:-/Users/beefymacmini/Downloads/Godot.app/Contents/MacOS/Godot}"
GODOT="$GODOT" ./godot/tools/export_web.sh
```

The script clears only `godot/build/web`, runs the release export, verifies the four required Godot files, copies the artifact-local Vercel config, and fails if Godot reports storing a licensed local asset in the package.

## Validate in a browser

Godot Web exports must be served over HTTP; opening `index.html` directly is not supported.

```bash
python3 -m http.server 8060 --directory godot/build/web
```

Open `http://127.0.0.1:8060/` in a Chromium browser. Confirm that:

1. The farm, both side rails, and Agent Workbench render without a WebGL or JavaScript error.
2. Wheel zoom and View-tool or right/middle-drag pan still reveal farm tiles behind the panels.
3. The CodeEdit accepts text and Compile produces the normal deterministic trace.
4. Reloading the same origin restores browser-local progress.
5. A private/incognito window is treated as disposable storage; persistence is not promised there.

## Vercel boundary

The generated `godot/build/web` directory is a complete static Vercel project. Link or deploy that directory, not `/Volumes/beefybackup/AgentVille`, because the repository root still contains the dead React/Vite prototype:

```bash
vercel --cwd godot/build/web
```

Connecting Git for automatic rebuilds is a separate deployment slice. It requires choosing the exact Vercel project and a build-artifact strategy, because Vercel's standard image does not include Godot or its export templates.
