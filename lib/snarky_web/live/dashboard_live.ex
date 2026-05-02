defmodule SnarkyWeb.DashboardLive do
  use SnarkyWeb, :live_view

  @tick_interval 250

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Snarky.PubSub, "session")
      Phoenix.PubSub.subscribe(Snarky.PubSub, "commands")
      Phoenix.PubSub.subscribe(Snarky.PubSub, "listener")
      Phoenix.PubSub.subscribe(Snarky.PubSub, "tts")
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
      |> assign(:mic_active, false)

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

  def handle_info({:command, _action, text}, socket) do
    entry = %{text: text, time: Time.utc_now()}
    log = Enum.take([entry | socket.assigns.command_log], 20)
    {:noreply, assign(socket, :command_log, log)}
  end

  def handle_info({:heard, text}, socket) do
    {:noreply, assign(socket, :last_heard, text)}
  end

  def handle_info({:listening, status}, socket) do
    {:noreply, assign(socket, :listening, status)}
  end

  def handle_info({:tts_audio, _audio_data}, socket) do
    {:noreply, socket}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  @impl true
  def handle_event("transport", %{"action" => action}, socket) do
    cmd = %Snarky.CommandRouter.Command{action: String.to_existing_atom(action)}
    Task.start(fn -> Snarky.Executor.execute(cmd) end)
    {:noreply, socket}
  end

  def handle_event("track_action", %{"track" => track_str, "action" => action}, socket) do
    track = String.to_integer(track_str)

    cmd = %Snarky.CommandRouter.Command{
      action: String.to_existing_atom(action),
      target: {:track, track}
    }

    Task.start(fn -> Snarky.Executor.execute(cmd) end)
    {:noreply, socket}
  end

  def handle_event("toggle_mic", _params, socket) do
    new_state = !socket.assigns.mic_active

    {:noreply,
     socket
     |> assign(:mic_active, new_state)
     |> push_event("toggle_mic", %{active: new_state})}
  end

  def handle_event("audio_chunk", %{"data" => base64_audio}, socket) do
    case Base.decode64(base64_audio) do
      {:ok, pcm_data} ->
        Task.start(fn -> process_ipad_audio(pcm_data) end)

      :error ->
        :ok
    end

    {:noreply, socket}
  end

  def handle_event(_event, _params, socket), do: {:noreply, socket}

  defp process_ipad_audio(pcm_data) do
    audio_dir = Path.join(System.tmp_dir!(), "snarky_audio")
    File.mkdir_p!(audio_dir)
    path = Path.join(audio_dir, "ipad_#{System.unique_integer([:positive])}.wav")

    write_wav(path, pcm_data, 16_000)

    case Snarky.Transcriber.transcribe(path) do
      {:ok, ""} ->
        :ok

      {:ok, text} ->
        Phoenix.PubSub.broadcast(Snarky.PubSub, "listener", {:heard, text})
        Snarky.CommandRouter.route(text)

      {:error, _} ->
        :ok
    end
  end

  defp write_wav(path, pcm_data, sample_rate) do
    data_size = byte_size(pcm_data)
    file_size = data_size + 36

    header =
      <<"RIFF", file_size::little-32, "WAVE", "fmt ", 16::little-32, 1::little-16, 1::little-16,
        sample_rate::little-32, sample_rate * 2::little-32, 2::little-16, 16::little-16, "data",
        data_size::little-32>>

    File.write!(path, header <> pcm_data)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div style="display: flex; flex-direction: column; height: 100vh; height: 100dvh; padding: env(safe-area-inset-top) env(safe-area-inset-right) env(safe-area-inset-bottom) env(safe-area-inset-left);">

      <!-- Transport Bar -->
      <div style="display: flex; align-items: center; justify-content: space-between; padding: 10px 16px; background: var(--surface); border-bottom: 1px solid var(--surface-alt);">
        <div style="display: flex; gap: 6px;">
          <button phx-click="transport" phx-value-action="rewind" style={transport_btn()}>⏮</button>
          <button phx-click="transport" phx-value-action="stop" style={transport_btn()}>⏹</button>
          <button phx-click="transport" phx-value-action="play" style={transport_btn() <> "background: var(--surface-alt);"}>▶</button>
          <button phx-click="transport" phx-value-action="record" style={transport_btn() <> "background: var(--armed); color: white;"}>⏺</button>
        </div>

        <div style="display: flex; align-items: center; gap: 16px;">
          <div style="font-size: 22px; font-weight: 700; font-variant-numeric: tabular-nums;">
            <%= @tempo %> BPM
          </div>

          <div style="display: flex; align-items: center; gap: 6px;">
            <div style={"width: 8px; height: 8px; border-radius: 50%; background: #{if @mcu_connected, do: "var(--green)", else: "var(--accent)"};"} />
            <span style="font-size: 10px; color: var(--text-dim);">MCU</span>
          </div>
        </div>

        <div style="display: flex; align-items: center; gap: 12px;">
          <button phx-click="toggle_mic" style={"border: none; background: #{if @mic_active, do: "var(--armed)", else: "var(--bg)"}; color: #{if @mic_active, do: "white", else: "var(--text-dim)"}; font-size: 16px; width: 40px; height: 36px; border-radius: 6px; cursor: pointer; -webkit-tap-highlight-color: transparent;"}>
            🎤
          </button>
          <div style={"font-size: 11px; color: #{if @listening, do: "var(--accent)", else: "var(--text-dim)"};"}>
            <%= if @listening, do: "● Listening", else: "○ Idle" %>
          </div>
        </div>
      </div>

      <!-- Channel Strips + Master -->
      <div style="flex: 1; display: flex; gap: 2px; padding: 8px; overflow: hidden;">
        <!-- 8 Channel Strips -->
        <div style="flex: 1; display: grid; grid-template-columns: repeat(8, 1fr); gap: 2px;">
          <%= for n <- 1..8 do %>
            <.channel_strip track={Map.get(@tracks, n, default_track(n))} number={n} />
          <% end %>
        </div>

        <!-- Master Fader -->
        <div style="width: 64px; display: flex; flex-direction: column; background: var(--surface-alt); border-radius: 8px; padding: 8px; gap: 6px;">
          <div style="text-align: center; font-size: 10px; font-weight: 700; color: var(--accent); text-transform: uppercase; letter-spacing: 1px;">
            MST
          </div>
          <div style="flex: 1; display: flex; justify-content: center; align-items: flex-end; padding: 4px 0;">
            <div style="width: 12px; height: 100%; background: var(--bg); border-radius: 4px; position: relative; overflow: hidden;">
              <div style="position: absolute; bottom: 0; width: 100%; height: 70%; background: var(--teal); border-radius: 4px; transition: height 0.2s;" />
            </div>
          </div>
          <div style="text-align: center; font-size: 11px; font-variant-numeric: tabular-nums; color: var(--text-dim);">
            0 dB
          </div>
        </div>
      </div>

      <!-- Command Log -->
      <div style="height: 100px; background: var(--surface); border-top: 1px solid var(--surface-alt); padding: 6px 16px; overflow-y: auto;">
        <div style="display: flex; align-items: center; gap: 8px; margin-bottom: 4px;">
          <span style="font-size: 10px; color: var(--text-dim); text-transform: uppercase; letter-spacing: 1px;">
            Log
          </span>
          <%= if @last_heard do %>
            <span style="font-size: 11px; color: var(--accent); font-style: italic;">
              "<%= @last_heard %>"
            </span>
          <% end %>
        </div>
        <%= for entry <- @command_log do %>
          <div style="font-size: 11px; color: var(--text-dim); padding: 1px 0; font-variant-numeric: tabular-nums;">
            <span style="color: var(--teal);"><%= Calendar.strftime(entry.time, "%H:%M:%S") %></span>
            <span style="color: var(--text);"><%= entry.text %></span>
          </div>
        <% end %>
      </div>
    </div>

    <script>
      // iPad mic capture
      (function() {
        let mediaRecorder = null;
        let audioContext = null;
        let stream = null;

        window.addEventListener("phx:toggle_mic", async (e) => {
          const active = e.detail.active;
          if (active) {
            try {
              stream = await navigator.mediaDevices.getUserMedia({
                audio: { sampleRate: 16000, channelCount: 1, echoCancellation: true }
              });
              audioContext = new AudioContext({ sampleRate: 16000 });
              const source = audioContext.createMediaStreamSource(stream);
              const processor = audioContext.createScriptProcessor(4096, 1, 1);

              let buffer = [];
              const CHUNK_SIZE = 16000 * 5; // 5 seconds

              processor.onaudioprocess = (e) => {
                const input = e.inputBuffer.getChannelData(0);
                const pcm16 = new Int16Array(input.length);
                for (let i = 0; i < input.length; i++) {
                  pcm16[i] = Math.max(-32768, Math.min(32767, input[i] * 32768));
                }
                buffer.push(...pcm16);

                if (buffer.length >= CHUNK_SIZE) {
                  const chunk = new Int16Array(buffer.splice(0, CHUNK_SIZE));
                  const b64 = btoa(String.fromCharCode(...new Uint8Array(chunk.buffer)));
                  liveSocket.execJS(document.body, JSON.stringify([
                    ["push", {event: "audio_chunk", data: {data: b64}}]
                  ]));
                }
              };

              source.connect(processor);
              processor.connect(audioContext.destination);
            } catch (err) {
              console.error("Mic access denied:", err);
            }
          } else {
            if (stream) stream.getTracks().forEach(t => t.stop());
            if (audioContext) audioContext.close();
            stream = null;
            audioContext = null;
          }
        });
      })();
    </script>
    """
  end

  defp channel_strip(assigns) do
    ~H"""
    <div style="display: flex; flex-direction: column; background: var(--surface); border-radius: 8px; padding: 8px; gap: 4px;">
      <div style="text-align: center; font-size: 11px; font-weight: 600; color: var(--text-dim); text-transform: uppercase; letter-spacing: 0.5px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">
        <%= @track.name %>
      </div>

      <div style="flex: 1; display: flex; justify-content: center; align-items: flex-end; padding: 4px 0;">
        <div style="width: 6px; height: 100%; background: var(--bg); border-radius: 3px; position: relative; overflow: hidden;">
          <div style={"position: absolute; bottom: 0; width: 100%; height: #{meter_height(@track.volume_db)}%; background: #{meter_color(@track.volume_db)}; border-radius: 3px; transition: height 0.2s;"} />
        </div>
      </div>

      <div style="text-align: center; font-size: 10px; font-variant-numeric: tabular-nums; color: var(--text-dim);">
        <%= @track.volume_db %> dB
      </div>

      <div style="text-align: center; font-size: 9px; color: var(--text-dim);">
        <%= format_pan(@track.pan) %>
      </div>

      <div style="display: flex; gap: 3px;">
        <button
          phx-click="track_action"
          phx-value-track={@number}
          phx-value-action={if @track.muted, do: "unmute", else: "mute"}
          style={track_btn(@track.muted, "var(--muted)")}
        >M</button>
        <button
          phx-click="track_action"
          phx-value-track={@number}
          phx-value-action={if @track.soloed, do: "unsolo", else: "solo"}
          style={track_btn(@track.soloed, "var(--soloed)")}
        >S</button>
        <button
          phx-click="track_action"
          phx-value-track={@number}
          phx-value-action={if @track.armed, do: "disarm", else: "arm"}
          style={track_btn(@track.armed, "var(--armed)")}
        >R</button>
      </div>
    </div>
    """
  end

  defp transport_btn do
    "border: none; background: var(--bg); color: var(--text); font-size: 18px; width: 44px; height: 36px; border-radius: 6px; cursor: pointer; display: flex; align-items: center; justify-content: center; -webkit-tap-highlight-color: transparent;"
  end

  defp track_btn(active, color) do
    bg = if active, do: color, else: "var(--bg)"
    text_color = if active, do: "white", else: "var(--text-dim)"

    "flex: 1; border: none; background: #{bg}; color: #{text_color}; font-size: 10px; font-weight: 700; padding: 5px 0; border-radius: 4px; cursor: pointer; -webkit-tap-highlight-color: transparent;"
  end

  defp default_track(n) do
    %{
      name: "Track #{n}",
      armed: false,
      muted: false,
      soloed: false,
      volume_db: 0,
      pan: :center,
      effects: []
    }
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
