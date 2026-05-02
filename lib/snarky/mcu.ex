defmodule Snarky.MCU do
  use GenServer
  require Logger

  @device_name "Snarky"

  defstruct [:output, :input, connected: false]

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def send_note(note, velocity \\ 127) do
    GenServer.cast(__MODULE__, {:note, note, velocity})
  end

  def send_note_off(note) do
    send_note(note, 0)
  end

  def send_cc(cc, value) do
    GenServer.cast(__MODULE__, {:cc, cc, value})
  end

  def send_pitch_bend(channel, value) do
    GenServer.cast(__MODULE__, {:pitch_bend, channel, value})
  end

  def connected? do
    GenServer.call(__MODULE__, :connected?)
  end

  @impl true
  def init(_opts) do
    send(self(), :connect)
    {:ok, %__MODULE__{}}
  end

  @impl true
  def handle_info(:connect, state) do
    case setup_midi() do
      {:ok, output, input} ->
        Logger.info("MCU MIDI connected as '#{@device_name}'")
        {:noreply, %{state | output: output, input: input, connected: true}}

      {:error, reason} ->
        Logger.warning("MCU MIDI setup failed: #{inspect(reason)}, retrying in 5s")
        Process.send_after(self(), :connect, 5_000)
        {:noreply, state}
    end
  end

  def handle_info({:midi_message, message}, state) do
    Snarky.MCU.Parser.handle(message)
    {:noreply, state}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  @impl true
  def handle_cast({:note, note, _velocity}, %{connected: false} = state) do
    Logger.warning("MCU not connected, dropping note #{note}")
    {:noreply, state}
  end

  def handle_cast({:note, note, velocity}, state) do
    msg = Midiex.Message.note_on(0, note, velocity)
    Midiex.send_msg(state.output, msg)
    {:noreply, state}
  end

  def handle_cast({:cc, cc, _value}, %{connected: false} = state) do
    Logger.warning("MCU not connected, dropping CC #{cc}")
    {:noreply, state}
  end

  def handle_cast({:cc, cc, value}, state) do
    msg = Midiex.Message.control_change(0, cc, value)
    Midiex.send_msg(state.output, msg)
    {:noreply, state}
  end

  def handle_cast({:pitch_bend, channel, _value}, %{connected: false} = state) do
    Logger.warning("MCU not connected, dropping pitch bend ch #{channel}")
    {:noreply, state}
  end

  def handle_cast({:pitch_bend, channel, value}, state) do
    msg = Midiex.Message.pitch_bend(channel, value)
    Midiex.send_msg(state.output, msg)
    {:noreply, state}
  end

  @impl true
  def handle_call(:connected?, _from, state) do
    {:reply, state.connected, state}
  end

  defp setup_midi do
    output = Midiex.create_virtual_output(@device_name)
    input = Midiex.create_virtual_input(@device_name)

    pid = self()

    Task.start(fn ->
      Midiex.subscribe(input)

      receive_loop = fn loop ->
        receive do
          message -> send(pid, {:midi_message, message})
        end

        loop.(loop)
      end

      receive_loop.(receive_loop)
    end)

    {:ok, output, input}
  rescue
    e ->
      {:error, Exception.message(e)}
  end
end
