defmodule Snarky.Speaker do
  use GenServer
  require Logger

  defstruct [:tts_engine, :voice, :rate, queue: :queue.new(), speaking: false]

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def say(text) do
    GenServer.cast(__MODULE__, {:say, text})
  end

  def stop_speaking do
    GenServer.cast(__MODULE__, :stop)
  end

  @impl true
  def init(_opts) do
    engine = Application.get_env(:snarky, :tts_engine, :kokoro)
    voice = Application.get_env(:snarky, :voice, "af_heart")
    rate = Application.get_env(:snarky, :speech_rate, 200)

    Logger.info("TTS engine: #{engine}")
    {:ok, %__MODULE__{tts_engine: engine, voice: voice, rate: rate}}
  end

  @impl true
  def handle_cast({:say, text}, state) do
    new_queue = :queue.in(text, state.queue)
    new_state = %{state | queue: new_queue}

    if state.speaking do
      {:noreply, new_state}
    else
      speak_next(%{new_state | speaking: true})
    end
  end

  def handle_cast(:stop, state) do
    System.cmd("killall", ["say"], stderr_to_stdout: true)
    {:noreply, %{state | queue: :queue.new(), speaking: false}}
  end

  @impl true
  def handle_info(:speak_next, state) do
    speak_next(state)
  end

  def handle_info(_msg, state), do: {:noreply, state}

  defp speak_next(state) do
    case :queue.out(state.queue) do
      {{:value, text}, remaining} ->
        Task.start(fn ->
          do_speak(text, state)
          send(__MODULE__, :speak_next)
        end)

        {:noreply, %{state | queue: remaining}}

      {:empty, _} ->
        {:noreply, %{state | speaking: false}}
    end
  end

  defp do_speak(text, %{tts_engine: :kokoro} = state) do
    Logger.debug("Speaking (Kokoro): #{text}")

    case speak_kokoro(text, state.voice) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.warning("Kokoro failed: #{reason}, falling back to say")
        speak_say(text, state.voice, state.rate)
    end
  end

  defp do_speak(text, state) do
    Logger.debug("Speaking (say): #{text}")
    speak_say(text, state.voice, state.rate)
  end

  defp speak_kokoro(text, voice) do
    args =
      [
        "run",
        "python",
        "-m",
        "mlx_audio.tts.generate",
        "--model",
        "prince-canuma/Kokoro-82M",
        "--text",
        text,
        "--play"
      ] ++ if(voice, do: ["--voice", voice], else: [])

    case System.cmd("uv", args, stderr_to_stdout: true, cd: project_root()) do
      {_output, 0} -> :ok
      {output, code} -> {:error, "uv exited #{code}: #{String.slice(output, 0, 200)}"}
    end
  end

  defp speak_say(text, voice, rate) do
    say_voice = if voice in macos_voices(), do: voice, else: "Samantha"
    System.cmd("say", ["-v", say_voice, "-r", to_string(rate), text], stderr_to_stdout: true)
  end

  defp macos_voices do
    ~w(Samantha Alex Victoria Daniel Karen Moira Tessa)
  end

  defp project_root do
    Application.app_dir(:snarky) |> Path.join("../../../") |> Path.expand()
  end
end
