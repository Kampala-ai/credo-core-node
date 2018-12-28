defmodule CredoCoreNode.DepositWithdrawalTest do
  use CredoCoreNodeWeb.DataCase

  alias CredoCoreNode.Accounts
  alias CredoCoreNode.Blockchain.Block
  alias CredoCoreNode.Mining.{Deposit, DepositWithdrawal}

  alias Decimal, as: D

  describe "detecting deposit withdrawals" do
    @describetag table_name: :miners

    def deposit_fixture(account) do
      amount = D.new(15_000)

      Deposit.construct_deposit(amount, account.private_key, account.address)
    end

    test "successfully detects a deposit withdrawal" do
      {:ok, account} = Accounts.generate_address("miner")
      deposit = deposit_fixture(account)

      Deposit.recognize_deposits([deposit])

      attrs = %{
        nonce: 0,
        to: "AF24738B406DB6387D05EB7CE1E90D420B25798F",
        value: Decimal.new(10.0),
        fee: 1.1,
        data: ""
      }

      {:ok, tx} = CredoCoreNode.Pool.generate_pending_transaction(account.private_key, attrs)

      DepositWithdrawal.is_deposit_withdrawal?(tx)
    end
  end

  describe "validating deposit withdrawals" do
    @describetag table_name: :miners

    test "invalidates a deposit withdrawal from an address with an insufficient balance" do
      {:ok, account} = Accounts.generate_address("miner")
      deposit = deposit_fixture(account)

      Deposit.recognize_deposits([deposit])

      attrs = %{
        nonce: 0,
        to: "AF24738B406DB6387D05EB7CE1E90D420B25798F",
        value: Decimal.new(10.0),
        fee: 1.1,
        data: ""
      }

      {:ok, tx} = CredoCoreNode.Pool.generate_pending_transaction(account.private_key, attrs)

      assert DepositWithdrawal.valid_deposit_withdrawal?(tx, %Block{number: 10})
    end
  end
end
