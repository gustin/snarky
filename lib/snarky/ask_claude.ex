defmodule Snarky.AskClaude do
  require Logger

  @context """
  You are a recording engineer assistant. Keep answers under 3 sentences
  and practical. The setup: Tascam Model 12 mixer/interface, Benson tube
  amp, Behringer mic, Logic Pro. Answer will be spoken aloud so keep it
  conversational.
  """

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
    parts = [@context]

    parts =
      if session_context != "" do
        parts ++ ["Current session state: #{session_context}"]
      else
        parts
      end

    parts = parts ++ ["Question: #{question}"]
    Enum.join(parts, "\n\n")
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
