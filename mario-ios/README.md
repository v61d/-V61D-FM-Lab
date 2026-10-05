# V61D Mario Native 3.0

Offline iOS 15+ application, arm64, bundle com.v61d.mario. Native C FCEUmm
(pinned 7a542dab1e87679921962a9f056186eca425c0c2), UIKit, Core Animation,
AudioQueue; no WebKit or JavaScript runtime. Original site ROM verified by SHA-256.

## Features

- Arabic V61D home, resume/new game, input selector, portrait and landscape layouts.
- Four arrow controls, adjustable size, A/B swap, controller and keyboard remapping,
  configurable stick dead zone, independent input ownership across sources.
- Autorun with manual B fire: releases for exactly two emulated frames before
  reassertion; disabled autorun behaves as a normal B button.
- Persisted volume/mute, sharp/linear pixels, scanlines, rotation and fullscreen.
- All compiled FCEUmm core option definitions are exposed using libretro v2,
  including NTSC filtering, region, palette, overscan, sound/APU and overclock.
- Stable 60 Hz / highest screen refresh / battery 30 Hz presentation. Original
  emulation speed remains unchanged in battery mode.
- Real runtime rendered and emulated FPS counters and core frame duration.
  These counters are distinct from the core's target frame rate.
- Fast forward 1.5–10x, slow motion, bounded rewind history (~15 seconds at
  60 fps). Accelerated and reverse playback mute audio to prevent buffering lag.
- Latest save, nine numbered slots and six manual historical snapshots;
  timestamps, thumbnails, automatic interval save and background save/pause.
- State checksums, .vsave export/import, ROM-format and size validation,
  corrupt import rejection and deletion of individual saves.
- Game Genie and raw NES cheats: add, enable/disable, delete and persist.
- PNG/JPEG capture of raw emulator image (1–4x) or visible game UI; iOS sharing.
- ReplayKit screen/audio recording, native preview and export interface.

## Platform equivalents and limitations

The site's WebGL/browser/mouse menu options are web runtime specifics. Native
presentation is synchronized by CADisplayLink and replaces WebGL. NTSC and
scanlines provide native image filtering. iOS ReplayKit controls video format,
bitrate and recording frame rate; the app does not offer ineffective WebM,
WebP or bitrate selectors. Browser JSNES saves cannot be loaded by FCEUmm.
V2 native raw .state saves remain readable in the app. .vsave is the supported
portable format for this native app. No automatic browser-save migration.
The ROM is fixed to the original game; peripheral options are inherited from
FCEUmm, and Zapper/Arkanoid inputs are irrelevant to this Mario ROM.
Game Genie BIOS option requires an external BIOS; direct cheat codes do not.
Region/RAM/BIOS options take effect when starting a new game. Existing saves
preserve game state, so keep compatible region settings when restoring them.

## Verification

`bash mario-ios/build.sh` builds the unsigned device IPA after portable input
regression and native ROM/video/audio/deterministic-state tests.
`bash mario-ios/verify-simulator.sh` builds the same frontend/core for the iOS
Simulator, runs save-slot/retention/export/import/corrupt-save/restore and UI
smoke checks and captures game/settings/core screenshots. UI launch test modes
run only with explicit --ui-smoke arguments and are inactive in normal use.

Physical-device touch/gamepad/keyboard latency, ReplayKit consent/recording and
battery/thermal behavior still need testing on a real iPhone. Simulator timing
is not an iPhone performance benchmark. Sign the unsigned IPA for installation.
No signing credentials are committed.

## Source and license

Frontend and FCEUmm: GPL-2.0-or-later. The IPA includes COPYING and its matching
source ZIP includes the exact patched core, frontend and build scripts. The core
Makefile patch includes libretro-common in the static archive for this standalone
frontend. ROM remains separate and is not committed to this source repository.
