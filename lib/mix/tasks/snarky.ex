defmodule Mix.Tasks.Snarky do
  @moduledoc "Start Snarky voice-controlled studio assistant"
  use Mix.Task

  @shortdoc "Start Snarky"

  @impl true
  def run(args) do
    Mix.Task.run("app.start")

    verbose = "--verbose" in args

    if verbose do
      Logger.configure(level: :debug)
    end

    IO.puts("""

    ╔══════════════════════════════════════╗
    ║         🎸  Snarky  🎸              ║
    ║   Voice-controlled studio assistant  ║
    ╚═════════��════════════════════════════╝

    Listening mode: #{Application.get_env(:snarky, :listen_mode, :always)}
    Whisper model:  #{Path.basename(Application.get_env(:snarky, :whisper_model, "unknown"))}

    Commands:  record, stop, play, mute, solo, arm...
    Questions: "Why does the bass sound muddy?"

    Press Ctrl+C to quit.
    """)

    Snarky.start()

    receive do
      :never -> :ok
    end
  end
end
