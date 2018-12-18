defmodule CredoCoreNode.Mixfile do
  use Mix.Project

  def project do
    [
      app: :credo_core_node,
      version: "0.1.5",
      elixir: "~> 1.4",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix, :gettext] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {CredoCoreNode.Application, []},
      extra_applications: [:logger, :runtime_tools, :edeliver, :mnesia]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.3.0"},
      {:phoenix_pubsub, "~> 1.0"},
      {:gettext, "~> 0.11"},
      {:cowboy, "~> 1.0"},
      {:phoenix_gen_socket_client, "~> 2.1.1"},
      {:websocket_client, "~> 1.2"},
      {:poison, "~> 3.1.0"},
      {:hackney, "~> 1.9"},
      {:libsecp256k1, git: "https://github.com/turinginc/libsecp256k1.git", tag: "0.1"},
      {:ex_rlp, "~> 0.3.0"},
      {:quantum, "~> 2.3"},
      {:timex, "~> 3.0"},
      {:merkle_patricia_tree, github: "aeternity/elixir-merkle-patricia-tree"},
      {:decimal, "~> 1.0"},
      {:phoenix_channel_client, github: "malroc/phoenix_channel_client"},
      {:edeliver, ">= 1.6.0"},
      {:distillery, "~> 2.0"}
    ]
  end
end
