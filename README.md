# V61D SW / NFC Lab

## v0.4 — RF Tone experiment

The car SW receiver already produces a repeatable NFC-related click pattern at **13.560 MHz**. v0.4 tests whether those RF transients can be pushed into an audible pitch.

Instead of opening and closing whole NFC sessions, the app keeps one Core NFC reader session active and repeatedly calls `restartPolling()` at a selected rate:

- 25 Hz
- 50 Hz
- 100 Hz
- 200 Hz

If each polling restart produces a detectable transient in the receiver, a sufficiently fast train may be heard as a buzz/tone rather than isolated clicks.

### Test

1. Tune SW2 to **13.560 MHz**.
2. Place the upper iPhone area at the same point that produced the previous continuous clicking.
3. Start at **50 Hz**.
4. Then try **100 Hz** and **200 Hz**.
5. Listen specifically for pitch change.

If the pitch follows the selected rate, the next experiment can sequence rates into a melody and then investigate low-rate audio encoding.

### Important limitation

Core NFC exposes reader sessions and polling controls, not raw 13.56 MHz carrier amplitude/phase modulation. This test therefore cannot guarantee arbitrary audio transmission.

### Artifact

`V61D-SW-NFC-Tone-Lab-unsigned`

## License

MIT
