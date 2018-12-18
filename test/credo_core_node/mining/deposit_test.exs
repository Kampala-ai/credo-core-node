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

    def deposit_fixture(amount, account \\ nil, timelock \\ nil) do
      account = account || elem(Accounts.generate_address("miner"), 1)
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

  describe "processing a miner deposit" do
    @describetag table_name: :miners

    def miner_fixture(account) do
      Mining.write_miner(%{
        address: account.address,
        ip: "1.1.1.1",
        stake_amount: D.new(1_000),
        participation_rate: 1.0,
        inserted_at: DateTime.utc_now(),
        is_self: false
      })
      |> elem(1)
    end

    test "saves the deposit" do
      deposit = deposit_fixture(D.new(50_000))

      Deposit.recognize_deposits([deposit])

      refute is_nil(Mining.get_deposit(deposit.hash))
    end

    test "creates a miner if it doesn't exist" do
      account = elem(Accounts.generate_address("miner"), 1)
      deposit = deposit_fixture(D.new(50_000), account)

      Deposit.recognize_deposits([deposit])

      refute is_nil(Mining.get_miner(account.address))
    end

    test "updates a miner if it already exists" do
      account = elem(Accounts.generate_address("miner"), 1)
      miner = miner_fixture(account)

      deposit = deposit_fixture(D.new(100_000), account)

      Deposit.recognize_deposits([deposit])

      assert D.cmp(Mining.get_miner(miner.address).stake_amount, D.add(miner.stake_amount, deposit.value)) == :eq
    end
  end
end
