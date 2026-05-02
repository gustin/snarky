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

    check_ffmpeg()
    check_claude()
    check_say()
    check_stt_model()

    IO.puts("""

    Setup complete. Run `mix snarky` to start.

    The STT model downloads from HuggingFace on first run.
    Silero VAD model downloads automatically on first run.

    Tips:
    - In Logic Pro, enable OSC: Preferences > Control Surfaces
    - Set your Tascam Model 12 to DAW control mode
    - Edit config/config.exs to customize track aliases
    """)
  end

  defp check_ffmpeg do
    case System.cmd("which", ["ffmpeg"], stderr_to_stdout: true) do
      {path, 0} -> IO.puts("  ok  ffmpeg found at #{String.trim(path)}")
      _ -> IO.puts("  --  ffmpeg not found. Install: brew install ffmpeg")
    end
  end

  defp check_claude do
    case System.cmd("which", ["claude"], stderr_to_stdout: true) do
      {path, 0} -> IO.puts("  ok  claude CLI found at #{String.trim(path)}")
      _ -> IO.puts("  --  claude CLI not found (needed for troubleshooting questions)")
    end
  end

  defp check_say do
    if File.exists?("/usr/bin/say") do
      IO.puts("  ok  macOS say command available")
    else
      IO.puts("  --  macOS say command not found (are you on macOS?)")
    end
  end

  defp check_stt_model do
    model = Application.get_env(:snarky, :stt_model, "distil-whisper/distil-large-v3")
    IO.puts("  ok  STT model configured: #{model}")
    IO.puts("      (downloads from HuggingFace on first run, cached locally)")
  end
end
