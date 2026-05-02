defmodule Snarky.Listener do
  use GenServer
  require Logger

  @capture_seconds 5

  defstruct [
    :audio_dir,
    :audio_device,
    :listen_mode,
    :wake_word,
    recording: false,
    awake: false,
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

    audio_device = resolve_audio_device()
    Logger.info("Using audio device: #{audio_device}")

    state = %__MODULE__{
      audio_dir: audio_dir,
      audio_device: audio_device,
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
    {:noreply, %{state | recording: false}}
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
    Logger.debug("Capturing audio chunk #{state.chunk_counter}...")

    case capture_audio(chunk_path, state.audio_device) do
      :ok ->
        Logger.debug("Audio captured, checking for speech...")

        if has_speech?(chunk_path) do
          Logger.debug("Speech detected, transcribing...")
          handle_speech(chunk_path, state)
        else
          Logger.debug("No speech, skipping")
          File.rm(chunk_path)
          schedule_next_capture()
          {:noreply, %{state | chunk_counter: state.chunk_counter + 1}}
        end

      {:error, reason} ->
        Logger.warning("Audio capture failed: #{reason}")
        schedule_next_capture()
        {:noreply, %{state | chunk_counter: state.chunk_counter + 1}}
    end
  end

  def handle_info(_msg, state), do: {:noreply, state}

  defp capture_audio(path, device) do
    ffmpeg_bin = Application.get_env(:snarky, :ffmpeg_bin, "ffmpeg")

    args = [
      "-y",
      "-f",
      "avfoundation",
      "-i",
      device,
      "-t",
      to_string(@capture_seconds),
      "-ar",
      "16000",
      "-ac",
      "1",
      "-acodec",
      "pcm_s16le",
      "-v",
      "quiet",
      path
    ]

    case System.cmd(ffmpeg_bin, args, stderr_to_stdout: true) do
      {_output, 0} -> :ok
      {output, code} -> {:error, "ffmpeg exited #{code}: #{output}"}
    end
  end

  defp has_speech?(wav_path) do
    case File.read(wav_path) do
      {:ok, data} when byte_size(data) > 44 ->
        <<_header::binary-size(44), pcm::binary>> = data

        f32_audio =
          pcm
          |> Nx.from_binary(:s16)
          |> Nx.as_type(:f32)
          |> Nx.divide(32768.0)
          |> Nx.to_binary()

        check_chunks_for_speech(f32_audio)

      _ ->
        false
    end
  rescue
    _ -> true
  end

  defp check_chunks_for_speech(f32_audio) do
    chunk_bytes = 1536 * 4
    total = byte_size(f32_audio)

    Enum.reduce_while(0..div(total, chunk_bytes), false, fn i, _acc ->
      offset = i * chunk_bytes

      if offset + chunk_bytes <= total do
        chunk = binary_part(f32_audio, offset, chunk_bytes)

        if Snarky.VAD.speech?(chunk) do
          {:halt, true}
        else
          {:cont, false}
        end
      else
        {:cont, false}
      end
    end)
  end

  defp handle_speech(path, state) do
    case Snarky.Transcriber.transcribe(path) do
      {:ok, ""} ->
        :ok

      {:ok, text} ->
        Logger.info("Heard: #{text}")
        Phoenix.PubSub.broadcast(Snarky.PubSub, "listener", {:heard, text})
        process_transcription(text, state)

      {:error, reason} ->
        Logger.warning("Transcription failed: #{reason}")
    end

    schedule_next_capture()
    {:noreply, %{state | chunk_counter: state.chunk_counter + 1}}
  end

  defp process_transcription(text, %{listen_mode: :always}) do
    Snarky.CommandRouter.route(text)
  end

  defp process_transcription(
         text,
         %{listen_mode: :wake_word, wake_word: wake, awake: false}
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

  defp resolve_audio_device do
    preferred = Application.get_env(:snarky, :audio_device, "MacBook Pro Microphone")

    if String.starts_with?(preferred, ":") do
      preferred
    else
      find_device_index(preferred)
    end
  end

  defp find_device_index(name) do
    {output, _} =
      System.cmd("ffmpeg", ["-f", "avfoundation", "-list_devices", "true", "-i", ""],
        stderr_to_stdout: true
      )

    output
    |> String.split("\n")
    |> Enum.reduce_while(nil, fn line, _acc ->
      if String.contains?(line, name) do
        case Regex.run(~r/\[(\d+)\]/, line) do
          [_, index] -> {:halt, ":#{index}"}
          _ -> {:cont, nil}
        end
      else
        {:cont, nil}
      end
    end)
    |> case do
      nil ->
        Logger.warning("Audio device '#{name}' not found, falling back to :0")
        ":0"

      device ->
        Logger.info("Found audio device '#{name}' at #{device}")
        device
    end
  end
end
