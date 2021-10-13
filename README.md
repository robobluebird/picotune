# picotune
Use a text file with a simple DSL to generate a musical (maybe) wav file.

## how to use
- install with 'gem install picotune' or add 'gem picotune' to your 'Gemfile'
- `require picotune` in your code or irb
- `PicoTune.new('path/to/your/input/file.txt').wav`
- see the newly minted `.wav` file in whatever directory you ran the above from!

## the dsl
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
