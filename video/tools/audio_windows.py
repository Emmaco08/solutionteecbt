"""Music, sound effects and mix for the "Now on Windows" advert (D-186).

    .venv/bin/python tools/audio_windows.py  ->  public/audio/win_ad.wav

Everything is synthesised (helpers in tools/audio.py, tools/audio_pack.py and tools/audio_features.py); no samples.
The Afro-house bed of the feature ads at 120 BPM: quiet under the hook, full from the laptop reveal (3.7 s), drums stop
at the end card (16.1 s).
"""
import os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import audio as A  # noqa: E402
import audio_pack as P  # noqa: E402
import audio_features as FE  # noqa: E402

DUR = 20.0
FE.END = 16.1
put = P.put


def main():
    P.setup(DUR)
    m = FE.bed_afro(3.75)
    s = P.B()
    # hook: words, three monitors land
    put(s, A.impact(0.6), 0.0, 0.6)
    put(s, A.whoosh(0.4, True, 0.5), 0.25)
    for a in (0.55, 0.62, 0.7):
        put(s, A.slam(130 + a * 60), a + 0.22, 0.45)
    # the small phone
    put(s, A.whoosh(0.5, True, 0.7), 2.05)
    put(s, A.pop(900), 2.3, 0.7)
    put(s, A.downbleep(), 2.9, 0.5)
    # reveal: lid rises, screen powers on
    put(s, A.riser(0.7, 0.6), 3.1)
    put(s, A.whoosh(0.7, True, 0.9), 3.75)
    put(s, A.impact(1.0), 4.55)
    put(s, A.chime(("A5", "E6", "A6"), 0.06, 0.9), 4.6)
    put(s, A.sparkle(1.3, 0.8), 4.85)
    put(s, A.pop(700), 5.35, 0.9)
    # big CBT: keys pressed on the beat
    put(s, A.whoosh(0.5, True, 0.8), 6.75)
    for i in range(4):
        put(s, A.pop(800 + i * 60), 7.6 + i * 0.12, 0.45)
    for i, f in enumerate((1700, 1500, 1600, 1300)):
        put(s, A.tap(f), 8.25 + i * 0.5, 1.0)
        put(s, A.tick(True), 8.25 + i * 0.5, 0.5)
    put(s, A.pop(650), 8.0, 0.6)
    # everything: one flick per screen
    put(s, A.whoosh(0.5, True, 0.8), 10.75)
    for i in range(5):
        put(s, A.whoosh(0.18, i % 2 == 0, 0.35), 11.22 + i * 0.46)
        put(s, A.pop(700 + i * 90), 11.25 + i * 0.46, 0.55)
    # same account: line draws, tick
    put(s, A.whoosh(0.5, True, 0.7), 13.55)
    put(s, A.countup(0.6, 600, 1500), 14.2, 0.45)
    put(s, A.chime(("E6", "B6"), 0.06, 0.9), 14.8)
    put(s, A.pop(800), 15.0, 0.6)
    # end card
    put(s, A.whoosh(0.6, False, 0.6), 16.0)
    put(s, A.chime(("A5", "C#6", "E6", "A6"), 0.09, 1.0), 16.2)
    put(s, A.pop(700), 17.4, 0.8)
    put(s, A.sparkle(1.5, 0.7), 17.5)
    P.master(m * 0.42 + s * 0.6, "win", DUR, "win_ad.wav")


if __name__ == "__main__":
    main()
