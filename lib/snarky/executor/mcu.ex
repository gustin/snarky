defmodule Snarky.Executor.MCU do
  require Logger
  alias Snarky.CommandRouter.Command
  alias Snarky.MCU.Protocol, as: P

  def execute(%Command{action: :play}) do
    note_bang(P.play())
    {:ok, "Playing"}
  end

  def execute(%Command{action: :stop}) do
    note_bang(P.stop())
    {:ok, "Stopped"}
  end

  def execute(%Command{action: :record, target: nil}) do
    note_bang(P.record())
    {:ok, "Recording"}
  end

  def execute(%Command{action: :record, target: {:track, n}}) do
    ch = n - 1
    note_bang(P.select(ch))
    note_bang(P.rec(ch))
    note_bang(P.record())
    {:ok, "Recording track #{n}"}
  end

  def execute(%Command{action: :pause}) do
    note_bang(P.stop())
    {:ok, "Paused"}
  end

  def execute(%Command{action: :rewind}) do
    note_bang(P.rewind())
    {:ok, "Rewound"}
  end

  def execute(%Command{action: :undo}) do
    note_bang(P.undo())
    {:ok, "Undone"}
  end

  def execute(%Command{action: :redo}) do
    note_bang(P.shift())
    note_bang(P.undo())
    {:ok, "Redone"}
  end

  def execute(%Command{action: :save}) do
    note_bang(P.save())
    {:ok, "Saved"}
  end

  def execute(%Command{action: :mute, target: :all}) do
    for ch <- 0..7, do: note_bang(P.mute(ch))
    {:ok, "All tracks muted"}
  end

  def execute(%Command{action: :mute, target: {:track, n}}) do
    note_bang(P.mute(n - 1))
    {:ok, "Track #{n} muted"}
  end

  def execute(%Command{action: :unmute, target: :all}) do
    for ch <- 0..7, do: note_bang(P.mute(ch))
    {:ok, "All tracks unmuted"}
  end

  def execute(%Command{action: :unmute, target: {:track, n}}) do
    note_bang(P.mute(n - 1))
    {:ok, "Track #{n} unmuted"}
  end

  def execute(%Command{action: :solo, target: {:track, n}}) do
    note_bang(P.solo(n - 1))
    {:ok, "Track #{n} soloed"}
  end

  def execute(%Command{action: :unsolo, target: {:track, n}}) do
    note_bang(P.solo(n - 1))
    {:ok, "Track #{n} unsoloed"}
  end

  def execute(%Command{action: :arm, target: {:track, n}}) do
    note_bang(P.rec(n - 1))
    {:ok, "Track #{n} armed"}
  end

  def execute(%Command{action: :disarm, target: {:track, n}}) do
    note_bang(P.rec(n - 1))
    {:ok, "Track #{n} disarmed"}
  end

  def execute(%Command{action: :set_volume, target: {:track, n}, params: %{db: db}}) do
    ch = n - 1
    value = P.db_to_fader(db)
    Snarky.MCU.send_note(P.fader_touch(ch), 127)
    Snarky.MCU.send_pitch_bend(ch, value)
    Snarky.MCU.send_note(P.fader_touch(ch), 0)
    {:ok, "Track #{n} volume set to #{db} dB"}
  end

  def execute(%Command{action: :volume_up, target: {:track, n}}) do
    ch = n - 1
    current = Snarky.Session.get_track(n)
    new_db = min(((current && current.volume_db) || 0) + 3, 10)
    value = P.db_to_fader(new_db)
    Snarky.MCU.send_note(P.fader_touch(ch), 127)
    Snarky.MCU.send_pitch_bend(ch, value)
    Snarky.MCU.send_note(P.fader_touch(ch), 0)
    {:ok, "Track #{n} volume up"}
  end

  def execute(%Command{action: :volume_down, target: {:track, n}}) do
    ch = n - 1
    current = Snarky.Session.get_track(n)
    new_db = max(((current && current.volume_db) || 0) - 3, -70)
    value = P.db_to_fader(new_db)
    Snarky.MCU.send_note(P.fader_touch(ch), 127)
    Snarky.MCU.send_pitch_bend(ch, value)
    Snarky.MCU.send_note(P.fader_touch(ch), 0)
    {:ok, "Track #{n} volume down"}
  end

  def execute(%Command{action: :pan, target: {:track, n}, params: %{direction: dir}}) do
    ch = n - 1
    note_bang(P.select(ch))

    case dir do
      :left ->
        for _ <- 1..20, do: Snarky.MCU.send_cc(P.vpot_cc(ch), P.counter_clockwise())

      :right ->
        for _ <- 1..20, do: Snarky.MCU.send_cc(P.vpot_cc(ch), P.clockwise())

      :center ->
        note_bang(P.vpot_click(ch))
    end

    {:ok, "Track #{n} panned #{dir}"}
  end

  def execute(%Command{action: :set_tempo, params: %{bpm: bpm}}) do
    Logger.info("Tempo #{bpm} — MCU cannot set tempo directly, falling back")
    {:error, :fallback_to_applescript}
  end

  def execute(%Command{action: :loop}) do
    note_bang(P.cycle())
    {:ok, "Loop toggled"}
  end

  def execute(%Command{action: :loop, params: %{from: _from, to: _to}}) do
    Logger.info("Loop range — MCU cannot set locators directly, falling back")
    {:error, :fallback_to_applescript}
  end

  def execute(%Command{action: :bounce}) do
    {:error, :fallback_to_applescript}
  end

  def execute(%Command{action: :export}) do
    {:error, :fallback_to_applescript}
  end

  def execute(%Command{action: action})
      when action in [:add_effect, :remove_effect] do
    {:error, :fallback_to_applescript}
  end

  def execute(%Command{} = cmd) do
    Logger.warning("MCU executor: unhandled #{inspect(cmd)}")
    {:error, :unhandled}
  end

  defp note_bang(note) do
    Snarky.MCU.send_note(note, 127)
    Process.sleep(30)
    Snarky.MCU.send_note(note, 0)
  end
end
