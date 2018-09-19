defmodule CredoCoreNode.Network.Connection do
  use Mnesia.Schema, table_name: :connections, fields: [:ip, :is_active, :failed_attempts_count]
end
