// Google Flow media for the two major adverts (D-183). Footage: Omni 1.2 Flash clips (9:16, first frame = the approved
// still); `from` is the second of the clip the ad starts on. Characters: 3D students cut out of a green screen
// (tools/cutout.py). Files live in public/major/.
export const CLIPS = {
  lamp: { src: "major/a_lamp.mp4", from: 1.3 }, // the lamp dies at 2.4 s in the clip, 1.1 s into the ad (click in the audio)
  win: { src: "major/a_win.mp4", from: 3.2 }, // grin, then the fist pump about 2 s into the shot
  bus: { src: "major/b_bus.mp4", from: 2.6 }, // smile and nod, then a glance out at the street
  duel: { src: "major/b_duel.mp4", from: 2.8 }, // Chidi wins and laughs, then they laugh together
  tundeBooks: "major/tunde_books.png",
  tundeConfused: "major/tunde_confused.png",
  tundeWin: "major/tunde_win.png",
  adaThink: "major/ada_think.png",
  adaJump: "major/ada_jump.png",
  adaWalk: "major/ada_walk.png",
};
