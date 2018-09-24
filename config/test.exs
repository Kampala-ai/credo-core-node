use Mix.Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :credo_core_node, CredoCoreNodeWeb.Endpoint,
  http: [port: 4001],
  server: false

config :credo_core_node, CredoCoreNode.Network,
  seed_node_ips: [],
  node_connection_port: 4001

# Print only warnings and errors during test
config :logger, level: :warn
