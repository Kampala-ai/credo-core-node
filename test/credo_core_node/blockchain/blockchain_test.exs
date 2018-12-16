defmodule CredoCoreNode.BlockchainTest do
  use CredoCoreNodeWeb.DataCase

  alias CredoCoreNode.{Blockchain, Pool}

  alias Decimal, as: D

  describe "blocks" do
    @describetag table_name: :blocks
    @private_key :crypto.strong_rand_bytes(32)
    @attrs [nonce: 0, to: "ABC", value: D.new(1), fee: D.new(1), data: ""]

    def block_fixture(private_key \\ @private_key, attrs \\ @attrs) do
      {:ok, pending_transaction} =
        private_key
        |> Pool.generate_pending_transaction(attrs)
        |> elem(1)
        |> Pool.write_pending_transaction()

      {:ok, block} =
        [pending_transaction]
        |> Pool.generate_pending_block()
        |> elem(1)
        |> Blockchain.write_block()

      block
    end

    test "list_blocks/0 returns all blocks" do
      block = block_fixture()
      assert Enum.member?(Blockchain.list_blocks(), %{block | body: nil})
    end

    test "get_block!/1 returns the block with given hash" do
      block = block_fixture()
      assert Blockchain.get_block(block.hash) == %{block | body: nil}
    end

    test "writes_block/1 with valid data creates a block" do
      Blockchain.load_genesis_block()

      block = block_fixture()

      assert block.number == 1
    end

    test "delete_block/1 deletes the block" do
      block = block_fixture()
      assert {:ok, block} = Blockchain.delete_block(block)
      assert Blockchain.get_block(block.hash) == nil
    end
  end

  describe "transactions" do
    @describetag table_name: :transactions
    @private_key :crypto.strong_rand_bytes(32)
    @attrs [nonce: 0, to: "ABC", value: D.new(1), fee: D.new(1), data: ""]

    def transaction_fixture(private_key \\ @private_key, attrs \\ @attrs) do
      {:ok, transaction} =
        private_key
        |> Pool.generate_pending_transaction(attrs)
        |> elem(1)
        |> Blockchain.write_transaction()

      transaction
    end

    test "list_transactions/0 returns all transactions" do
      transaction = transaction_fixture()
      assert Enum.member?(Blockchain.list_transactions(), transaction)
    end

    test "get_transaction!/1 returns the transaction with given hash" do
      transaction = transaction_fixture()
      assert Blockchain.get_transaction(transaction.hash) == transaction
    end

    test "write_transaction/1 with valid data creates a transaction" do
      assert {:ok, transaction} =
               @private_key
               |> Pool.generate_pending_transaction(@attrs)
               |> elem(1)
               |> Blockchain.write_transaction()

      assert transaction.nonce == @attrs[:nonce]
      assert transaction.to == @attrs[:to]
      assert transaction.value == @attrs[:value]
      assert transaction.fee == @attrs[:fee]
      assert transaction.data == @attrs[:data]
    end

    test "delete_transaction/1 deletes the transaction" do
      transaction = transaction_fixture()
      assert {:ok, transaction} = Blockchain.delete_transaction(transaction)
      assert Blockchain.get_transaction(transaction.hash) == nil
    end
  end
end
