defmodule CredoCoreNode.Mining.Miner do
  use Mnesia.Schema,
    table_name: :miners,
    fields: [:address, :ip, :stake_amount, :participation_rate, :timelock, :is_self]
end
