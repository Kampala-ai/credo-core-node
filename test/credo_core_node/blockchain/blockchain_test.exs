defmodule CredoCoreNode.BlockchainTest do
  use CredoCoreNodeWeb.DataCase

  alias CredoCoreNode.{Blockchain, Pool}
  alias CredoCoreNode.Mining.{Coinbase, Deposit, Ip, Slash}

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

    test "list_preceding_blocks/0 returns all blocks before the current one" do
      Blockchain.load_genesis_block()
      block = block_fixture()
      preceding_blocks = Blockchain.list_preceding_blocks(block)
      assert length(preceding_blocks) == block.number
      assert hd(preceding_blocks).number == block.number - 1
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

  describe "loading the genesis block" do
    @describetag table_name: :blocks

    test "load_genesis_block/0 returns the genesis block" do
      block = Blockchain.load_genesis_block()

      assert block.number == 0
      assert block.hash == "51D9D50254B866AEE7060B51B611B2C19FB280641FB5CDB11D4669AA14BB1A07"
    end
  end

  describe "transaction types" do
    @describetag table_name: :pending_transactions
    @private_key :crypto.strong_rand_bytes(32)
    @attrs [nonce: 0, to: "ABC", value: D.new(1), fee: D.new(1)]

    def pending_transaction_fixture(private_key, attrs, data) do
      private_key
      |> Pool.generate_pending_transaction(attrs ++ [data: data])
      |> elem(1)
    end

    test "constant getters return expected type" do
      assert Blockchain.coinbase_tx_type() == "coinbase"
      assert Blockchain.security_deposit_tx_type() == "security_deposit"
      assert Blockchain.slash_tx_type() == "slash"
      assert Blockchain.update_miner_ip_tx_type() == "update_miner_ip"
    end

    test "detecting coinbase transaction type" do
      pending_transaction =
        pending_transaction_fixture(
          @private_key,
          @attrs,
          "{\"tx_type\" : \"#{Blockchain.coinbase_tx_type()}\"}"
        )

      assert Coinbase.is_coinbase_tx(pending_transaction)
    end

    test "detecting deposit transaction type" do
      pending_transaction =
        pending_transaction_fixture(
          @private_key,
          @attrs,
          "{\"tx_type\" : \"#{Blockchain.security_deposit_tx_type()}\"}"
        )

      assert Deposit.is_deposit(pending_transaction)
    end

    test "detecting ip transaction type" do
      pending_transaction =
        pending_transaction_fixture(
          @private_key,
          @attrs,
          "{\"tx_type\" : \"#{Blockchain.update_miner_ip_tx_type()}\"}"
        )

      assert Ip.is_miner_ip_update(pending_transaction)
    end

    test "detecting slash transaction type" do
      pending_transaction =
        pending_transaction_fixture(
          @private_key,
          @attrs,
          "{\"tx_type\" : \"#{Blockchain.slash_tx_type()}\"}"
        )

      assert Slash.is_slash(pending_transaction)
    end
  end

  describe "summing transaction values" do
    @describetag table_name: :transactions

    test "correctly sums up transaction values for a block" do
      block = Blockchain.load_genesis_block()

      assert D.cmp(Blockchain.sum_transaction_values(block), D.new(1_374_729_257.2286)) == :eq
    end

    test "correctly sums up transaction values for a list of transactions" do
      transactions =
        Blockchain.load_genesis_block()
        |> Blockchain.list_transactions()

      assert D.cmp(Blockchain.sum_transaction_values(transactions), D.new(1_374_729_257.2286)) ==
               :eq
    end
  end
end
