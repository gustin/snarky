defmodule Snarky.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Snarky.Speaker,
      Snarky.Session,
      Snarky.Executor.OSC,
      Snarky.Listener
    ]

    opts = [strategy: :one_for_one, name: Snarky.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
