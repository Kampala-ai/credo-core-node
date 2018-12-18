defmodule CredoCoreNode.PoolTest do
  use CredoCoreNodeWeb.DataCase

  alias CredoCoreNode.{Blockchain, Pool}

  alias Decimal, as: D

  describe "pending_blocks" do
    @describetag table_name: :pending_blocks
    @private_key :crypto.strong_rand_bytes(32)
    @attrs [nonce: 0, to: "ABC", value: D.new(1), fee: D.new(1), data: ""]

    def pending_block_fixture(private_key \\ @private_key, attrs \\ @attrs) do
      {:ok, pending_transaction} =
        private_key
        |> Pool.generate_pending_transaction(attrs)
        |> elem(1)
        |> Pool.write_pending_transaction()

      {:ok, pending_block} =
        [pending_transaction]
        |> Pool.generate_pending_block()
        |> elem(1)
        |> Pool.write_pending_block()

      pending_block
    end

    test "list_pending_blocks/0 returns all pending_blocks" do
      pending_block = pending_block_fixture()
      assert Enum.member?(Pool.list_pending_blocks(), pending_block)
    end

    test "get_pending_block!/1 returns the pending_block with given hash" do
      pending_block = pending_block_fixture()
      assert Pool.get_pending_block(pending_block.hash) == pending_block
    end

    test "writes_pending_block/1 with valid data creates a pending_block" do
      Blockchain.load_genesis_block()

      pending_block = pending_block_fixture()

      assert pending_block.number == 1
    end

    test "delete_pending_block/1 deletes the pending_block" do
      pending_block = pending_block_fixture()
      assert {:ok, pending_block} = Pool.delete_pending_block(pending_block)
      assert Pool.get_pending_block(pending_block.hash) == nil
    end
  end

  describe "pending_transactions" do
    @describetag table_name: :pending_transactions
    @private_key :crypto.strong_rand_bytes(32)
    @attrs [nonce: 0, to: "ABC", value: D.new(1), fee: D.new(1), data: ""]

    def pending_transaction_fixture(private_key \\ @private_key, attrs \\ @attrs) do
      {:ok, pending_transaction} =
        private_key
        |> Pool.generate_pending_transaction(attrs)
        |> elem(1)
        |> Pool.write_pending_transaction()

      pending_transaction
    end

    test "list_pending_transactions/0 returns all pending_transactions" do
      pending_transaction = pending_transaction_fixture()
      assert Enum.member?(Pool.list_pending_transactions(), pending_transaction)
    end

    test "get_pending_transaction!/1 returns the pending_transaction with given hash" do
      pending_transaction = pending_transaction_fixture()
      assert Pool.get_pending_transaction(pending_transaction.hash) == pending_transaction
    end

    test "write_pending_transaction/1 with valid data creates a pending_transaction" do
      assert {:ok, pending_transaction} =
               @private_key
               |> Pool.generate_pending_transaction(@attrs)
               |> elem(1)
               |> Pool.write_pending_transaction()

      assert pending_transaction.nonce == @attrs[:nonce]
      assert pending_transaction.to == @attrs[:to]
      assert pending_transaction.value == @attrs[:value]
      assert pending_transaction.fee == @attrs[:fee]
      assert pending_transaction.data == @attrs[:data]
    end

    test "delete_pending_transaction/1 deletes the pending_transaction" do
      pending_transaction = pending_transaction_fixture()
      assert {:ok, pending_transaction} = Pool.delete_pending_transaction(pending_transaction)
      assert Pool.get_pending_transaction(pending_transaction.hash) == nil
    end
  end

  describe "validating that a transaction is unmined" do
    @describetag table_name: :pending_transactions

    test "is_tx_unmined?/1 returns false for a mined transaction" do
      tx =
        struct(
          CredoCoreNode.Pool.PendingTransaction,
          data:
            "{\"tx_type\" : \"security_deposit\", \"node_ip\" : \"10.0.1.9\", \"timelock\": \"\"}",
          fee: D.new(1.0),
          hash: "A588D170F64FC3ADAF805670DA67C152FA906B8BB855AAA9B2041ED8E2747FF1",
          nonce: 0,
          r: "389576343235F0311A7FA5DD8BCE9C6E529698B66AB146427403C4B6863DC801",
          s: "46A623CC9B3FAFB41F35A698EE4C7ED73C76FA01D8E12209A76046C0B120D0E9",
          to: "A9A2B9A1EBDDE9EEB5EF733E47FC137D7EB95340",
          v: 0,
          value: D.new(10000.0)
        )

      refute Pool.is_tx_unmined?(tx)
    end

    test "is_tx_unmined?/1 returns true for a mined transaction" do
      tx =
        struct(
          CredoCoreNode.Pool.PendingTransaction,
          data: "",
          fee: Decimal.new(1.1),
          hash: "E0137BE996B287A9DD541E4DD5C5FC6270D65738D837F20CC33F199353E973FA",
          nonce: 0,
          r: "8E2BFD6A070E324C161CFB112B1AE657B84A9C67788AA3BBCD1121EE9B64CE3E",
          s: "02DB5FB3A4582633C4EB0191FD1F1420EC388D460B3C37B6DB35C455ADC1FC63",
          to: "A7A5DF6D79203F6E6F0FA9CD550366FC9067A350",
          v: 0,
          value: Decimal.new(500)
        )

      assert Pool.is_tx_unmined?(tx)
    end
  end

  describe "validating that a transaction has a sufficient balance" do
    @describetag table_name: :pending_transactions

    test "is_tx_from_balance_sufficient?/1 returns true for a transaction from an account with enough credos" do
      tx =
        struct(
          CredoCoreNode.Pool.PendingTransaction,
          data: "",
          fee: Decimal.new(1.100000000000000000),
          hash: "34F97321DDC0E56E67CC0AECE02053E64393390730AFDB6F63FB546CB7FA9B46",
          nonce: 0,
          r: "8DBF9628AB59AB7E28418B3D58EE696B744624041BF955075FDD3A2653173905",
          s: "7A4A73877604F44BC673D46CEF6E267283215FCF6CE7AF82C18BFEEBD8053468",
          to: "AF24738B406DB6387D05EB7CE1E90D420B25798F",
          v: 0,
          value: Decimal.new(1000000)
        )

      assert Pool.is_tx_from_balance_sufficient?(tx)
    end

    test "is_tx_from_balance_sufficient?/1 returns false for a transaction from an account without enough credos" do
      tx =
        struct(
          CredoCoreNode.Pool.PendingTransaction,
          data: "",
          fee: Decimal.new(1.1),
          hash: "E0137BE996B287A9DD541E4DD5C5FC6270D65738D837F20CC33F199353E973FA",
          nonce: 0,
          r: "8E2BFD6A070E324C161CFB112B1AE657B84A9C67788AA3BBCD1121EE9B64CE3E",
          s: "02DB5FB3A4582633C4EB0191FD1F1420EC388D460B3C37B6DB35C455ADC1FC63",
          to: "A7A5DF6D79203F6E6F0FA9CD550366FC9067A350",
          v: 0,
          value: Decimal.new(500)
        )

      refute Pool.is_tx_from_balance_sufficient?(tx)
    end
  end
end
