import Config

config :snarky,
  stt_model: "distil-whisper/distil-large-v3",
  ffmpeg_bin: System.get_env("SNARKY_FFMPEG_BIN") || "ffmpeg",
  audio_device: "MacBook Pro Microphone",
  claude_bin: System.get_env("SNARKY_CLAUDE_BIN") || "claude",
  osc_host: {127, 0, 0, 1},
  osc_port: 8000,
  listen_mode: :always,
  wake_word: "hey snarky",
  tts_engine: :kokoro,
  voice: "af_heart",
  speech_rate: 200,
  track_aliases: %{
    "guitar" => 1,
    "bass" => 2,
    "keys" => 3,
    "vocals" => 4,
    "drums" => 5,
    "kick" => 6,
    "snare" => 7,
    "overhead" => 8
  }

config :nx, :default_backend, EXLA.Backend
