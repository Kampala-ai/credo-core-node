defmodule CredoCoreNode.IpTest do
  use CredoCoreNodeWeb.DataCase

  alias CredoCoreNode.{Accounts, Mining}
  alias CredoCoreNode.Mining.Deposit

  alias Decimal, as: D

  describe "constructing a miner deposit" do
    @describetag table_name: :pending_transactions

    test "creates a valid deposit transaction" do
      {:ok, account} = Accounts.generate_address("miner")
      amount = D.new(1_000)

      tx = Deposit.construct_deposit(amount, account.private_key, account.address)

      assert Deposit.is_deposit(tx)
    end
  end
end