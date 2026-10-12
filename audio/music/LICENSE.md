# Music licences

Both loops are dedicated to the public domain under **CC0 1.0 Universal**
(https://creativecommons.org/publicdomain/zero/1.0/). No attribution is required. Both
licences were checked on their OpenGameArt pages on 2026-10-12, where CC0 is the only licence
listed. The files are the downloads, re-encoded as described under "Processing" and imported
with loop on and loop offset 0 (see `presentation/music.gd`).

| File | Track | Author | Source | Licence |
|---|---|---|---|---|
| `shift.ogg` | "Buy Something!" (normal mix, 88.0 s, 44.1 kHz stereo) | Cleyton Kauffman | https://opengameart.org/content/shop-theme, file `shop_theme/Buy Something!.ogg` from https://opengameart.org/sites/default/files/shop_theme.zip | CC0 1.0 |
| `front.ogg` | "Urban Shop" (92 BPM, 83.5 s, 44.1 kHz stereo) | MintoDog | https://opengameart.org/node/179170, file https://opengameart.org/sites/default/files/urban_shop_bpm92_0.ogg | CC0 1.0 |

## Credits

Cleyton Kauffman asks for this credit, and we give it (under CC0 it is a request, not a
condition):

> Music by Cleyton Kauffman - https://soundcloud.com/cleytonkauffman

"Urban Shop" by MintoDog (https://opengameart.org/node/179170), CC0.

## Processing

The user picked both loops by ear on 2026-10-12. Each download was then re-encoded once with
FFmpeg 9.0.2 (libvorbis), as the sound map says: a gentle dip in the 1-3 kHz band, to clear
the note ladder and the scan beep, and OGG Vorbis at quality 5:

    ffmpeg -i <download>.ogg -af "equalizer=f=1800:t=o:w=1.2:g=-2.5" -c:a libvorbis -q:a 5 <file>.ogg

Both keep 44.1 kHz stereo and their exact sample counts (`shift.ogg` 3,880,800 frames,
`front.ogg` 3,681,391), so the loop points don't move. The peak and mean levels moved by at most
0.2 dB. Sizes: `shift.ogg` 3.6 MB to 1.8 MB, `front.ogg` 2.7 MB to 1.6 MB (about 160 kbps). To
swap a track, process the new download the same way and replace only the `.ogg`; its `.import`
(loop on, loop offset 0) stays.

Feedback at the end of phase 3 (the release-candidate playtest, issue #69) may still change small
details of the music, its direction, or the tracks themselves.
