defmodule Mix.Tasks.Snarky.Setup do
  @moduledoc "First-time setup for Snarky"
  use Mix.Task

  @shortdoc "Run Snarky first-time setup"

  @impl true
  def run(_args) do
    IO.puts("""

    Snarky Setup
    ============

    Checking dependencies...
    """)

    check_whisper()
    check_ffmpeg()
    check_claude()
    check_model()
    check_say()

    IO.puts("""

    Setup complete. Run `mix snarky` to start.

    Tips:
    - In Logic Pro, enable OSC: Preferences > Control Surfaces
    - Set your Tascam Model 12 to DAW control mode
    - Edit config/config.exs to customize track aliases
    """)
  end

  defp check_whisper do
    whisper_bin =
      Application.get_env(:snarky, :whisper_bin, "/opt/homebrew/opt/whisper-cpp/bin/whisper-cli")

    if File.exists?(whisper_bin) do
      IO.puts("  ✓ whisper-cpp found at #{whisper_bin}")
    else
      IO.puts("  ✗ whisper-cpp not found. Install: brew install whisper-cpp")
    end
  end

  defp check_ffmpeg do
    case System.cmd("which", ["ffmpeg"], stderr_to_stdout: true) do
      {path, 0} -> IO.puts("  ✓ ffmpeg found at #{String.trim(path)}")
      _ -> IO.puts("  ✗ ffmpeg not found. Install: brew install ffmpeg")
    end
  end

  defp check_claude do
    case System.cmd("which", ["claude"], stderr_to_stdout: true) do
      {path, 0} -> IO.puts("  ✓ claude CLI found at #{String.trim(path)}")
      _ -> IO.puts("  ✗ claude CLI not found (needed for troubleshooting questions)")
    end
  end

  defp check_model do
    model = Application.get_env(:snarky, :whisper_model, "")

    if model != "" and File.exists?(model) do
      size = File.stat!(model).size |> div(1_000_000)
      IO.puts("  �� Whisper model found (#{size} MB): #{Path.basename(model)}")
    else
      IO.puts("  ✗ Whisper model not found at #{model}")

      IO.puts(
        "    Download: curl -L https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin -o priv/models/ggml-base.en.bin"
      )
    end
  end

  defp check_say do
    if File.exists?("/usr/bin/say") do
      IO.puts("  ✓ macOS say command available")
    else
      IO.puts("  ✗ macOS say command not found (are you on macOS?)")
    end
  end
end
