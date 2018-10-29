defmodule CredoCoreNode.Accounts.Account do #TODO: implement more secure private key storage.
  use Mnesia.Schema, table_name: :accounts, fields: [:address, :private_key, :public_key, :label]
end
