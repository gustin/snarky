defmodule Snarky.Transcriber do
  require Logger

  @serving_name Snarky.STT

  def serving(opts \\ []) do
    model_id =
      opts[:model] || Application.get_env(:snarky, :stt_model, "distil-whisper/distil-large-v3")

    Logger.info("Loading STT model: #{model_id}")

    {:ok, whisper} = Bumblebee.load_model({:hf, model_id})
    {:ok, featurizer} = Bumblebee.load_featurizer({:hf, model_id})
    {:ok, tokenizer} = Bumblebee.load_tokenizer({:hf, model_id})
    {:ok, generation_config} = Bumblebee.load_generation_config({:hf, model_id})

    Bumblebee.Audio.speech_to_text_whisper(
      whisper,
      featurizer,
      tokenizer,
      generation_config,
      defn_options: [compiler: EXLA],
      chunk_num_seconds: 30,
      task: :transcribe,
      language: "en"
    )
  end

  def transcribe(audio_path) do
    unless File.exists?(audio_path) do
      {:error, "audio file not found: #{audio_path}"}
    else
      audio = load_audio(audio_path)

      case Nx.Serving.batched_run(@serving_name, audio) do
        %{chunks: chunks} ->
          text =
            chunks
            |> Enum.map(& &1.text)
            |> Enum.join(" ")
            |> String.trim()

          File.rm(audio_path)
          {:ok, text}

        other ->
          Logger.warning("Unexpected STT result: #{inspect(other)}")
          {:error, :unexpected_result}
      end
    end
  rescue
    e ->
      Logger.error("Transcription error: #{Exception.message(e)}")
      {:error, Exception.message(e)}
  end

  def transcribe_audio(audio_tensor) do
    case Nx.Serving.batched_run(@serving_name, audio_tensor) do
      %{chunks: chunks} ->
        text =
          chunks
          |> Enum.map(& &1.text)
          |> Enum.join(" ")
          |> String.trim()

        {:ok, text}

      _ ->
        {:error, :unexpected_result}
    end
  end

  defp load_audio(path) do
    {raw, 0} =
      System.cmd("ffmpeg", [
        "-i",
        path,
        "-f",
        "f32le",
        "-ar",
        "16000",
        "-ac",
        "1",
        "-v",
        "quiet",
        "pipe:1"
      ])

    raw
    |> Nx.from_binary(:f32)
    |> Nx.reshape({:auto})
  end
end
