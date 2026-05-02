defmodule Snarky.Transcriber do
  require Logger

  def transcribe(audio_path) do
    whisper_bin =
      Application.get_env(:snarky, :whisper_bin, "/opt/homebrew/opt/whisper-cpp/bin/whisper-cli")

    model_path = Application.get_env(:snarky, :whisper_model)

    unless File.exists?(audio_path) do
      {:error, "audio file not found: #{audio_path}"}
    else
      args = [
        "-m",
        model_path,
        "-f",
        audio_path,
        "--no-timestamps",
        "-t",
        "4",
        "-l",
        "en"
      ]

      case System.cmd(whisper_bin, args, stderr_to_stdout: true) do
        {output, 0} ->
          text = parse_whisper_output(output)
          cleanup(audio_path)
          {:ok, text}

        {output, code} ->
          Logger.warning("whisper-cli exited #{code}")
          {:error, output}
      end
    end
  end

  defp parse_whisper_output(output) do
    output
    |> String.split("\n")
    |> Enum.reject(&String.starts_with?(&1, "whisper_"))
    |> Enum.reject(&String.starts_with?(&1, "main:"))
    |> Enum.reject(&(&1 == ""))
    |> Enum.reject(&String.contains?(&1, "[BLANK_AUDIO]"))
    |> Enum.map(&String.trim/1)
    |> Enum.map(fn line ->
      Regex.replace(~r/\[[\d:.]+\s*-->\s*[\d:.]+\]\s*/, line, "")
    end)
    |> Enum.join(" ")
    |> String.trim()
  end

  defp cleanup(path) do
    File.rm(path)
  end
end
