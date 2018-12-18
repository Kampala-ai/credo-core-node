defmodule CredoCoreNode.Network.Connection do
  use Mnesia.Schema,
    table_name: :connections,
    fields: [
      :ip,
      :is_active,
      :is_outgoing,
      :failed_attempts_count,
      :socket_client_id,
      :session_id,
      :updated_at
    ]
end
