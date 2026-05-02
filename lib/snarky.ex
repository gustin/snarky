defmodule Snarky do
  @moduledoc false

  def start do
    Snarky.Speaker.say("Snarky is listening")
    Snarky.Listener.start_listening()
  end

  def stop do
    Snarky.Listener.stop_listening()
    Snarky.Speaker.say("Snarky out")
  end
end
