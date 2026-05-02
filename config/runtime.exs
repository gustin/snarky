import Config

if model = System.get_env("SNARKY_STT_MODEL") do
  config :snarky, stt_model: model
end
