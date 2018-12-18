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

  describe "validating a miner deposit" do
    @describetag table_name: :miners

    def deposit_fixture(amount, timelock \\ nil) do
      {:ok, account} = Accounts.generate_address("miner")
      tx = Deposit.construct_deposit(amount, account.private_key, account.address, timelock)
    end

    test "validates a deposit above the minimum" do
      deposit = deposit_fixture(D.new(50_000))

      assert Deposit.validate_deposits([deposit]) == [deposit]
    end

    test "invalidates an overly small deposit" do
      deposit = deposit_fixture(D.new(5))

      assert Deposit.validate_deposits([deposit]) == []
    end
  end
end
