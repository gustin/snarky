defmodule Snarky.Executor.OSC do
  use GenServer
  require Logger
  alias Snarky.CommandRouter.Command

  defstruct [:socket, :host, :port]

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def execute(%Command{} = cmd) do
    GenServer.call(__MODULE__, {:execute, cmd})
  end

  @impl true
  def init(_opts) do
    host = Application.get_env(:snarky, :osc_host, {127, 0, 0, 1})
    port = Application.get_env(:snarky, :osc_port, 8000)

    case :gen_udp.open(0) do
      {:ok, socket} ->
        {:ok, %__MODULE__{socket: socket, host: host, port: port}}

      {:error, reason} ->
        Logger.error("Failed to open OSC socket: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  @impl true
  def handle_call({:execute, cmd}, _from, state) do
    result = do_execute(cmd, state)
    {:reply, result, state}
  end

  defp do_execute(%Command{action: :set_volume, target: {:track, n}, params: %{db: db}}, state) do
    fader_value = db_to_fader(db)
    send_osc(state, "/track/#{n}/volume", [fader_value])
    {:ok, "Track #{n} volume set to #{db} dB"}
  end

  defp do_execute(%Command{action: :volume_up, target: {:track, n}}, state) do
    send_osc(state, "/track/#{n}/volume/+", [3.0])
    {:ok, "Track #{n} volume up"}
  end

  defp do_execute(%Command{action: :volume_down, target: {:track, n}}, state) do
    send_osc(state, "/track/#{n}/volume/-", [3.0])
    {:ok, "Track #{n} volume down"}
  end

  defp do_execute(%Command{action: :pan, target: {:track, n}, params: %{direction: dir}}, state) do
    value =
      case dir do
        :left -> -1.0
        :right -> 1.0
        :center -> 0.0
      end

    send_osc(state, "/track/#{n}/pan", [value])
    {:ok, "Track #{n} panned #{dir}"}
  end

  defp do_execute(%Command{action: :set_volume, target: :all, params: %{db: db}}, state) do
    fader_value = db_to_fader(db)

    1..8
    |> Enum.each(fn n ->
      send_osc(state, "/track/#{n}/volume", [fader_value])
    end)

    {:ok, "All tracks set to #{db} dB"}
  end

  defp do_execute(%Command{} = cmd, _state) do
    Logger.warning("OSC executor: unhandled #{inspect(cmd)}")
    {:error, :unhandled}
  end

  defp send_osc(%{socket: socket, host: host, port: port}, address, args) do
    packet = encode_osc_message(address, args)
    :gen_udp.send(socket, host, port, packet)
  end

  defp encode_osc_message(address, args) do
    padded_address = osc_string(address)
    type_tag = osc_string("," <> Enum.map_join(args, "", &osc_type/1))
    arg_data = Enum.map_join(args, "", &osc_encode_arg/1)

    padded_address <> type_tag <> arg_data
  end

  defp osc_string(str) do
    bytes = str <> <<0>>
    padding = rem(4 - rem(byte_size(bytes), 4), 4)
    bytes <> :binary.copy(<<0>>, padding)
  end

  defp osc_type(v) when is_float(v), do: "f"
  defp osc_type(v) when is_integer(v), do: "i"
  defp osc_type(v) when is_binary(v), do: "s"

  defp osc_encode_arg(v) when is_float(v), do: <<v::float-32-big>>
  defp osc_encode_arg(v) when is_integer(v), do: <<v::integer-32-big>>
  defp osc_encode_arg(v) when is_binary(v), do: osc_string(v)

  defp db_to_fader(db) when db <= -70, do: 0.0
  defp db_to_fader(db) when db >= 6, do: 1.0
  defp db_to_fader(db), do: (db + 70) / 76.0
end
