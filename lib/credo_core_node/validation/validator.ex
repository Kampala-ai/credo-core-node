defmodule CredoCoreNode.Validation.Validator do
  use Mnesia.Schema, table_name: :validators, fields: [:ip, :address, :stake_amount, :participation_rate]
end
