defmodule Snarky.Session do
  use GenServer
  require Logger

  defstruct tracks: %{},
            tempo: 120,
            time_signature: "4/4",
            loop: nil,
            last_commands: []

  defmodule Track do
    defstruct [
      :number,
      :name,
      armed: false,
      muted: false,
      soloed: false,
      volume_db: 0,
      pan: :center,
      effects: []
    ]
  end

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def track_command(cmd) do
    GenServer.cast(__MODULE__, {:track_command, cmd})
  end

  def get_state do
    GenServer.call(__MODULE__, :get_state)
  end

  def describe do
    GenServer.call(__MODULE__, :describe)
  end

  def get_track(n) do
    GenServer.call(__MODULE__, {:get_track, n})
  end

  @impl true
  def init(_opts) do
    aliases = Application.get_env(:snarky, :track_aliases, %{})

    tracks =
      for {name, num} <- aliases, into: %{} do
        {num, %Track{number: num, name: name}}
      end

    default_tracks =
      for n <- 1..8, not Map.has_key?(tracks, n), into: %{} do
        {n, %Track{number: n, name: "Track #{n}"}}
      end

    {:ok, %__MODULE__{tracks: Map.merge(default_tracks, tracks)}}
  end

  @impl true
  def handle_cast({:track_command, cmd}, state) do
    new_state = apply_command(cmd, state)
    Phoenix.PubSub.broadcast(Snarky.PubSub, "session", {:session_updated, new_state})
    {:noreply, new_state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  def handle_call(:describe, _from, state) do
    {:reply, describe_session(state), state}
  end

  def handle_call({:get_track, n}, _from, state) do
    {:reply, Map.get(state.tracks, n), state}
  end

  defp apply_command(%{action: :arm, target: {:track, n}}, state) do
    update_track(state, n, fn t -> %{t | armed: true} end)
  end

  defp apply_command(%{action: :disarm, target: {:track, n}}, state) do
    update_track(state, n, fn t -> %{t | armed: false} end)
  end

  defp apply_command(%{action: :mute, target: {:track, n}}, state) do
    update_track(state, n, fn t -> %{t | muted: true} end)
  end

  defp apply_command(%{action: :mute, target: :all}, state) do
    tracks = Map.new(state.tracks, fn {k, t} -> {k, %{t | muted: true}} end)
    %{state | tracks: tracks}
  end

  defp apply_command(%{action: :unmute, target: {:track, n}}, state) do
    update_track(state, n, fn t -> %{t | muted: false} end)
  end

  defp apply_command(%{action: :unmute, target: :all}, state) do
    tracks = Map.new(state.tracks, fn {k, t} -> {k, %{t | muted: false}} end)
    %{state | tracks: tracks}
  end

  defp apply_command(%{action: :solo, target: {:track, n}}, state) do
    update_track(state, n, fn t -> %{t | soloed: true} end)
  end

  defp apply_command(%{action: :unsolo, target: {:track, n}}, state) do
    update_track(state, n, fn t -> %{t | soloed: false} end)
  end

  defp apply_command(%{action: :set_volume, target: {:track, n}, params: %{db: db}}, state) do
    update_track(state, n, fn t -> %{t | volume_db: db} end)
  end

  defp apply_command(%{action: :pan, target: {:track, n}, params: %{direction: dir}}, state) do
    update_track(state, n, fn t -> %{t | pan: dir} end)
  end

  defp apply_command(%{action: :set_tempo, params: %{bpm: bpm}}, state) do
    %{state | tempo: bpm}
  end

  defp apply_command(%{action: :loop, params: %{from: from, to: to}}, state) do
    %{state | loop: {from, to}}
  end

  defp apply_command(
         %{action: :add_effect, target: {:track, n}, params: %{effect: effect}},
         state
       ) do
    update_track(state, n, fn t -> %{t | effects: t.effects ++ [effect]} end)
  end

  defp apply_command(
         %{action: :remove_effect, target: {:track, n}, params: %{effect: effect}},
         state
       ) do
    update_track(state, n, fn t -> %{t | effects: List.delete(t.effects, effect)} end)
  end

  defp apply_command(_cmd, state), do: state

  defp update_track(state, n, fun) do
    case Map.get(state.tracks, n) do
      nil -> state
      track -> %{state | tracks: Map.put(state.tracks, n, fun.(track))}
    end
  end

  defp describe_session(state) do
    armed =
      state.tracks
      |> Map.values()
      |> Enum.filter(& &1.armed)
      |> Enum.map(&"#{&1.name} (#{&1.number})")

    muted =
      state.tracks
      |> Map.values()
      |> Enum.filter(& &1.muted)
      |> Enum.map(&"#{&1.name} (#{&1.number})")

    soloed =
      state.tracks
      |> Map.values()
      |> Enum.filter(& &1.soloed)
      |> Enum.map(&"#{&1.name} (#{&1.number})")

    parts = ["Tempo: #{state.tempo} BPM"]

    parts = if armed != [], do: parts ++ ["Armed: #{Enum.join(armed, ", ")}"], else: parts
    parts = if muted != [], do: parts ++ ["Muted: #{Enum.join(muted, ", ")}"], else: parts
    parts = if soloed != [], do: parts ++ ["Soloed: #{Enum.join(soloed, ", ")}"], else: parts

    parts =
      case state.loop do
        {from, to} -> parts ++ ["Loop: bar #{from} to #{to}"]
        _ -> parts
      end

    Enum.join(parts, ". ")
  end
end
