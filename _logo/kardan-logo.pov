// ---------------------------------------------------------------------------
// Kardan wordmark -- "KARDAN" as beveled 3D letters standing on a studio
// floor, in the spirit of the Pixar wordmark.
//
// Render:
//   povray +Ikardan-logo.pov +Okardan-logo.png +W2124 +H700 +A0.25 +AM2 +R3 +Q11
//
//   povray +Ikardan-logo.pov +Okardan-dark.png Declare=Theme=1 \
//          +W2124 +H700 +A0.25 +AM2 +R3 +Q11
//
// See Note [Framing by height] for the camera angle.
//
// Options (add on the command line):
//   Declare=Theme=1   white letters on a dark ground
// ---------------------------------------------------------------------------

#include "kardan-common.inc"

// ---------------------------------------------------------------------------
// The word
// ---------------------------------------------------------------------------
#declare Word =
union {
  #declare Cur = -TotW / 2;
  #declare i = 0;
  #while (i < NC)
    object {
      Beveled(Chars[i])
      translate x * (Cur + Wid[i] / 2)
      texture { T_Letter }
    }
    #declare Cur = Cur + Wid[i] + Trk;
    #declare i = i + 1;
  #end
  interior { ior 1.5 }
  scale Scl
}

StudioFloor(1)
StudioSky()
StudioLights(1)

camera {
  perspective
  // Dead centre in x: the word stays symmetric, and the 10 degrees of
  // elevation is what reveals the tops of the letters. Standing well back with
  // a narrow field keeps the outer letters from splaying the way a wide angle
  // makes them.
  location < 0.0, 6.00, -29.5>
  look_at  < 0.0, 1.15,   0.0>
  right    x * image_width / image_height
  angle    FrameAngle(19)
}

object { Word }
