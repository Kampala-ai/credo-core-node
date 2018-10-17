# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# Configures the endpoint
config :credo_core_node, CredoCoreNodeWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "94sm7rW9uoXg2HxBXYPdy08FUCm9Jsmw6Tcp0dBy/+aK3XG5Rxf9ONGAUEVLQE7B",
  render_errors: [view: CredoCoreNodeWeb.ErrorView, accepts: ~w(json)],
  pubsub: [name: CredoCoreNode.PubSub, adapter: Phoenix.PubSub.PG2]

config :credo_core_node, Mnesia, table_suffix: System.get_env("MNESIA_TABLE_SUFFIX") || Mix.env()

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :credo_core_node, CredoCoreNode.Scheduler,
  global: true,
  overlap: false,
  timezone: :utc,
  jobs: [
    {"*/15 * * * *", {CredoCoreNode.Validation, :maybe_update_validator_ip, []}} # Periodically check for an ip change on a running node.
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
