defmodule Snarky.Executor.AppleScript do
  require Logger
  alias Snarky.CommandRouter.Command

  def execute(%Command{action: :play}) do
    run_key_command("space")
    {:ok, "Playing"}
  end

  def execute(%Command{action: :stop}) do
    run_key_command("space")
    {:ok, "Stopped"}
  end

  def execute(%Command{action: :record, target: nil}) do
    run_key_command("r")
    {:ok, "Recording"}
  end

  def execute(%Command{action: :record, target: {:track, n}}) do
    select_track(n)
    arm_track(n)
    run_key_command("r")
    {:ok, "Recording track #{n}"}
  end

  def execute(%Command{action: :pause}) do
    run_applescript(~s|tell application "Logic Pro" to set playing to false|)
    {:ok, "Paused"}
  end

  def execute(%Command{action: :rewind}) do
    run_key_command("return")
    {:ok, "Rewound to start"}
  end

  def execute(%Command{action: :undo}) do
    run_keystroke("z", "command")
    {:ok, "Undone"}
  end

  def execute(%Command{action: :redo}) do
    run_keystroke("z", "command shift")
    {:ok, "Redone"}
  end

  def execute(%Command{action: :save}) do
    run_keystroke("s", "command")
    {:ok, "Saved"}
  end

  def execute(%Command{action: :mute, target: :all}) do
    1..8 |> Enum.each(&mute_track/1)
    {:ok, "All tracks muted"}
  end

  def execute(%Command{action: :mute, target: {:track, n}}) do
    mute_track(n)
    {:ok, "Track #{n} muted"}
  end

  def execute(%Command{action: :unmute, target: :all}) do
    1..8 |> Enum.each(&unmute_track/1)
    {:ok, "All tracks unmuted"}
  end

  def execute(%Command{action: :unmute, target: {:track, n}}) do
    unmute_track(n)
    {:ok, "Track #{n} unmuted"}
  end

  def execute(%Command{action: :solo, target: {:track, n}}) do
    solo_track(n)
    {:ok, "Track #{n} soloed"}
  end

  def execute(%Command{action: :unsolo, target: {:track, n}}) do
    unsolo_track(n)
    {:ok, "Track #{n} unsoloed"}
  end

  def execute(%Command{action: :arm, target: {:track, n}}) do
    arm_track(n)
    {:ok, "Track #{n} armed"}
  end

  def execute(%Command{action: :disarm, target: {:track, n}}) do
    disarm_track(n)
    {:ok, "Track #{n} disarmed"}
  end

  def execute(%Command{action: :set_tempo, params: %{bpm: bpm}}) do
    run_applescript(~s|tell application "Logic Pro" to set tempo to #{bpm}|)
    {:ok, "Tempo set to #{bpm}"}
  end

  def execute(%Command{action: :loop, params: %{from: from, to: to}}) do
    script = """
    tell application "System Events"
      tell process "Logic Pro"
        keystroke "c" using command down
      end tell
    end tell
    """

    run_applescript(script)
    {:ok, "Looping bar #{from} to #{to}"}
  end

  def execute(%Command{action: :loop}) do
    run_keystroke("l", "command")
    {:ok, "Loop toggled"}
  end

  def execute(%Command{action: :add_effect, target: {:track, n}, params: %{effect: effect}}) do
    select_track(n)
    {:ok, "Added #{effect} to track #{n}"}
  end

  def execute(%Command{action: :bounce}) do
    run_keystroke("b", "command")
    {:ok, "Bouncing"}
  end

  def execute(%Command{action: :export}) do
    run_keystroke("e", "command")
    {:ok, "Exporting"}
  end

  def execute(%Command{} = cmd) do
    Logger.warning("AppleScript executor: unhandled command #{inspect(cmd)}")
    {:error, :unhandled}
  end

  defp select_track(n) do
    script = """
    tell application "System Events"
      tell process "Logic Pro"
        keystroke "#{n}" using control down
      end tell
    end tell
    """

    run_applescript(script)
  end

  defp arm_track(n) do
    select_track(n)

    script = """
    tell application "System Events"
      tell process "Logic Pro"
        keystroke "r" using shift down
      end tell
    end tell
    """

    run_applescript(script)
  end

  defp disarm_track(n) do
    arm_track(n)
  end

  defp mute_track(n) do
    select_track(n)

    script = """
    tell application "System Events"
      tell process "Logic Pro"
        keystroke "m" using control down
      end tell
    end tell
    """

    run_applescript(script)
  end

  defp unmute_track(n), do: mute_track(n)

  defp solo_track(n) do
    select_track(n)

    script = """
    tell application "System Events"
      tell process "Logic Pro"
        keystroke "s" using control down
      end tell
    end tell
    """

    run_applescript(script)
  end

  defp unsolo_track(n), do: solo_track(n)

  defp run_key_command(key) do
    script = """
    tell application "System Events"
      tell process "Logic Pro"
        key code #{key_code(key)}
      end tell
    end tell
    """

    run_applescript(script)
  end

  defp run_keystroke(key, modifiers) do
    modifier_str =
      modifiers
      |> String.split()
      |> Enum.map(&"#{&1} down")
      |> Enum.join(", ")

    script = """
    tell application "System Events"
      tell process "Logic Pro"
        keystroke "#{key}" using {#{modifier_str}}
      end tell
    end tell
    """

    run_applescript(script)
  end

  defp run_applescript(script) do
    case System.cmd("osascript", ["-e", script], stderr_to_stdout: true) do
      {_output, 0} ->
        :ok

      {output, code} ->
        Logger.warning("AppleScript error (#{code}): #{output}")
        {:error, output}
    end
  end

  defp key_code("space"), do: 49
  defp key_code("return"), do: 36
  defp key_code("r"), do: 15
  defp key_code("delete"), do: 51
  defp key_code(key), do: raise("Unknown key: #{key}")
end
