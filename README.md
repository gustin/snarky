# Snarky

Voice-controlled studio assistant for Logic Pro.

Speak commands while playing guitar. Snarky listens on your Mac mic,
transcribes locally with Whisper, and controls Logic Pro via Mackie
Control protocol and OSC.

## Hardware

- Tascam Model 12 (DAW control mode)
- Benson tube amp
- Behringer mic
- Logic Pro

## Architecture

```
Mac mic → Whisper (local STT) → Command Router → Logic Pro
                                     ↓
                                 claude -p (troubleshooting questions)
                                     ↓
                                 macOS say (spoken feedback)
```

Commands like "record track 8" or "mute the bass" are parsed
deterministically. Engineering questions like "why is the bass muddy?"
route to Claude via your Max subscription.

## Requirements

- Elixir 1.19+
- whisper.cpp (`brew install whisper-cpp`)
- ffmpeg (`brew install ffmpeg`)
- Logic Pro with OSC enabled

## Setup

```sh
mix deps.get
mix snarky.setup
```

## Usage

```sh
mix snarky
```

Then pick up your guitar and talk.
