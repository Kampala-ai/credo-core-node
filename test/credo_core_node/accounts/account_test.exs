defmodule CredoCoreNode.AccountTest do
  use CredoCoreNodeWeb.DataCase

  describe "table" do
    @describetag table_name: :accounts

    test "has expected fields" do
      assert CredoCoreNode.Accounts.Account.fields == [:address, :private_key, :public_key, :label]
    end

  end

end