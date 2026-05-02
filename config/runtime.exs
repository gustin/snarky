import Config

if config_env() == :prod do
  config :snarky,
    whisper_model:
      System.get_env("SNARKY_WHISPER_MODEL") ||
        Path.join(:code.priv_dir(:snarky) |> to_string(), "models/ggml-base.en.bin")
end
