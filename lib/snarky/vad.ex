defmodule Snarky.VAD do
  @moduledoc false
  use GenServer
  require Logger

  @sample_rate 16_000

  defstruct [:model, :state, triggered: false]

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def speech?(audio_binary) when is_binary(audio_binary) do
    GenServer.call(__MODULE__, {:detect, audio_binary})
  end

  @impl true
  def init(_opts) do
    model_path = ensure_model()
    model = Ortex.load(model_path)

    state_tensor =
      Nx.broadcast(Nx.tensor(0.0, type: :f32, backend: Nx.BinaryBackend), {2, 1, 128})

    Logger.info("Silero VAD loaded")
    {:ok, %__MODULE__{model: model, state: state_tensor}}
  end

  @impl true
  def handle_call({:detect, audio_binary}, _from, state) do
    samples =
      audio_binary
      |> Nx.from_binary({:f, 32}, backend: Nx.BinaryBackend)
      |> Nx.reshape({1, :auto})

    sr = Nx.tensor(@sample_rate, type: :s64, backend: Nx.BinaryBackend)

    {output, new_state} = Ortex.run(state.model, {samples, state.state, sr})

    new_state = Nx.backend_transfer(new_state, Nx.BinaryBackend)

    probability =
      output
      |> Nx.backend_transfer(Nx.BinaryBackend)
      |> Nx.squeeze()
      |> Nx.to_number()

    triggered = probability > 0.5

    if triggered and not state.triggered do
      Logger.debug("VAD: speech detected (#{Float.round(probability, 3)})")
    end

    {:reply, triggered, %{state | state: new_state, triggered: triggered}}
  rescue
    e ->
      Logger.warning("VAD error: #{Exception.message(e)}")

      fresh_state =
        Nx.broadcast(Nx.tensor(0.0, type: :f32, backend: Nx.BinaryBackend), {2, 1, 128})

      {:reply, true, %{state | state: fresh_state}}
  end

  defp ensure_model do
    model_dir = Path.join(:code.priv_dir(:snarky) |> to_string(), "models")
    model_path = Path.join(model_dir, "silero_vad.onnx")

    unless File.exists?(model_path) do
      File.mkdir_p!(model_dir)
      Logger.info("Downloading Silero VAD model...")

      {_, 0} =
        System.cmd("curl", [
          "-L",
          "https://github.com/snakers4/silero-vad/raw/master/src/silero_vad/data/silero_vad.onnx",
          "-o",
          model_path
        ])

      Logger.info("Silero VAD model downloaded")
    end

    model_path
  end
end
