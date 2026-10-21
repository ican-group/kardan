// ---------------------------------------------------------------------------
// Kardan icon -- the K of the wordmark, alone on a flat brand tile, lit by the
// same rig. Square frames only. Feed the render to make-icons.py, which rounds
// the corners and cuts the favicon sizes.
//
// Render:
//   povray +Ikardan-icon.pov +Okardan-icon.png +W1024 +H1024 +A0.2 +AM2 +R4 +Q11
//
// Options (add on the command line):
//   Declare=Theme=1   coral K on a charcoal tile
// ---------------------------------------------------------------------------

#include "kardan-common.inc"

// Note [Flat albedo for the icon]
// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// The wordmark's ceramic darkens towards the base of each letter, which at 16
// pixels turns the foot of the K into a grey smudge and costs the mark its
// silhouette. The icon uses one flat albedo instead and lets the lighting do
// all of the shading.
#declare T_Icon = Ceramic(C_Mark, C_Mark, 0.42)

#declare Icon =
object {
  Beveled("K")
  texture { T_Icon }
  interior { ior 1.5 }
  scale Scl
}

#declare IconH = CapH * Scl;

// ---------------------------------------------------------------------------
// Note [Flat tile, lit subject]
// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// The tile has to be the exact brand hex -- an icon is read as a colour swatch
// before it is read as a shape -- so the backdrop is a self-emitting plane
// rather than a lit surface: emission carries the pigment straight to the film
// with no shading and no need for the compensation in Note [Hitting the brand
// colour]. It is no_shadow so the lights behind it still reach the subject, and
// the studio floor stays no_image so it bounces light up into the base without
// appearing in frame or planting a shadow on the tile.
// ---------------------------------------------------------------------------
plane {
  z, 9
  pigment { #if (Theme = 0) C_Coral #else C_Ink #end }
  finish { emission 1 diffuse 0 }
  no_shadow
  no_reflection
}

// Note [The dark tile runs a little dark]
// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// On the charcoal tile the coral K renders #e5494a against the brand
// #fc4d50: right hue, ~9% short on red. The albedo is already at full red (see
// Note [Hitting the brand colour]) and the emissive tile gives back no bounce,
// so the only lever left is a hotter key -- which clips red instead of raising
// it and washes the hue out to #ff6d6d. Left as is; the light tile, where the
// coral is a flat fill, is exact.
StudioFloor(0)
StudioSky()
StudioLights(0.35)

camera {
  perspective
  // Only 5 degrees of elevation: any more and the top faces of the K turn into
  // a tabletop and the mark stops reading as a flat letter.
  location <0, IconH * 0.5 + 1.05, -11.70>
  // Aimed a hair below the middle of the mark: looking slightly down makes it
  // sit high in the frame otherwise, and an icon has to be optically centred.
  look_at  <0, IconH * 0.5 - 0.04,   0.00>
  // Note [Framing a square by hand]
  // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  // "angle" is measured against the right vector, so its effect shifts with
  // the aspect ratio (the wordmark had to be tuned by eye). Giving right, up
  // and direction explicitly makes the field exact instead: the half-angle is
  // atan(0.5 / |direction|), so 4.96 covers 2.36 units at this distance, which
  // leaves the 1.65-unit K filling 70% of the tile: big enough to hold up at 16
  // pixels, with enough margin around the letter for it to read as a K.
  right     x
  up        y
  direction z * 4.96
}

object { Icon }
