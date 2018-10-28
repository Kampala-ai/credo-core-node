defmodule CredoCoreNode.Accounts.Address do #TODO: implement more secure private key storage.
  use Mnesia.Schema, table_name: :addresses, fields: [:address, :private_key, :public_key, :label]
end
