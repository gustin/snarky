# Snarky System Architecture

## Overview

Snarky is an Elixir/OTP application that runs on a Mac alongside
Logic Pro. An iPad serves as the studio control panel. The Mac
does all processing. The iPad is the eyes, ears, and mouth.

```mermaid
graph TB
    subgraph iPad["iPad (Studio Control Panel)"]
        Browser["Safari / LiveView"]
        iPadMic["iPad Mic"]
        iPadSpeaker["iPad Speaker"]
    end

    subgraph Mac["Mac (Processing)"]
        subgraph Snarky["Snarky (Elixir/OTP)"]
            Phoenix["Phoenix LiveView"]
            STT["Speech-to-Text<br/>(Bumblebee)"]
            Router["Command Router"]
            MCU["MCU MIDI"]
            Session["Session State"]
            TTS["Text-to-Speech<br/>(Ortex/Piper ONNX)"]
            Claude["Claude CLI"]
            VAD["Silero VAD"]
        end
        Logic["Logic Pro"]
    end

    subgraph Hardware["Hardware"]
        Tascam["Tascam Model 12"]
        Amp["Benson Tube Amp"]
        Mic["Behringer Mic"]
    end

    iPadMic -->|WebSocket audio| Phoenix
    Phoenix -->|PCM chunks| VAD
    VAD -->|speech detected| STT
    STT -->|text| Router
    Router -->|commands| MCU
    Router -->|questions| Claude
    MCU <-->|MIDI / Mackie Control| Logic
    Logic <-->|USB / Mackie Control| Tascam
    Claude -->|answer| TTS
    MCU -->|confirmation| TTS
    TTS -->|audio stream| Phoenix
    Phoenix -->|Web Audio playback| iPadSpeaker
    MCU -->|state updates| Session
    Session -->|live state| Phoenix
    Phoenix -->|dashboard UI| Browser
    Mic --> Tascam
    Amp --> Tascam
    Tascam -->|USB audio| Logic
```

## Data Flow: Voice Command

A musician speaks a command into the iPad while playing.

```mermaid
sequenceDiagram
    participant iPad
    participant Phoenix
    participant VAD
    participant STT
    participant Router
    participant MCU
    participant Logic
    participant Session
    participant TTS

    iPad->>Phoenix: audio chunk (WebSocket)
    Phoenix->>VAD: PCM samples
    VAD-->>Phoenix: speech detected
    Phoenix->>STT: audio tensor
    STT-->>Router: "mute track 3"
    Router->>MCU: %Command{action: :mute, target: {:track, 3}}
    MCU->>Logic: MIDI Note On 0x12 vel 127
    MCU->>Logic: MIDI Note On 0x12 vel 0
    Logic-->>MCU: MIDI Note On 0x12 vel 127 (LED confirm)
    MCU->>Session: track 3 muted
    Session-->>Phoenix: state changed
    Phoenix-->>iPad: LiveView patch (track 3 muted)
    Router->>TTS: "Track 3 muted"
    TTS-->>Phoenix: audio samples
    Phoenix-->>iPad: Web Audio playback
```

## Data Flow: Engineering Question

A musician asks a troubleshooting question.

```mermaid
sequenceDiagram
    participant iPad
    participant Phoenix
    participant STT
    participant Router
    participant Claude
    participant Session
    participant TTS

    iPad->>Phoenix: audio chunk
    Phoenix->>STT: audio tensor
    STT-->>Router: "why does the bass sound muddy"
    Router->>Session: get current state
    Session-->>Router: Track 2 bass at -4dB, compressor loaded
    Router->>Claude: question + session context
    Claude-->>Router: "Check around 200-400 Hz..."
    Router->>TTS: answer text
    TTS-->>Phoenix: audio samples
    Phoenix-->>iPad: Web Audio playback
    Phoenix-->>iPad: LiveView shows Q&A in log
```

## Data Flow: Tascam Physical Control

Someone moves a fader on the Tascam. Snarky sees it.

```mermaid
sequenceDiagram
    participant Tascam
    participant Logic
    participant MCU
    participant Session
    participant Phoenix
    participant iPad

    Tascam->>Logic: Pitch Bend ch 2 (fader 3 moved)
    Logic->>MCU: Pitch Bend ch 2 value 12000
    MCU->>Session: track 3 volume = -1.2 dB
    Session-->>Phoenix: state changed
    Phoenix-->>iPad: LiveView patch (fader 3 moved)
```

## iPad Dashboard Layout

```mermaid
graph TB
    subgraph Dashboard["iPad LiveView Dashboard"]
        subgraph Top["Transport Bar"]
            Play["Play"]
            Stop["Stop"]
            Record["Record"]
            Tempo["120 BPM"]
            Position["Bar 12:3:240"]
        end

        subgraph Tracks["Channel Strip Grid"]
            T1["1 Guitar<br/>Armed<br/>-6 dB<br/>▮▮▮▮░░"]
            T2["2 Bass<br/>-4 dB<br/>▮▮▮░░░"]
            T3["3 Keys<br/>Muted<br/>-8 dB<br/>▮▮░░░░"]
            T4["4 Vocals<br/>-3 dB<br/>▮▮▮░░░"]
            T5["5 Drums<br/>-2 dB<br/>▮▮▮▮░░"]
            T6["6 Kick<br/>-5 dB<br/>▮▮▮░░░"]
            T7["7 Snare<br/>-4 dB<br/>▮▮▮░░░"]
            T8["8 OH<br/>-10 dB<br/>▮▮░░░░"]
        end

        subgraph Bottom["Command Log + Voice"]
            Listening["🎤 Listening..."]
            Log["mute track 3 → Track 3 muted<br/>solo the bass → Track 2 soloed<br/>why muddy? → Check 200-400 Hz"]
        end
    end
```

## Component Architecture

```mermaid
graph LR
    subgraph Supervision["Snarky.Supervisor (one_for_one)"]
        NxServing["Nx.Serving<br/>(STT model)"]
        VAD["Snarky.VAD<br/>(Silero ONNX)"]
        Speaker["Snarky.Speaker<br/>(TTS)"]
        Session["Snarky.Session<br/>(state)"]
        MCUProc["Snarky.MCU<br/>(MIDI)"]
        OSC["Snarky.Executor.OSC<br/>(UDP)"]
        Listener["Snarky.Listener<br/>(mic capture)"]
        Endpoint["SnarkyWeb.Endpoint<br/>(Phoenix)"]
    end

    subgraph Pure["Pure Modules (no state)"]
        Transcriber["Snarky.Transcriber"]
        CommandRouter["Snarky.CommandRouter"]
        Executor["Snarky.Executor"]
        ExMCU["Snarky.Executor.MCU"]
        ExAS["Snarky.Executor.AppleScript"]
        Protocol["Snarky.MCU.Protocol"]
        Parser["Snarky.MCU.Parser"]
        AskClaude["Snarky.AskClaude"]
    end
```

## Network Topology

```mermaid
graph LR
    subgraph Studio["Studio Network"]
        iPad["iPad<br/>192.168.x.x"]
        Mac["Mac<br/>192.168.x.y"]
    end

    iPad -->|"HTTP/WebSocket<br/>port 4000"| Mac
    Mac -->|"USB MIDI<br/>(Mackie Control)"| Tascam["Tascam Model 12"]
    Mac -->|"Virtual MIDI<br/>(Mackie Control)"| Logic["Logic Pro"]
    Mac -->|"UDP :8000<br/>(OSC)"| Logic
```

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Runtime | Elixir/OTP on BEAM |
| Web | Phoenix LiveView |
| STT | Bumblebee + distil-whisper (EXLA) |
| VAD | Silero via Ortex (ONNX) |
| TTS | Piper via Ortex (ONNX) or macOS say |
| DAW control | Mackie Control protocol via midiex |
| Mixer control | OSC via ex_osc |
| Fallback control | AppleScript via osascript |
| AI assistant | Claude CLI (Max subscription) |
| Audio capture | ffmpeg (local mic) or WebSocket (iPad mic) |
| Audio playback | Web Audio API (iPad) or macOS say (local) |
