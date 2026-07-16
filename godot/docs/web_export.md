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
- Direct hosting: `web/vercel.json` is copied into the local artifact for CLI previews.
- Git hosting: `deploy/vercel/` is the reviewed, tracked production snapshot. The repository-root `vercel.json` explicitly skips npm/Vite and serves that directory.

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

## Publish the reviewed Git artifact

The existing Vercel project is connected to this repository. Refresh its tracked static snapshot only after the local browser checks pass:

```bash
GODOT="$GODOT" ./godot/tools/publish_web.sh
```

The script rebuilds first, copies only runtime files into `godot/deploy/vercel`, excludes the nested artifact-local config, and writes `artifact-sha256.txt`. Commit the reviewed snapshot together with source changes. The repository-root `vercel.json` skips dependency installation and the retired Vite build, then serves this exact directory.

The legacy React/Vite code remains in history and on its archive branch for rollback, but it is not a production build input.

## Direct Vercel preview

The generated `godot/build/web` directory remains a complete standalone static Vercel project for CLI previews:

```bash
vercel --cwd godot/build/web
```

The checked-in snapshot is an intentional bridge for Git deployments because Vercel's standard image does not include Godot or its export templates. A later CI slice can replace tracked binaries with an authenticated prebuilt deployment while preserving the same browser acceptance gate.
