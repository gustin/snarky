defmodule SnarkyWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :snarky

  @session_options [
    store: :cookie,
    key: "_snarky_key",
    signing_salt: "snarky_studio",
    same_site: "Lax"
  ]

  socket("/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session_options]])

  plug(Plug.Static,
    at: "/",
    from: :snarky,
    gzip: false,
    only: SnarkyWeb.static_paths()
  )

  plug(Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()
  )

  plug(Plug.Session, @session_options)
  plug(SnarkyWeb.Router)
end
