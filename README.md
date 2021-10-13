# picotune
Use a text file with a simple DSL to generate a musical (maybe) wav file.

## how to use
- install with `gem install picotune` or add `gem picotune` to your `Gemfile`
- `require 'picotune'` in your code or irb
- `p = PicoTune.new('path/to/your/input/file.txt')`
- `p.wav`
- see the newly minted `.wav` file in whatever directory you ran the above from!

## the dsl
- Take a look at the example file below, then come back here and read this explainer:
- `tune helloworld` names your tune to "helloworld"
- `sequence ph1 ...` defines what sequence your phrases will play in. Notice the names `ph1` and `ph2` are defined lower down with the `phrase ph1` and `phrase ph2` blocks.
- `instrument i1` names an instrument "i1".
  - valid `tone` values are `sine`, `square`, `triangle`, `saw`, or `noise`
  - valid `length` and `volume` values are `none`, `quarter`, `half`, `threequarters`, or `full`
  - valid `pan` values are `left`, `centerleft`, `center`, `centerright`, or `right`
  - valid `reverb` values are `none`, `some`, `more`, or `lots`
- `phrase ph1` names a phrase called "ph1"
  - `tempo` is beats per minute
  - `beats` is the number of beats per measure. This is usually 4 in modern pop/rock music but any number besides 0 will do.
  - `subbeats` is the number of subdivisions of each beat. 4 will divide your beats in 16th notes. So in this case "ph1" will have 16 steps in the phrase (4 beats each with 4 subbeats)
  - `melodies` keyword goes on a line by itself, followed by lines of melody definitions. A melody is an instrument and a pattern, both must be named (see pattern description)
- `pattern p1 C4.C4.E4-E4-G4.G4.C4-C4.` defines a pattern named "p1". The string after that is the notes and rests of the pattern. IMPORTANT: A pattern MUST have the correct number of "steps" to match with a phrase. If you have a phrase like above with 4 beats and 4 subbeats per beat then your pattern MUST have 16 steps!
  - a step of the pattern can either be a note like `A4`, a rest `.`, or a continuation `-`
  - note names include a note and an octave. valid note names are `A`, `A#` or `Bb`, `B`, `B#` or `Cb`, `D`, `D#` or `Eb`, `E`, `F`, `F#` or `Gb`, `G`, `G#` or `Ab`. valid octaves are a number between 1 and 8 inclusive.
  - a rest means nothing plays
  - a continuance plays the note that immediately proceeds it again. `A4---` encodes four `A4` notes. this is just for convenience.

There is not much error checking so if something breaks check your format, make you are spelling instrument/phrase/pattern names correctly wherever you use them.

You can have as many tempo and time signature shifts as you want in a tune, so go nuts with that.

That's about it! Good luck!

```
tune helloworld

sequence ph1 ph2 ph1 ph2

instrument i1
tone sine
length full
volume full
pan center
reverb none

instrument i2
tone square
length half
volume half
pan centerright
reverb some

phrase ph1
tempo 120
beats 4
subbeats 4
melodies
i1 p1
i1 p2
i1 p3

phrase ph2
tempo 160
beats 3
subbeats 4
melodies
i1 p4
i2 p5

pattern p1 C4.C4.E4-E4-G4.G4.C4-C4.
pattern p2 E4.E4.G4-G4-B4.B4.G4-G4.
pattern p3 A4...C5.B4.A4---C5.C5.
pattern p4 C4.C4.E4-E4-G4.G4.
pattern p5 A4...C5.B4.A4---
```
