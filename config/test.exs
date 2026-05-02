import Config

config :snarky, SnarkyWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4099],
  server: false
