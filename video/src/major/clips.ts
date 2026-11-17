// Google Flow media for the two major adverts (D-183). Footage: Omni 1.2 Flash clips (9:16, first frame = the approved
// still); `from` is the second of the clip the ad starts on. Characters: 3D students cut out of a green screen
// (tools/cutout.py). Files live in public/major/.
export const CLIPS = {
  lamp: { src: "major/a_lamp.mp4", from: 0.6 }, // the lamp dies at 2.4 s in the clip, 1.8 s into the ad
  win: { src: "major/a_win.jpg", from: 1.2 },
  bus: { src: "major/b_bus.jpg", from: 0 },
  duel: { src: "major/b_duel.jpg", from: 1.0 },
  tundeBooks: "major/tunde_books.png",
  tundeConfused: "major/tunde_confused.png",
  tundeWin: "major/tunde_win.png",
  adaThink: "major/ada_think.png",
  adaJump: "major/ada_jump.png",
  adaWalk: "major/ada_walk.png",
};
