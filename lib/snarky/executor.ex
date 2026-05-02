defmodule Snarky.Executor do
  require Logger
  alias Snarky.CommandRouter.Command

  def execute(%Command{} = cmd) do
    Logger.info("Executing: #{cmd.action} on #{inspect(cmd.target)}")

    result =
      if Snarky.MCU.connected?() do
        case Snarky.Executor.MCU.execute(cmd) do
          {:error, :fallback_to_applescript} ->
            Logger.debug("MCU fallback to AppleScript for #{cmd.action}")
            execute_legacy(cmd)

          other ->
            other
        end
      else
        execute_legacy(cmd)
      end

    case result do
      {:ok, message} ->
        Snarky.Speaker.say(message)
        Snarky.Session.track_command(cmd)
        Phoenix.PubSub.broadcast(Snarky.PubSub, "commands", {:command, cmd.action, message})
        :ok

      {:error, reason} ->
        Snarky.Speaker.say("Sorry, that didn't work")
        Logger.error("Execution failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp execute_legacy(%Command{action: action} = cmd)
       when action in [:set_volume, :volume_up, :volume_down, :pan] do
    Snarky.Executor.OSC.execute(cmd)
  end

  defp execute_legacy(%Command{} = cmd) do
    Snarky.Executor.AppleScript.execute(cmd)
  end
end
