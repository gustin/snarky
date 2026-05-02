# Snarky Build Plan

Voice-controlled studio assistant for Logic Pro.
Tascam Model 12 + Benson tube amp + Behringer mic + Logic Pro.

## Hardware/Software Context

- Tascam Model 12 in DAW control mode (Mackie Control over USB)
- Logic Pro as DAW
- Mac built-in mic for voice capture (separate from recording mic)
- ffmpeg for audio capture (already installed)
- whisper.cpp for local speech-to-text
- osascript / OSC for Logic control
- claude -p for troubleshooting questions (Max subscription)
- macOS say for spoken feedback

## Iteration 1: Mic Capture and Transcription

Get audio from the Mac mic and turn it into text. This is the
foundation everything else depends on.

Steps:
1. Install whisper.cpp via Homebrew (brew install whisper-cpp)
2. Build a Snarky.Listener GenServer that:
   - Uses ffmpeg to record short audio chunks from the default input device
   - Saves chunks as wav files to a tmp directory
   - Detects silence to know when a phrase is complete
3. Build Snarky.Transcriber module that:
   - Calls whisper.cpp CLI via System.cmd on each audio chunk
   - Returns the transcribed text
4. Wire Listener to Transcriber with a simple pipeline
5. Log transcriptions to stdout for verification

Test: Run the app, speak into the Mac mic, see text in the terminal.

## Iteration 2: Command Parser

Pattern match transcriptions into studio commands. Deterministic,
no LLM needed.

Steps:
1. Build Snarky.CommandRouter module with pattern matching:
   - Transport: record, stop, play, pause, rewind, undo
   - Track targeting: "track 8", "the drums", "all tracks"
   - Mixing: mute, solo, arm, pan, volume up/down
   - Effects: "add reverb to track 3", "remove compressor"
   - Session: save, bounce, export, set tempo
   - Questions: anything with "why", "how", "what" routes to Claude
2. Build Snarky.CommandRouter.Parser for fuzzy matching:
   - Handle Whisper misheard words ("wreck cord" -> "record")
   - Normalize track names and numbers
   - Handle aliases ("the bass" -> track 4, configurable)
3. Define a command struct: %Snarky.Command{action, target, params}
4. Add track alias config (map friendly names to track numbers)

Test: Unit tests with sample transcriptions, verify correct command
structs come out.

## Iteration 3: Logic Pro Control via AppleScript

Execute parsed commands against Logic Pro.

Steps:
1. Build Snarky.Executor.AppleScript module:
   - Transport controls (play, stop, record, rewind)
   - These use System.cmd("osascript", ["-e", script])
   - Logic responds to key code simulation for most transport
2. Map out which Logic operations need AppleScript vs key simulation:
   - Transport: key commands (spacebar = play/stop, R = record)
   - Track arming: needs AppleScript or MIDI
   - Mute/Solo: needs AppleScript or MIDI
3. Test each command individually via iex
4. Add a confirmation callback that calls say after execution

Test: Say "record" into mic, Logic starts recording. Say "stop",
it stops.

## Iteration 4: OSC Control for Mixer Operations

Add OSC for finer-grained control that AppleScript can't do well.

Steps:
1. Add ex_osc dependency to mix.exs
2. Enable OSC in Logic Pro (Preferences > Control Surfaces > OSC)
3. Build Snarky.Executor.OSC module:
   - Connect to Logic's OSC port
   - Fader control (volume per track)
   - Pan control
   - Send levels
   - Plugin parameter control
4. Build Snarky.Executor that delegates to AppleScript or OSC
   depending on the command type
5. Add feedback: read current values back via OSC and speak them
   ("Track 3 volume is at minus 6 dB")

Test: "Set track 3 volume to minus 6" adjusts the fader in Logic.

## Iteration 5: Claude Integration for Troubleshooting

Route engineering questions to claude -p using Max subscription.

Steps:
1. Build Snarky.AskClaude module:
   - Pipes question to System.cmd("claude", ["-p", prompt])
   - Prepends context: "You are a recording engineer. Setup: Tascam
     Model 12, Benson tube amp, Behringer mic, Logic Pro."
   - Parses response and truncates for spoken output
2. Build Snarky.Speaker module:
   - Wraps System.cmd("say", [text])
   - Configurable voice and rate
   - Queues speech so commands don't overlap
3. Wire question route from CommandRouter to AskClaude to Speaker
4. Optionally read current session state (what plugins are on which
   tracks) and include in the Claude context

Test: "Why does the bass sound muddy?" gets a spoken engineering
answer.

## Iteration 6: Session Awareness

Let Snarky know what's happening in the current Logic session so
commands and answers are context-aware.

Steps:
1. Build Snarky.Session GenServer that tracks:
   - Track names and assignments (from config or OSC query)
   - Current armed tracks
   - Current mute/solo state
   - Tempo and time signature
2. Update on every command execution
3. Feed session state into Claude context for better troubleshooting
4. Enable commands like "mute everything except guitar"

Test: "What tracks are armed?" gets an accurate spoken answer.

## Iteration 7: Wake Word and Listening Modes

Control when Snarky listens so it doesn't pick up random
conversation or guitar playing.

Steps:
1. Add listening modes to Snarky.Listener:
   - Always on (default, simple)
   - Wake word: "Hey Snarky" activates listening for one command
   - Push to talk: external trigger (foot pedal MIDI, keyboard shortcut)
2. Add silence detection tuning (don't trigger on amp hum or
   string noise)
3. Add configurable input device selection (specific Mac mic vs
   default)
4. Visual/audio indicator when listening (short beep or terminal
   status)

Test: "Hey Snarky, record track 5" works. Random talking is ignored.

## Iteration 8: Polish and Config

Steps:
1. Add config/config.exs with:
   - Track aliases map
   - Default Claude context (gear list, room description)
   - Whisper model size (tiny/base/small for speed vs accuracy)
   - OSC port and host
   - Voice preferences for say
   - Listening mode preference
2. Add mix task: mix snarky.setup that walks through first-time config
3. Add --verbose flag for debugging transcription issues
4. Error handling: graceful recovery when Logic isn't open, when
   whisper fails, when Claude times out
5. Write a short README with setup instructions

## Dependency Checklist

Install before starting:
- [ ] brew install whisper-cpp
- [ ] brew install sox (backup audio capture option)
- [ ] Enable OSC in Logic Pro preferences
- [ ] Set Tascam Model 12 to DAW control mode
- [ ] Verify claude -p works from terminal

Elixir deps (mix.exs):
- ex_osc (OSC client)

## Open Questions

- Best Whisper model size for real-time on this Mac? Start with
  tiny for speed, upgrade if accuracy is bad.
- Should Snarky run as a Mix task or an escript? Mix task is easier
  for development, escript for distribution.
- MIDI foot pedal for push-to-talk? Would need ex_midi or similar.
  Park this for later.
- Can we read Logic plugin state via OSC? Need to test what Logic
  exposes. If not, maintain state internally.
- STT model choice: Whisper is the starting point but not the only
  option. Evaluate alternatives (Vosk, Deepgram, Canary, faster-whisper,
  MLX Whisper for Apple Silicon) before locking in. Key criteria:
  local-only, low latency, accuracy with studio background noise.
