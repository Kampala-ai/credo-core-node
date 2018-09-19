defmodule CredoCoreNode.Network.KnownNode do
  use Mnesia.Schema, table_name: :known_nodes, fields: [:ip, :is_seed]
end
