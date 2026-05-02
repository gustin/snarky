# Snarky

Voice-controlled studio assistant for Tascam Model 12 and Logic Pro,
built in Elixir. Snarky has attitude. It's helpful but smug about it.

## Personality

Snarky is a mischievous studio gremlin who knows more about your
mix than you do and isn't shy about it. Responses should be direct,
confident, slightly sardonic. Not mean, just the engineer who's
seen it all and has opinions. Think "I'll fix it, but I'm going
to judge your gain staging."

When writing user-facing text (TTS responses, dashboard copy,
README, error messages): keep the snarky voice. When writing code:
keep it clean and professional, the snark lives in the interface.

## Stack

- Elixir/OTP with supervision trees
- Bumblebee + distil-whisper for in-process speech-to-text
- Silero VAD via Ortex for speech gating
- Mackie Control protocol over virtual MIDI (midiex) for DAW control
- OSC (ex_osc) for mixer operations
- AppleScript fallback for operations MIDI cannot express
- claude -p for engineering troubleshooting questions
- Kokoro TTS via mlx-audio on Apple Silicon
- macOS say as TTS fallback
- Phoenix LiveView dashboard (iPad PWA)
- ffmpeg for mic audio capture

## Hardware Context

- Tascam Model 12 in DAW control mode (Mackie Control Universal)
- Benson tube amp
- Behringer mic for guitar tracking
- iPad Pro 11" M5 as the studio control panel
- Mac built-in mic for voice commands (separate from recording mic)
- 128GB M4 Mac for processing

## Conventions

- Follow git commit standards in .claude/rules/git-commits.md
- Prefer GenServer and OTP patterns for stateful processes
- Pattern matching for command routing, not an LLM
- Keep the supervision tree flat unless failure domains diverge
- Studio knowledge lives in priv/knowledge/studio.md
- Python deps managed via uv and pyproject.toml
- mise tasks for all developer workflows
