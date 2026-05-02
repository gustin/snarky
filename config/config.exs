import Config

config :snarky,
  whisper_model:
    System.get_env("SNARKY_WHISPER_MODEL") ||
      Path.join(File.cwd!(), "priv/models/ggml-base.en.bin"),
  whisper_bin:
    System.get_env("SNARKY_WHISPER_BIN") || "/opt/homebrew/opt/whisper-cpp/bin/whisper-cli",
  ffmpeg_bin: System.get_env("SNARKY_FFMPEG_BIN") || "ffmpeg",
  claude_bin: System.get_env("SNARKY_CLAUDE_BIN") || "claude",
  osc_host: {127, 0, 0, 1},
  osc_port: 8000,
  listen_mode: :always,
  wake_word: "hey snarky",
  voice: "Samantha",
  speech_rate: 200,
  audio_device: :default,
  silence_threshold_db: -30,
  silence_duration_ms: 1500,
  max_phrase_ms: 15_000,
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
