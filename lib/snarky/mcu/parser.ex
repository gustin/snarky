defmodule Snarky.MCU.Parser do
  require Logger
  import Bitwise
  alias Snarky.MCU.Protocol, as: P

  def handle(%{data: data}) when is_list(data) do
    parse(data)
  end

  def handle(_), do: :ok

  defp parse([status, note, velocity]) when status >= 0x90 and status <= 0x9F do
    handle_note(note, velocity)
  end

  defp parse([status, cc, value]) when status >= 0xB0 and status <= 0xBF do
    handle_cc(cc, value)
  end

  defp parse([status, lsb, msb]) when status >= 0xE0 and status <= 0xEF do
    channel = status - 0xE0
    value = msb * 128 + lsb
    handle_fader(channel, value)
  end

  defp parse([status, value]) when status >= 0xD0 and status <= 0xDF do
    handle_meter(value)
  end

  defp parse([0xF0 | rest]) do
    handle_sysex(rest)
  end

  defp parse(_data), do: :ok

  defp handle_note(note, velocity) do
    on = velocity > 0

    cond do
      note in 0x00..0x07 ->
        track = note - 0x00 + 1

        cmd = %Snarky.CommandRouter.Command{
          action: if(on, do: :arm, else: :disarm),
          target: {:track, track}
        }

        Snarky.Session.track_command(cmd)
        Logger.debug("MCU: Track #{track} rec #{if on, do: "on", else: "off"}")

      note in 0x08..0x0F ->
        track = note - 0x08 + 1

        cmd = %Snarky.CommandRouter.Command{
          action: if(on, do: :solo, else: :unsolo),
          target: {:track, track}
        }

        Snarky.Session.track_command(cmd)
        Logger.debug("MCU: Track #{track} solo #{if on, do: "on", else: "off"}")

      note in 0x10..0x17 ->
        track = note - 0x10 + 1

        cmd = %Snarky.CommandRouter.Command{
          action: if(on, do: :mute, else: :unmute),
          target: {:track, track}
        }

        Snarky.Session.track_command(cmd)
        Logger.debug("MCU: Track #{track} mute #{if on, do: "on", else: "off"}")

      true ->
        :ok
    end
  end

  defp handle_fader(channel, value) when channel in 0..7 do
    track = channel + 1
    db = P.fader_to_db(value)

    cmd = %Snarky.CommandRouter.Command{
      action: :set_volume,
      target: {:track, track},
      params: %{db: round(db)}
    }

    Snarky.Session.track_command(cmd)
    Logger.debug("MCU: Track #{track} fader #{db} dB")
  end

  defp handle_fader(_channel, _value), do: :ok

  defp handle_cc(cc, value) when cc in 0x30..0x37 do
    channel = cc - 0x30 + 1
    pan_value = value &&& 0x0F
    Logger.debug("MCU: Track #{channel} vpot ring #{pan_value}")
  end

  defp handle_cc(cc, value) when cc in 0x40..0x49 do
    digit = cc - 0x40
    Logger.debug("MCU: Timecode digit #{digit} = #{value}")
  end

  defp handle_cc(_cc, _value), do: :ok

  defp handle_meter(value) do
    channel = Bitwise.bsr(value, 4) + 1
    level = value &&& 0x0F
    Logger.debug("MCU: Meter ch #{channel} level #{level}")
  end

  defp handle_sysex(data) do
    case data do
      [0x00, 0x00, 0x66, 0x14, 0x12, offset | chars] ->
        text =
          chars
          |> Enum.take_while(&(&1 != 0xF7))
          |> List.to_string()

        handle_lcd(offset, text)

      _ ->
        :ok
    end
  end

  defp handle_lcd(offset, text) do
    row = if offset < 56, do: 0, else: 1
    col = rem(offset, 56)
    Logger.debug("MCU: LCD row #{row} col #{col}: #{text}")
  end
end
