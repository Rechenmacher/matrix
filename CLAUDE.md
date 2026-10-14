# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A web-based, GPU-accelerated recreation of the "digital rain" effect from The Matrix films. Supports multiple visual variants (classic, nightmare, paradise, resurrections, etc.) and is customizable via 40+ URL query parameters.

## Running the Project

No build system — this is a static web project served directly to the browser:

```bash
python3 -m http.server
```

There are no tests, no lint commands, and no package manager. The only build steps are for the Playdate console port.

### Playdate Builds (optional)

```bash
# C port — simulator
cd playdate/matrix_c/build && rm -R ../ThePlaytrix.pdx ./* && cmake .. && make

# C port — device
cd playdate/matrix_c/build-device
cmake -DCMAKE_TOOLCHAIN_FILE=${PLAYDATE_SDK_PATH}/C_API/buildsupport/arm.cmake -DCMAKE_BUILD_TYPE=Release .. && make

# Lua port
pdc -s Source ThePlaytrixLua.pdx
```

## Architecture

### Dual-Renderer Pattern

The project maintains two parallel rendering implementations under `js/regl/` (WebGL via the REGL library) and `js/webgpu/` (WebGPU). Both share the same pass structure and config system. `js/main.js` detects WebGPU availability and routes to the appropriate implementation.

### Pass-Based Pipeline

Each visual effect is a discrete "pass" that reads from intermediate textures and writes to another. The pipeline runs per frame:

1. **rainPass** — GPU-resident raindrop simulation + MSDF glyph rendering to an FBO
2. **bloomPass** — High-pass filter + blur pyramid for the glow effect
3. **Effect pass** (one of: `palettePass`, `stripePass`, `imagePass`, `mirrorPass`) — color mapping / overlay
4. **quiltPass** (REGL only) — Holographic display output for Looking Glass devices
5. **endPass** (WebGPU only) — Copy intermediate texture to canvas

Each pass is a self-contained module that exposes a consistent interface (setup + draw). See `js/regl/utils.js` and `js/webgpu/utils.js` for the pass framework.

### Configuration System

`js/config.js` is the central source of truth for all rendering parameters. It defines:
- 11+ named version presets (e.g. `classic`, `nightmare`, `paradise`, `resurrections`) each overriding a subset of defaults
- Font definitions (10+ MSDF glyph atlases: katakana, Gothic, Coptic, etc.)
- Effect names and mappings

URL query parameters override config values at runtime. `suppressWarnings` is a special URL param that silences hardware-warning overlays.

### Shaders

- `shaders/glsl/` — GLSL shaders for the REGL pipeline (11 files)
- `shaders/wgsl/` — WGSL shaders for the WebGPU pipeline (11 files)

Both sets follow the same naming convention: `rainPass.frag.glsl` ↔ `rainPass.wgsl`, etc. Shaders are loaded from files at runtime (not bundled).

### MSDF Glyph Rendering

Glyphs are pre-baked into Multi-channel Signed Distance Field texture atlases in `assets/`. New glyphs require running `msdfgen` (git submodule). The raindrop simulation runs entirely on the GPU using double-buffered textures; raindrop positions and glyph selections are never read back to the CPU.

### Key Files

| File | Role |
|---|---|
| `js/main.js` | Entry point: GPU detection, config loading, warning handler |
| `js/config.js` | All defaults, version presets, font definitions |
| `js/regl/rainPass.js` | Core simulation: raindrop physics, glyph cycling, MSDF rendering |
| `js/regl/utils.js` | Pass framework, FBO/texture helpers, shader loading |
| `js/webgpu/utils.js` | WebGPU equivalent of regl/utils.js |
| `lib/gpu-buffer.js` | Custom WGSL type reflection/serialization for uniform buffers |
