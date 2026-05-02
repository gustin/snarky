defmodule Snarky.Speaker do
  use GenServer
  require Logger

  defstruct [:voice, :rate, queue: :queue.new(), speaking: false]

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
    voice = Application.get_env(:snarky, :voice, "Samantha")
    rate = Application.get_env(:snarky, :speech_rate, 200)
    {:ok, %__MODULE__{voice: voice, rate: rate}}
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
          do_speak(text, state.voice, state.rate)
          send(__MODULE__, :speak_next)
        end)

        {:noreply, %{state | queue: remaining}}

      {:empty, _} ->
        {:noreply, %{state | speaking: false}}
    end
  end

  defp do_speak(text, voice, rate) do
    Logger.debug("Speaking: #{text}")
    System.cmd("say", ["-v", voice, "-r", to_string(rate), text], stderr_to_stdout: true)
  end
end
