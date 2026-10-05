# V61D Mario Native 2.0

Native iOS 15+ NES application using statically linked FCEUmm in C, UIKit controls,
nearest-neighbor Core Animation video, and an AudioQueue PCM ring buffer.
No WebView or JavaScript runtime. The game is bundled by the build and runs offline.
Rendering follows the core's NTSC timing with a 60 Hz display link.
Supports touch and standard extended GameController profiles.
Automatic B run has a two-emulated-frame release on manual B presses to preserve fireballs.
Native saves are independent of earlier browser/JSNES saves and are not converted.
One latest save and six manually selected snapshots are retained in Documents/NativeSaves.
Backgrounding saves then pauses; gameplay resumes through the visible button.

Build on macOS/Xcode: `bash mario-ios/build.sh`.
Output: `mario-ios/build/V61D-Mario-Native-unsigned.ipa`.
Sign before installation on a regular iPhone. No signing secrets are stored here.
The build runs a native core ROM/audio/video/deterministic-save smoke test first.
Physical iPhone performance and UI have not been verified by these tests.

## Source and license
Frontend source is GPL-2.0-or-later. FCEUmm is GPL-2.0-or-later; see included COPYING.
Pinned core: https://github.com/libretro/libretro-fceumm/tree/7a542dab1e87679921962a9f056186eca425c0c2
The accompanying source ZIP contains the exact core and frontend/build scripts used.
The game ROM remains separate from GPL emulator code and is not committed to GitHub.
