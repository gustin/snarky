defmodule Snarky.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Phoenix.PubSub, name: Snarky.PubSub},
      {Nx.Serving,
       serving: Snarky.Transcriber.serving(), name: Snarky.STT, batch_size: 1, batch_timeout: 100},
      Snarky.VAD,
      Snarky.Speaker,
      Snarky.Session,
      Snarky.MCU,
      Snarky.Executor.OSC,
      Snarky.Listener,
      SnarkyWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Snarky.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
