# V61D FM Lab

Experimental iOS lab for testing whether any unintended electromagnetic side-channel from an iPhone can be noticed on a nearby FM receiver.

## What the app does

- Generates a very distinctive repeating audio beacon (`V61D Locator`).
- Includes a 1000/500 Hz dual-tone test and a 200 Hz–8 kHz chirp.
- Provides a receiver-frequency notebook slider for scanning 87.5–108.0 MHz. **It does not tune an iPhone FM transmitter.**
- Includes an optional 120 Hz display activity test.
- Built with SwiftUI + AVAudioEngine; no private APIs.

## Important limitation

iPhone does not expose an official FM-transmitter API. This app does **not** turn the phone into a guaranteed FM transmitter. It is an experiment to see whether any unintended emissions are detectable at very short range. A normal result is that the radio receives nothing.

Use only for short-range testing with your own receiver and avoid causing interference to other radio users.

## Build an unsigned IPA with GitHub Actions

The repository includes `.github/workflows/build-ipa.yml`.

1. Open **Actions** → **Build unsigned IPA**.
2. Run the workflow (or push to `main`).
3. When it finishes, open the run and download the `V61D-FM-Lab-unsigned` artifact.
4. Extract the artifact ZIP to get `V61D-FM-Lab-unsigned.ipa`.
5. Sign/install the IPA with your own Apple signing method.

The workflow uses a GitHub-hosted macOS runner, installs XcodeGen, builds with signing disabled, and packages the `.app` as an IPA.

## Suggested test

1. Start **V61D Locator**.
2. If using a USB-C cable as a passive test lead, connect only the cable and keep it near the car radio/antenna wiring; there is no guarantee this changes emissions.
3. Slowly scan an unused FM frequency and listen for the unique `beep-beep-beep / lower long beep` pattern.
4. If you hear something, stop the beacon to verify that it disappears, then start it again to confirm correlation.

## License

MIT
