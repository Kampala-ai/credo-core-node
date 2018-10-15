defmodule CredoCoreNode.Validation.Validator do
  use Mnesia.Schema, table_name: :validators, fields: [:address, :ip, :stake_amount, :participation_rate, :is_self]
end
