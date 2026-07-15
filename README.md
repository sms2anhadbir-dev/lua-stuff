# LuaInject

A dylib that embeds a Lua 5.4 interpreter and runs scripts inside whatever
iOS process loads it. Built with Theos, entirely on GitHub Codespaces (Linux).

## What it is
An in-app Lua code injector. Once the dylib is loaded, a draggable **W**
button floats over the host app. Tap it to open an editor where you can:
- paste or type Lua code into the textbox,
- **Run** it immediately against a live Lua state,
- **Save & Run** to persist it under a name,
- reload any saved script (tap it in the list) and run it again,
- swipe to delete saved scripts.

Files:
- `src/LuaInject.m` — `__attribute__((constructor))` that waits for the app's
  UI scene and presents the overlay.
- `src/LuaOverlay.m` — the floating W button, editor panel, and saved-script
  list, hosted in a passthrough `UIWindow` so the app underneath stays usable.
- `src/LuaEngine.m` — a persistent Lua state + the `inject.*` native API.
- `vendor/lua/` — the vanilla Lua interpreter source (fetched at build time).
- Output: `libLuaInject.dylib` in `.theos/obj/`.

Saved scripts live in `/var/mobile/Library/LuaInject/scripts/`, falling back
to the app's Documents dir if that path isn't writable.

## Build in Codespaces
1. Open this repo in a Codespace. The `.devcontainer` installs Theos + a
   Linux iOS toolchain + SDK automatically.
2. Once the container is ready:
   ```bash
   make
   ```
   The dylib lands in `.theos/obj/libLuaInject.dylib`.

## Loading it into a process
This is the part that depends on *your* environment and authorization:
- **Jailbroken device (your own):** drop the dylib in `/usr/lib` and load it
  via a tweak `MobileSubstrate` filter, or `DYLD_INSERT_LIBRARIES`.
- **Your own app / re-signed app you own:** add it to the app bundle's
  `Frameworks/` and codesign, or inject with a loader like `optool`.

## Note on authorization
Only inject into processes you own or are authorized to modify (your own
apps, your own jailbroken device, CTF/research targets you have permission
for). Don't use this against apps or devices you don't control.

## Extending the native API
Add C functions to `kInjectLib` in `src/LuaEngine.m`. Anything you expose
there becomes callable from Lua as `inject.<name>(...)`.

## Repo manifest
A sample repo manifest is available in [repo.json](repo.json). It follows the requested top-level structure with `META`, `Games`, `Tweaked`, `Jailbreaks`, `Emulators`, and `Other` sections.

## GitHub Pages publishing
The workflow in [.github/workflows/deploy-release.yml](.github/workflows/deploy-release.yml) publishes the patched IPA and manifest as GitHub Pages assets. Replace the placeholder owner/repo URL in [repo.json](repo.json) with your actual GitHub username and repository name before running the workflow.
