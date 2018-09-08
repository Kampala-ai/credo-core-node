defmodule CredoCoreNode.Network.KnownNode do
  use Mnesia.Schema, table_name: :known_nodes, fields: [:url, :last_active_at]
end
