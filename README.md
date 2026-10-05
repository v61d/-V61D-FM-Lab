# V61D SW / NFC Lab

Experimental iOS lab for testing whether a nearby shortwave receiver can notice RF activity from iPhone NFC reader mode at **13.56 MHz**.

## v0.2

- Real Core NFC Reader Mode experiment.
- One-tap **6 second NFC burst** test.
- SW tuning notebook centered on **13.560 MHz**.
- Original audio beacon retained as a secondary comparison test.
- NFC NDEF reader entitlement and usage description included.

## Goal

The first goal is only to see whether the car receiver produces a repeatable click, buzz or other change when NFC Reader Mode starts and stops.

iOS controls the NFC RF timing, modulation, transmit power and antenna behavior. This app cannot set an arbitrary carrier or directly modulate music onto 13.56 MHz.

## Test

1. Tune the car radio to **SW2 / 13.560 MHz**.
2. Use medium volume.
3. Put the upper part of the iPhone very close to the radio or antenna/coax area.
4. Tap **NFC BURST — 6 SEC**.
5. Repeat three times.
6. If needed, check around **13.555–13.565 MHz**.

A repeatable on/off-correlated effect would be useful evidence of coupling. Hearing nothing is also a valid result.

## Signing note

Core NFC requires the **Near Field Communication Tag Reading** entitlement in the final signed app. GitHub Actions produces an **unsigned IPA**. Your signing/provisioning method must preserve and authorize the NFC entitlement, otherwise Core NFC can report a missing-entitlement error.

## Build artifact

`V61D-SW-NFC-Lab-unsigned`

## License

MIT
