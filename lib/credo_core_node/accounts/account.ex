# TODO: implement more secure private key storage.
defmodule CredoCoreNode.Accounts.Account do
  use Mnesia.Schema, table_name: :accounts, fields: [:address, :private_key, :public_key, :label]
end
