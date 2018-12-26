defmodule CredoCoreNode.CoinbaseTest do
  use CredoCoreNodeWeb.DataCase

  alias CredoCoreNode.Pool
  alias CredoCoreNode.Mining.Coinbase

  alias Decimal, as: D

  describe "adding a coinbase traansaction" do
    @describetag table_name: :pending_transactions
    @private_key :crypto.strong_rand_bytes(32)
    @attrs [nonce: 0, to: "ABC", value: D.new(1), fee: D.new(1), data: ""]

    def pending_transactions_fixture(private_key \\ @private_key, attrs \\ @attrs) do
      {:ok, pending_transaction} =
        private_key
        |> Pool.generate_pending_transaction(attrs)
        |> elem(1)
        |> Pool.write_pending_transaction()

      [pending_transaction]
    end

    def pending_block_fixture(pending_transactions) do
      {:ok, pending_block} =
        pending_transactions
        |> Pool.generate_pending_block()
        |> elem(1)
        |> Pool.write_pending_block()

      pending_block
    end

    test "adds a valid coinbase transaction" do
      pending_txs = pending_transactions_fixture()
      txs = Coinbase.add_coinbase_tx(pending_txs)
      block = pending_block_fixture(txs)

      [coinbase_tx] = tl(txs)

      assert Coinbase.is_coinbase_tx(coinbase_tx)
      assert Coinbase.tx_fee_sums_match(block, [coinbase_tx])
    end
  end

  describe "retrieving a coinbase transaction from a pending block" do
    @describetag table_name: :pending_transactions

    test "retrieves a coinbase transaction from a pending block that contains a coinbase transaction" do
      pending_txs = pending_transactions_fixture()
      txs = Coinbase.add_coinbase_tx(pending_txs)
      block = pending_block_fixture(txs)

      [coinbase_tx] = tl(txs)

      assert List.first(Coinbase.get_coinbase_txs(block)).hash == coinbase_tx.hash
    end

    test "retrieves an empty list from a pending block that doesn't contain a coinbase transaction" do
      block =
        pending_transactions_fixture()
        |> pending_block_fixture()

      assert Coinbase.get_coinbase_txs(block) == []
    end

  end

  describe "checking if a transaction is a coinbase transaction" do
    @describetag table_name: :pending_transactions

    test "determines that a regular transaction is not a coinbase transaction" do
      [pending_tx] = pending_transactions_fixture()

      refute Coinbase.is_coinbase_tx(pending_tx)
    end

    test "determines that a coinbase transaction is a coinbase transaction" do
      [coinbase_tx] =
        pending_transactions_fixture()
        |> Coinbase.add_coinbase_tx()
        |> tl()

      assert Coinbase.is_coinbase_tx(coinbase_tx)
    end
  end
end