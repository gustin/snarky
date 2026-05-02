defmodule Snarky.Executor do
  require Logger
  alias Snarky.CommandRouter.Command

  def execute(%Command{} = cmd) do
    Logger.info("Executing: #{cmd.action} on #{inspect(cmd.target)}")

    result =
      case cmd.action do
        action when action in [:play, :stop, :record, :pause, :rewind, :undo, :redo, :save] ->
          Snarky.Executor.AppleScript.execute(cmd)

        action when action in [:mute, :unmute, :solo, :unsolo, :arm, :disarm] ->
          Snarky.Executor.AppleScript.execute(cmd)

        action when action in [:set_volume, :volume_up, :volume_down, :pan] ->
          Snarky.Executor.OSC.execute(cmd)

        :set_tempo ->
          Snarky.Executor.AppleScript.execute(cmd)

        :loop ->
          Snarky.Executor.AppleScript.execute(cmd)

        action when action in [:add_effect, :remove_effect] ->
          Snarky.Executor.AppleScript.execute(cmd)

        :bounce ->
          Snarky.Executor.AppleScript.execute(cmd)

        :export ->
          Snarky.Executor.AppleScript.execute(cmd)

        _ ->
          Logger.warning("Unknown action: #{cmd.action}")
          {:error, :unknown_action}
      end

    case result do
      {:ok, message} ->
        Snarky.Speaker.say(message)
        Snarky.Session.track_command(cmd)
        :ok

      {:error, reason} ->
        Snarky.Speaker.say("Sorry, that didn't work")
        Logger.error("Execution failed: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
