defmodule SnarkyWeb do
  def static_paths, do: ~w(assets images favicon.ico robots.txt)

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: SnarkyWeb.Endpoint,
        router: SnarkyWeb.Router,
        statics: SnarkyWeb.static_paths()
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView, layout: {SnarkyWeb.Layouts, :app}
      unquote(verified_routes())
    end
  end

  def html do
    quote do
      use Phoenix.Component
      import Phoenix.HTML
      unquote(verified_routes())
    end
  end

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
