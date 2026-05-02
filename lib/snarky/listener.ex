defmodule Snarky.Listener do
  use GenServer
  require Logger

  @max_phrase_ms 15_000

  defstruct [
    :ffmpeg_pid,
    :audio_dir,
    :current_file,
    :recording,
    :listen_mode,
    :wake_word,
    :awake,
    silence_counter: 0,
    chunk_counter: 0
  ]

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def start_listening, do: GenServer.cast(__MODULE__, :start)
  def stop_listening, do: GenServer.cast(__MODULE__, :stop)
  def listening?, do: GenServer.call(__MODULE__, :listening?)

  @impl true
  def init(opts) do
    audio_dir = Path.join(System.tmp_dir!(), "snarky_audio")
    File.mkdir_p!(audio_dir)

    listen_mode = opts[:listen_mode] || Application.get_env(:snarky, :listen_mode, :always)
    wake_word = opts[:wake_word] || Application.get_env(:snarky, :wake_word, "hey snarky")

    state = %__MODULE__{
      audio_dir: audio_dir,
      recording: false,
      listen_mode: listen_mode,
      wake_word: wake_word,
      awake: listen_mode == :always
    }

    {:ok, state}
  end

  @impl true
  def handle_cast(:start, state) do
    Logger.info("Snarky listener starting")
    send(self(), :capture_loop)
    {:noreply, %{state | recording: true}}
  end

  def handle_cast(:stop, state) do
    Logger.info("Snarky listener stopping")
    stop_ffmpeg(state)
    {:noreply, %{state | recording: false, ffmpeg_pid: nil}}
  end

  @impl true
  def handle_call(:listening?, _from, state) do
    {:reply, state.recording, state}
  end

  @impl true
  def handle_info(:capture_loop, %{recording: false} = state) do
    {:noreply, state}
  end

  def handle_info(:capture_loop, state) do
    chunk_path = Path.join(state.audio_dir, "chunk_#{state.chunk_counter}.wav")
    max_seconds = @max_phrase_ms / 1000

    ffmpeg_bin = Application.get_env(:snarky, :ffmpeg_bin, "ffmpeg")

    args = [
      "-y",
      "-f",
      "avfoundation",
      "-i",
      ":default",
      "-t",
      to_string(max_seconds),
      "-ar",
      "16000",
      "-ac",
      "1",
      "-acodec",
      "pcm_s16le",
      chunk_path
    ]

    task =
      Task.async(fn ->
        case System.cmd(ffmpeg_bin, args, stderr_to_stdout: true) do
          {_output, 0} -> {:ok, chunk_path}
          {output, code} -> {:error, "ffmpeg exited #{code}: #{output}"}
        end
      end)

    case Task.await(task, round(max_seconds * 1000) + 5_000) do
      {:ok, path} ->
        handle_audio_chunk(path, state)

      {:error, reason} ->
        Logger.warning("Audio capture failed: #{reason}")
        schedule_next_capture()
        {:noreply, %{state | chunk_counter: state.chunk_counter + 1}}
    end
  end

  def handle_info(_msg, state), do: {:noreply, state}

  defp handle_audio_chunk(path, state) do
    case Snarky.Transcriber.transcribe(path) do
      {:ok, ""} ->
        schedule_next_capture()
        {:noreply, %{state | chunk_counter: state.chunk_counter + 1}}

      {:ok, text} ->
        Logger.info("Heard: #{text}")
        process_transcription(text, state)
        schedule_next_capture()
        {:noreply, %{state | chunk_counter: state.chunk_counter + 1}}

      {:error, reason} ->
        Logger.warning("Transcription failed: #{reason}")
        schedule_next_capture()
        {:noreply, %{state | chunk_counter: state.chunk_counter + 1}}
    end
  end

  defp process_transcription(text, %{listen_mode: :always} = _state) do
    Snarky.CommandRouter.route(text)
  end

  defp process_transcription(
         text,
         %{listen_mode: :wake_word, wake_word: wake, awake: false} = _state
       ) do
    if String.contains?(String.downcase(text), String.downcase(wake)) do
      command =
        text
        |> String.downcase()
        |> String.replace(String.downcase(wake), "")
        |> String.trim()

      if command != "" do
        Snarky.CommandRouter.route(command)
      else
        Snarky.Speaker.say("Yeah?")
      end
    end
  end

  defp process_transcription(text, _state) do
    Snarky.CommandRouter.route(text)
  end

  defp schedule_next_capture do
    Process.send_after(self(), :capture_loop, 100)
  end

  defp stop_ffmpeg(%{ffmpeg_pid: nil}), do: :ok

  defp stop_ffmpeg(%{ffmpeg_pid: pid}) do
    try do
      Port.close(pid)
    rescue
      _ -> :ok
    end
  end
end
