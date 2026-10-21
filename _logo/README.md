# Logo sources

POV-Ray scenes for the 3D Kardan marks. Underscore-prefixed, so Jekyll does not
copy any of it into the built site.

| File | What |
|---|---|
| `kardan-common.inc` | palette, geometry, materials, light rig -- shared, so the marks cannot drift apart |
| `kardan-logo.pov` | the KARDAN wordmark |
| `kardan-icon.pov` | the K alone on a brand tile, for the favicons |
| `kardan-anim.pov` | the wordmark assembling itself: the letters drop in one by one |
| `anim.ini` | frame count, clock range and render size for the animation |
| `make-icons.py` | rounds the tile corners and cuts the favicon sizes |
| `make-anim.sh` | renders the animation and encodes the clip, poster and fallback |

Rendering, from this directory:

```sh
# wordmark -> assets/images/kardan-wordmark.png (downscaled to 1416px wide)
povray +Ikardan-logo.pov +Okardan-logo.png +W2124 +H700 +A0.25 +AM2 +R3 +Q11

# favicons -> assets/
povray +Ikardan-icon.pov +Okardan-icon.png +W1024 +H1024 +A0.2 +AM2 +R4 +Q11
./make-icons.py kardan-icon.png

# animated wordmark -> assets/images/ (~5 min, 80 frames)
./make-anim.sh
./make-anim.sh --draft     # quarter size, no AA, ~30s, for checking the timing
./make-anim.sh --encode    # re-encode existing frames, ~1s, for tuning the codec
./make-anim.sh --check     # verify the last frame really is the still
```

That writes three files: `kardan-wordmark.webm` (VP9, what nearly everyone
gets), `kardan-wordmark.mp4` (H.264, for browsers too old for VP9) and
`kardan-wordmark-poster.webp`.

The animation plays once and stops, and its last frame is the committed still.
That is what lets `index.md` swap the clip for `kardan-wordmark.png` when a
reader has asked for reduced motion -- they end up looking at the same image
everyone else does. Keep that property if you change the timing: `--check`
tests it, and `Note [The last frame is the still]` in `kardan-anim.pov`
explains it.

Two encoding decisions are already made and worth not re-litigating, both
written up in `make-anim.sh`: `Note [VP9, not animated WebP]` (animated WebP
streaks badly across this backdrop and raising its quality does not fix it) and
`Note [The poster is the FIRST frame]` (posting the finished mark makes the
page show the logo, then rebuild it).

`Declare=Theme=1` renders either scene white-on-charcoal instead of
coral-on-white. The site is light-skinned, so only the light variants are
committed.

The palette comes from the site's own CSS (`#fc4d50`, `#ffffff`, `#f2f2f2`,
`#222222`). Two things in `kardan-common.inc` are worth reading before changing
the lighting: `Note [sRGB hex under assumed_gamma 1.0]` and
`Note [Hitting the brand colour]` -- the coral albedo is hand-calibrated against
this light rig, and moving the lights invalidates it.

The flat artwork these were matched against is still in the repo and still in
use: `assets/images/favicon-source.svg` (geometry), `_includes/svg/logo.svg`
(24px header mark) and `assets/safari-pinned-tab.svg` (monochrome mask).
