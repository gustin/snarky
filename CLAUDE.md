# Snarky

Voice-controlled studio assistant for Logic Pro, built in Elixir.

## Stack

- Elixir/OTP with supervision trees
- whisper.cpp for local speech-to-text
- OSC (ex_osc) and AppleScript for Logic Pro control
- Mackie Control protocol over MIDI for transport/mixer
- claude -p for engineering troubleshooting questions
- macOS say for spoken feedback
- ffmpeg for mic audio capture

## Hardware Context

- Tascam Model 12 in DAW control mode (Mackie Control Universal)
- Benson tube amp
- Behringer mic for guitar tracking
- Mac built-in mic for voice commands (separate from recording mic)

## Conventions

- Follow git commit standards in .claude/rules/git-commits.md
- Prefer GenServer and OTP patterns for stateful processes
- Shell out via System.cmd for external tools (whisper, ffmpeg, osascript, say, claude)
- Pattern matching for command routing, not an LLM
- Keep the supervision tree flat unless failure domains diverge
