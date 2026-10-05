# V61D Mario for iPhone and iPad

Native fullscreen WKWebView client for https://mario.v61d.chatgpt.site/.
Requires iOS 15+ and internet. Website changes apply automatically.
Touch controls, run/fire behavior and save/restore remain provided by the site.
Persistent app-local web storage is separate from Safari's saves.
Leaving the foreground attempts to save and pauses gameplay; resume using the game's button.
External HTTPS links open outside the app. No certificates, credentials, or game ROMs are bundled.

Build on macOS with Xcode installed: `bash mario-ios/build.sh`.
Output: `mario-ios/build/V61D-Mario-unsigned.ipa`.
This artifact is unsigned and must be signed before installation on a regular iPhone.
