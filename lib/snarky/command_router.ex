defmodule Snarky.CommandRouter do
  require Logger

  defmodule Command do
    defstruct [:action, :target, :params]
  end

  @question_starters ~w(why how what where when which does is are can could should would)

  def route(text) do
    normalized = normalize(text)
    Logger.debug("Routing: #{normalized}")

    case parse(normalized) do
      {:command, %Command{} = cmd} ->
        Logger.info("Command: #{inspect(cmd)}")
        Snarky.Executor.execute(cmd)

      {:question, question} ->
        Logger.info("Question: #{question}")
        Snarky.AskClaude.ask(question)

      :ignored ->
        Logger.debug("Ignored: #{normalized}")
        :ok
    end
  end

  def parse(text) do
    words = String.split(text)

    cond do
      is_question?(words) -> {:question, text}
      match = parse_transport(words) -> {:command, match}
      match = parse_loop(text) -> {:command, match}
      match = parse_tempo(text) -> {:command, match}
      match = parse_mix_command(words) -> {:command, match}
      match = parse_effect(text) -> {:command, match}
      match = parse_session(words) -> {:command, match}
      true -> :ignored
    end
  end

  defp is_question?(words) do
    first = List.first(words, "") |> String.downcase()
    first in @question_starters or String.ends_with?(List.last(words, ""), "?")
  end

  defp parse_transport(words) do
    first = List.first(words, "") |> String.downcase()
    rest = Enum.drop(words, 1)

    action = find_transport_action(first)

    if action do
      target = parse_target(rest)
      %Command{action: action, target: target}
    end
  end

  defp find_transport_action(word) do
    mapping = %{
      "record" => :record,
      "recording" => :record,
      "rec" => :record,
      "stop" => :stop,
      "play" => :play,
      "playback" => :play,
      "pause" => :pause,
      "rewind" => :rewind,
      "undo" => :undo,
      "redo" => :redo
    }

    Map.get(mapping, apply_corrections(word))
  end

  defp parse_loop(text) do
    cond do
      match =
          Regex.run(~r/loop\s+(?:from\s+)?(?:bar\s+)?(\d+)\s+(?:to\s+)?(?:bar\s+)?(\d+)/i, text) ->
        [_, from, to] = match

        %Command{
          action: :loop,
          params: %{from: String.to_integer(from), to: String.to_integer(to)}
        }

      String.contains?(text, "loop") ->
        %Command{action: :loop}

      true ->
        nil
    end
  end

  defp parse_tempo(text) do
    case Regex.run(~r/(?:set\s+)?tempo\s+(?:to\s+)?(\d+)/i, text) do
      [_, bpm] -> %Command{action: :set_tempo, params: %{bpm: String.to_integer(bpm)}}
      _ -> nil
    end
  end

  defp parse_mix_command(words) do
    first = List.first(words, "") |> String.downcase() |> apply_corrections()
    rest = Enum.drop(words, 1)

    case first do
      action when action in ~w(mute unmute) ->
        target = parse_target(rest)
        %Command{action: String.to_atom(action), target: target}

      "solo" ->
        target = parse_target(rest)
        %Command{action: :solo, target: target}

      "unsolo" ->
        target = parse_target(rest)
        %Command{action: :unsolo, target: target}

      "arm" ->
        target = parse_target(rest)
        %Command{action: :arm, target: target}

      "disarm" ->
        target = parse_target(rest)
        %Command{action: :disarm, target: target}

      "volume" ->
        parse_volume_command(rest)

      "set" ->
        parse_set_command(rest)

      "pan" ->
        target = parse_target(rest)
        direction = parse_pan_direction(rest)
        %Command{action: :pan, target: target, params: %{direction: direction}}

      _ ->
        nil
    end
  end

  defp parse_volume_command(words) do
    text = Enum.join(words, " ")

    cond do
      String.contains?(text, "up") ->
        target = parse_target(words)
        %Command{action: :volume_up, target: target}

      String.contains?(text, "down") ->
        target = parse_target(words)
        %Command{action: :volume_down, target: target}

      match = Regex.run(~r/(-?\d+)/, text) ->
        [_, db] = match
        target = parse_target(words)
        %Command{action: :set_volume, target: target, params: %{db: String.to_integer(db)}}

      true ->
        nil
    end
  end

  defp parse_set_command(words) do
    text = Enum.join(words, " ") |> String.downcase()

    cond do
      match = Regex.run(~r/volume\s+.*?(-?\d+)/i, text) ->
        [_, db] = match
        target = parse_target(words)
        %Command{action: :set_volume, target: target, params: %{db: String.to_integer(db)}}

      match = Regex.run(~r/pan\s+.*?(left|right|center)/i, text) ->
        [_, direction] = match
        target = parse_target(words)
        %Command{action: :pan, target: target, params: %{direction: String.to_atom(direction)}}

      true ->
        nil
    end
  end

  defp parse_effect(text) do
    cond do
      match = Regex.run(~r/(?:add|put)\s+(?:a\s+|some\s+)?(.+?)\s+(?:to|on)\s+(.+)/i, text) ->
        [_, effect, target_text] = match
        target = parse_target(String.split(target_text))
        %Command{action: :add_effect, target: target, params: %{effect: normalize_effect(effect)}}

      match =
          Regex.run(
            ~r/(?:remove|take off|delete)\s+(?:the\s+)?(.+?)\s+(?:from|off|on)\s+(.+)/i,
            text
          ) ->
        [_, effect, target_text] = match
        target = parse_target(String.split(target_text))

        %Command{
          action: :remove_effect,
          target: target,
          params: %{effect: normalize_effect(effect)}
        }

      true ->
        nil
    end
  end

  defp parse_session(words) do
    first = List.first(words, "") |> String.downcase()

    case first do
      "save" -> %Command{action: :save}
      "bounce" -> %Command{action: :bounce, target: parse_target(Enum.drop(words, 1))}
      "export" -> %Command{action: :export}
      _ -> nil
    end
  end

  defp parse_target(words) do
    text = words |> Enum.join(" ") |> String.downcase()
    aliases = Application.get_env(:snarky, :track_aliases, %{})

    cond do
      text =~ ~r/\ball\b/ ->
        :all

      text =~ ~r/everything/ ->
        :all

      match = Regex.run(~r/track\s+(\d+)/, text) ->
        [_, num] = match
        {:track, String.to_integer(num)}

      match = Regex.run(~r/tracks?\s+(\d+)\s+(?:and|through|to)\s+(\d+)/, text) ->
        [_, from, to] = match
        {:tracks, String.to_integer(from), String.to_integer(to)}

      true ->
        find_alias(text, aliases)
    end
  end

  defp find_alias(text, aliases) do
    found =
      Enum.find(aliases, fn {name, _track} ->
        String.contains?(text, String.downcase(name))
      end)

    case found do
      {_name, track_num} -> {:track, track_num}
      nil -> nil
    end
  end

  defp parse_pan_direction(words) do
    text = Enum.join(words, " ") |> String.downcase()

    cond do
      text =~ ~r/left/ -> :left
      text =~ ~r/right/ -> :right
      text =~ ~r/center|centre|middle/ -> :center
      true -> :center
    end
  end

  defp normalize_effect(effect) do
    mapping = %{
      "reverb" => :reverb,
      "plate reverb" => :plate_reverb,
      "hall reverb" => :hall_reverb,
      "room reverb" => :room_reverb,
      "delay" => :delay,
      "tape delay" => :tape_delay,
      "echo" => :delay,
      "compressor" => :compressor,
      "compression" => :compressor,
      "comp" => :compressor,
      "eq" => :eq,
      "equalizer" => :eq,
      "chorus" => :chorus,
      "distortion" => :distortion,
      "overdrive" => :overdrive,
      "limiter" => :limiter,
      "gate" => :gate,
      "noise gate" => :gate,
      "phaser" => :phaser,
      "flanger" => :flanger,
      "tremolo" => :tremolo
    }

    key = String.downcase(String.trim(effect))
    Map.get(mapping, key, String.to_atom(String.replace(key, " ", "_")))
  end

  defp normalize(text) do
    text
    |> String.trim()
    |> String.replace(~r/\s+/, " ")
    |> String.downcase()
  end

  @corrections %{
    "wreck cord" => "record",
    "wreckord" => "record",
    "wrecked" => "record",
    "plate" => "play",
    "mewed" => "mute",
    "mewing" => "mute",
    "saw low" => "solo",
    "you know" => "undo",
    "on do" => "undo"
  }

  defp apply_corrections(word) do
    Map.get(@corrections, word, word)
  end
end
