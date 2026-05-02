# Studio Reference

## Signal Chain

Instrument → Behringer mic (condenser, cardioid) → Tascam Model 12
channel input → USB audio interface → Logic Pro on Mac

Guitar: instrument → Benson tube amp → Behringer mic on cab →
Tascam channel input

## Gear Characteristics

### Tascam Model 12
- 10 input channels (8 mono + 1 stereo)
- Channels 1-2: XLR/TRS combo with 48V phantom power
- Channels 3-8: XLR/TRS combo
- Channels 9/10: stereo line input
- Channels 11/12: Bluetooth / USB return
- Built-in compressor on channels 1-8 (one-knob)
- Built-in EQ: 3-band (high shelf 10kHz, mid peak 2.5kHz, low shelf 100Hz)
- USB audio: 12 in / 10 out at 48kHz or 44.1kHz
- Onboard effects: reverb and delay sends
- Headphone mix is independent of main mix
- DAW control mode: Mackie Control Universal

### Benson Tube Amp
- Produces warm harmonic saturation, especially in the mids
- Sweet spot is typically at moderate gain where tubes compress naturally
- Can get harsh above 3kHz when driven hard
- Low end thickens as volume increases
- Mic placement on the speaker cone matters significantly:
  - Center of cone: brighter, more attack, more presence
  - Edge of cone: warmer, rounder, less fizz
  - Off-axis: reduces high frequency harshness
  - Distance: more room, less direct, thinner low end

### Behringer Mic
- Condenser microphone, cardioid pattern
- Proximity effect: bass boost when close to source
- Can be harsh in the 5-8kHz presence peak region
- Needs phantom power (48V from Tascam channels 1-2)

## Common Problems and Fixes

### Bass sounds muddy
- Check 200-400 Hz range for buildup
- Cut narrow at the offending frequency rather than broad boost elsewhere
- Check proximity effect: move mic back from source
- High-pass filter below 80 Hz to remove sub rumble

### Guitar sounds thin
- Mic too far from the speaker cab
- High-pass filter set too high, cutting body
- Move mic closer to cone center for more low-mid content
- Check Tascam EQ: low shelf might be cut

### Guitar sounds harsh
- 2.5-5 kHz presence peak from mic and amp interaction
- Move mic toward edge of speaker cone
- Cut narrow around 3-4 kHz
- Reduce amp gain slightly, tube amps get harsher when pushed

### Mix sounds boxy
- 300-500 Hz buildup, common in small rooms
- Cut 3-5 dB narrow around 350 Hz on offending tracks
- Room reflections adding to the boxiness
- Try a different mic position relative to room corners

### Vocals sound nasal
- 800 Hz - 1.2 kHz range
- Cut narrow in that region
- Check mic angle: singing directly on-axis emphasizes this range

### Too much room sound
- Mic too far from source
- Reflective surfaces near the mic
- Consider a reflection filter behind the mic
- Gate or expand to reduce room sound between phrases

## EQ Starting Points

### Electric Guitar (clean)
- HPF: 80 Hz
- Cut: -3 dB at 300 Hz (reduce mud)
- Boost: +2 dB at 3 kHz (presence)
- Shelf: -2 dB above 10 kHz (reduce hiss)

### Electric Guitar (driven)
- HPF: 100 Hz
- Cut: -4 dB at 400 Hz (reduce boxiness)
- Cut: -3 dB at 3.5 kHz (reduce harshness)
- Shelf: -3 dB above 8 kHz (reduce fizz)

### Bass Guitar (DI)
- HPF: 40 Hz
- Boost: +3 dB at 80 Hz (weight)
- Cut: -3 dB at 250 Hz (reduce mud)
- Boost: +2 dB at 1.5 kHz (definition)

### Acoustic Guitar
- HPF: 80 Hz
- Cut: -3 dB at 200 Hz (reduce boom)
- Boost: +2 dB at 5 kHz (sparkle)
- Shelf: +1 dB above 10 kHz (air)

### Vocals
- HPF: 100 Hz
- Cut: -3 dB at 300 Hz (reduce mud)
- Boost: +3 dB at 3-5 kHz (presence)
- Boost: +2 dB at 10 kHz (air)
- De-ess around 6-8 kHz if sibilant

### Drums (overhead)
- HPF: 200 Hz (let kick and snare come from close mics)
- Cut: -3 dB at 400 Hz (reduce boxiness)
- Boost: +2 dB at 8 kHz (cymbal shimmer)

## Compression Starting Points

### Vocals
- Ratio: 3:1 to 4:1
- Attack: 10-20 ms (let transients through)
- Release: auto or 100-200 ms
- Threshold: aim for 3-6 dB gain reduction

### Electric Guitar
- Ratio: 2:1 to 4:1
- Attack: 5-15 ms
- Release: 50-100 ms
- Light compression, the amp is already compressing

### Bass
- Ratio: 4:1 to 6:1
- Attack: 10-30 ms
- Release: auto or 100 ms
- Aim for consistent level, 4-8 dB reduction

### Drums (bus)
- Ratio: 2:1 to 4:1
- Attack: 20-40 ms (preserve transients)
- Release: auto
- Glue compression, 2-4 dB reduction

## Gain Staging

- Tascam input gain: aim for peaks at -12 to -6 dBFS
- Leave headroom: do not clip the Tascam preamps
- Logic channel faders: start at unity (0 dB)
- Mix into the master at -6 dB average, peaks no higher than -3 dB
- The Tascam one-knob compressor is post-preamp, pre-USB

## Room Notes

(Fill in your room characteristics here)
- Room dimensions:
- Floor material:
- Wall treatment:
- Known resonant frequencies:
- Best mic position in the room:
- Worst mic position in the room:
