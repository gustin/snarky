defmodule SnarkyWeb.DashboardLive do
  use SnarkyWeb, :live_view

  @tick_interval 250

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Snarky.PubSub, "session")
      Phoenix.PubSub.subscribe(Snarky.PubSub, "commands")
      Phoenix.PubSub.subscribe(Snarky.PubSub, "listener")
      :timer.send_interval(@tick_interval, self(), :tick)
    end

    session = Snarky.Session.get_state()

    socket =
      socket
      |> assign(:session, session)
      |> assign(:tracks, session.tracks)
      |> assign(:tempo, session.tempo)
      |> assign(:listening, false)
      |> assign(:last_heard, nil)
      |> assign(:command_log, [])
      |> assign(:mcu_connected, false)

    {:ok, socket}
  end

  @impl true
  def handle_info(:tick, socket) do
    mcu = Snarky.MCU.connected?()
    session = Snarky.Session.get_state()

    {:noreply,
     socket
     |> assign(:mcu_connected, mcu)
     |> assign(:session, session)
     |> assign(:tracks, session.tracks)
     |> assign(:tempo, session.tempo)}
  end

  def handle_info({:session_updated, session}, socket) do
    {:noreply,
     socket
     |> assign(:session, session)
     |> assign(:tracks, session.tracks)
     |> assign(:tempo, session.tempo)}
  end

  def handle_info({:command, action, text}, socket) do
    entry = %{action: action, text: text, time: Time.utc_now()}
    log = Enum.take([entry | socket.assigns.command_log], 20)
    {:noreply, assign(socket, :command_log, log)}
  end

  def handle_info({:heard, text}, socket) do
    {:noreply, assign(socket, :last_heard, text)}
  end

  def handle_info({:listening, status}, socket) do
    {:noreply, assign(socket, :listening, status)}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  @impl true
  def handle_event("transport", %{"action" => action}, socket) do
    cmd = %Snarky.CommandRouter.Command{action: String.to_existing_atom(action)}
    Snarky.Executor.execute(cmd)
    {:noreply, socket}
  end

  def handle_event("track_action", %{"track" => track_str, "action" => action}, socket) do
    track = String.to_integer(track_str)

    cmd = %Snarky.CommandRouter.Command{
      action: String.to_existing_atom(action),
      target: {:track, track}
    }

    Snarky.Executor.execute(cmd)
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div style="display: flex; flex-direction: column; height: 100vh; height: 100dvh; padding: env(safe-area-inset-top) env(safe-area-inset-right) env(safe-area-inset-bottom) env(safe-area-inset-left);">

      <!-- Transport Bar -->
      <div style="display: flex; align-items: center; justify-content: space-between; padding: 12px 16px; background: var(--surface); border-bottom: 1px solid var(--surface-alt);">
        <div style="display: flex; gap: 8px;">
          <button phx-click="transport" phx-value-action="rewind" style={transport_btn()}>
            ⏮
          </button>
          <button phx-click="transport" phx-value-action="stop" style={transport_btn()}>
            ⏹
          </button>
          <button phx-click="transport" phx-value-action="play" style={transport_btn() <> "background: var(--surface-alt);"}>
            ▶
          </button>
          <button phx-click="transport" phx-value-action="record" style={transport_btn() <> "background: var(--armed); color: white;"}>
            ⏺
          </button>
        </div>

        <div style="display: flex; align-items: center; gap: 20px;">
          <div style="font-size: 24px; font-weight: 700; font-variant-numeric: tabular-nums;">
            <%= @tempo %> BPM
          </div>
          <div style={"width: 10px; height: 10px; border-radius: 50%; background: #{if @mcu_connected, do: "var(--green)", else: "var(--accent)"};"}>
          </div>
        </div>

        <div style="display: flex; align-items: center; gap: 12px;">
          <div style={"font-size: 13px; color: #{if @listening, do: "var(--accent)", else: "var(--text-dim)"};"}>
            <%= if @listening, do: "● Listening", else: "○ Idle" %>
          </div>
        </div>
      </div>

      <!-- Channel Strips -->
      <div style="flex: 1; display: grid; grid-template-columns: repeat(8, 1fr); gap: 2px; padding: 8px; overflow: hidden;">
        <%= for n <- 1..8 do %>
          <% track = Map.get(@tracks, n, %{name: "Track #{n}", armed: false, muted: false, soloed: false, volume_db: 0, pan: :center, effects: []}) %>
          <div style="display: flex; flex-direction: column; background: var(--surface); border-radius: 8px; padding: 8px; gap: 6px;">

            <!-- Track Name -->
            <div style="text-align: center; font-size: 12px; font-weight: 600; color: var(--text-dim); text-transform: uppercase; letter-spacing: 0.5px;">
              <%= track.name %>
            </div>

            <!-- Meter placeholder -->
            <div style="flex: 1; display: flex; justify-content: center; align-items: flex-end; padding: 4px 0;">
              <div style="width: 8px; height: 100%; background: var(--bg); border-radius: 4px; position: relative; overflow: hidden;">
                <div style={"position: absolute; bottom: 0; width: 100%; height: #{meter_height(track.volume_db)}%; background: #{meter_color(track.volume_db)}; border-radius: 4px; transition: height 0.2s;"}></div>
              </div>
            </div>

            <!-- Volume -->
            <div style="text-align: center; font-size: 11px; font-variant-numeric: tabular-nums; color: var(--text-dim);">
              <%= track.volume_db %> dB
            </div>

            <!-- Pan -->
            <div style="text-align: center; font-size: 10px; color: var(--text-dim);">
              <%= format_pan(track.pan) %>
            </div>

            <!-- Buttons -->
            <div style="display: flex; gap: 4px;">
              <button
                phx-click="track_action"
                phx-value-track={n}
                phx-value-action={if track.muted, do: "unmute", else: "mute"}
                style={track_btn(track.muted, "var(--muted)")}
              >
                M
              </button>
              <button
                phx-click="track_action"
                phx-value-track={n}
                phx-value-action={if track.soloed, do: "unsolo", else: "solo"}
                style={track_btn(track.soloed, "var(--soloed)")}
              >
                S
              </button>
              <button
                phx-click="track_action"
                phx-value-track={n}
                phx-value-action={if track.armed, do: "disarm", else: "arm"}
                style={track_btn(track.armed, "var(--armed)")}
              >
                R
              </button>
            </div>
          </div>
        <% end %>
      </div>

      <!-- Command Log -->
      <div style="height: 120px; background: var(--surface); border-top: 1px solid var(--surface-alt); padding: 8px 16px; overflow-y: auto;">
        <div style="display: flex; align-items: center; gap: 8px; margin-bottom: 6px;">
          <span style="font-size: 11px; color: var(--text-dim); text-transform: uppercase; letter-spacing: 1px;">
            Command Log
          </span>
          <%= if @last_heard do %>
            <span style="font-size: 11px; color: var(--accent);">
              "<%= @last_heard %>"
            </span>
          <% end %>
        </div>
        <%= for entry <- @command_log do %>
          <div style="font-size: 12px; color: var(--text-dim); padding: 2px 0; font-variant-numeric: tabular-nums;">
            <span style="color: var(--teal);"><%= Calendar.strftime(entry.time, "%H:%M:%S") %></span>
            <span style="color: var(--text);"><%= entry.text %></span>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp transport_btn do
    "border: none; background: var(--bg); color: var(--text); font-size: 20px; width: 48px; height: 40px; border-radius: 6px; cursor: pointer; display: flex; align-items: center; justify-content: center; -webkit-tap-highlight-color: transparent;"
  end

  defp track_btn(active, color) do
    bg = if active, do: color, else: "var(--bg)"
    text_color = if active, do: "white", else: "var(--text-dim)"

    "flex: 1; border: none; background: #{bg}; color: #{text_color}; font-size: 11px; font-weight: 700; padding: 6px 0; border-radius: 4px; cursor: pointer; -webkit-tap-highlight-color: transparent;"
  end

  defp meter_height(db) when db <= -60, do: 5
  defp meter_height(db) when db >= 0, do: 85
  defp meter_height(db), do: round((db + 60) / 60 * 80 + 5)

  defp meter_color(db) when db > -6, do: "var(--meter-high)"
  defp meter_color(db) when db > -20, do: "var(--meter-mid)"
  defp meter_color(_db), do: "var(--meter-low)"

  defp format_pan(:center), do: "C"
  defp format_pan(:left), do: "◀ L"
  defp format_pan(:right), do: "R ▶"
  defp format_pan(_), do: "C"
end
