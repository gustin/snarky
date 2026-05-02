defmodule Snarky.AskClaude do
  require Logger

  @system """
  You are a recording engineer working in the studio right now.
  Keep answers under 3 sentences. Be specific about frequencies,
  dB values, and knob positions. Answer will be spoken aloud so
  keep it conversational, no markdown.
  """

  @knowledge_path "priv/knowledge/studio.md"

  def ask(question) do
    Logger.info("Asking Claude: #{question}")

    session_context = Snarky.Session.describe()
    prompt = build_prompt(question, session_context)
    claude_bin = Application.get_env(:snarky, :claude_bin, "claude")

    task =
      Task.async(fn ->
        System.cmd("sh", ["-c", "#{claude_bin} -p #{escape(prompt)} < /dev/null"],
          stderr_to_stdout: true
        )
      end)

    case Task.await(task, 30_000) do
      {response, 0} ->
        answer = clean_response(response)
        Logger.info("Claude says: #{answer}")
        Snarky.Speaker.say(answer)
        {:ok, answer}

      {error, code} ->
        Logger.error("Claude failed (#{code}): #{error}")
        Snarky.Speaker.say("Sorry, I couldn't figure that out")
        {:error, error}
    end
  rescue
    e ->
      Logger.error("Claude timeout or error: #{inspect(e)}")
      Snarky.Speaker.say("Sorry, that took too long")
      {:error, :timeout}
  end

  defp build_prompt(question, session_context) do
    parts = [@system, studio_knowledge()]

    parts =
      if session_context != "" do
        parts ++ ["Current session state: #{session_context}"]
      else
        parts
      end

    parts = parts ++ ["Question: #{question}"]
    Enum.join(parts, "\n\n")
  end

  defp studio_knowledge do
    path = Application.app_dir(:snarky, @knowledge_path)

    case File.read(path) do
      {:ok, content} -> content
      {:error, _} -> ""
    end
  end

  defp clean_response(text) do
    text
    |> String.trim()
    |> String.replace(~r/^Warning:.*$/m, "")
    |> String.replace(~r/\*\*(.+?)\*\*/, "\\1")
    |> String.replace(~r/`(.+?)`/, "\\1")
    |> String.replace(~r/^#+\s+/m, "")
    |> String.replace(~r/^\s*[-*]\s+/m, "")
    |> String.replace(~r/\n+/, " ")
    |> String.trim()
  end

  defp escape(str) do
    "'" <> String.replace(str, "'", "'\\''") <> "'"
  end
end
