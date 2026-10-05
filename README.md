# V61D SW / NFC Lab

Experimental iOS lab for testing whether a nearby shortwave receiver can notice iPhone NFC reader activity at **13.56 MHz**.

## v0.3 — Pulse Channel

The app now includes an automatic **NFC ON/OFF pulse train**. This is intended to test whether the click/buzz already heard on the SW receiver can be controlled by software timing.

Presets:
- **2s ON / 2s OFF** × 6
- **1s ON / 1s OFF** × 8
- **0.5s ON / 0.5s OFF** × 10

The app starts an NFC reader session for each ON interval, invalidates it for OFF, then starts the next session.

## Test

1. Tune the receiver to **SW2 / 13.560 MHz**.
2. Put the upper part of the iPhone very close to the same location that produced the continuous clicking.
3. Start with **2s / 2s**.
4. Listen for approximately two seconds of NFC-related clicking followed by approximately two seconds of silence.
5. If that tracks reliably, try the faster presets.

A repeatable timing-correlated result is evidence of a software-controlled RF activity channel.

## Important limitation

This does **not** directly modulate arbitrary audio onto 13.56 MHz. iOS controls the NFC RF waveform, power, polling behavior and timing internally. The app only starts and stops public Core NFC reader sessions, so actual timing can include system startup/invalidation delay.

## Signing

The final signed app must retain Apple's **Near Field Communication Tag Reading** entitlement.

## Build artifact

`V61D-SW-NFC-Pulse-Lab-unsigned`

## License

MIT
