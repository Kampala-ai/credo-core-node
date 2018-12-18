defmodule CredoCoreNode.BlockValidatorTest do
  use CredoCoreNodeWeb.DataCase

  alias CredoCoreNode.Pool
  alias CredoCoreNode.Blockchain.BlockValidator

  alias Decimal, as: D

  describe "validly constructed block" do
    @describetag table_name: :pending_blocks

    def valid_pending_block_fixture() do
      {:ok, pending_block} =
        %CredoCoreNode.Pool.PendingBlock{
          body:
            <<249, 1, 162, 248, 196, 128, 168, 65, 70, 50, 52, 55, 51, 56, 66, 52, 48, 54, 68, 66,
              54, 51, 56, 55, 68, 48, 53, 69, 66, 55, 67, 69, 49, 69, 57, 48, 68, 52, 50, 48, 66,
              50, 53, 55, 57, 56, 70, 138, 211, 194, 27, 206, 204, 237, 161, 0, 0, 0, 136, 15, 67,
              252, 44, 4, 238, 0, 0, 128, 128, 184, 64, 56, 68, 66, 70, 57, 54, 50, 56, 65, 66,
              53, 57, 65, 66, 55, 69, 50, 56, 52, 49, 56, 66, 51, 68, 53, 56, 69, 69, 54, 57, 54,
              66, 55, 52, 52, 54, 50, 52, 48, 52, 49, 66, 70, 57, 53, 53, 48, 55, 53, 70, 68, 68,
              51, 65, 50, 54, 53, 51, 49, 55, 51, 57, 48, 53, 184, 64, 55, 65, 52, 65, 55, 51, 56,
              55, 55, 54, 48, 52, 70, 52, 52, 66, 67, 54, 55, 51, 68, 52, 54, 67, 69, 70, 54, 69,
              50, 54, 55, 50, 56, 51, 50, 49, 53, 70, 67, 70, 54, 67, 69, 55, 65, 70, 56, 50, 67,
              49, 56, 66, 70, 69, 69, 66, 68, 56, 48, 53, 51, 52, 54, 56, 248, 218, 128, 168, 65,
              57, 65, 50, 66, 57, 65, 49, 69, 66, 68, 68, 69, 57, 69, 69, 66, 53, 69, 70, 55, 51,
              51, 69, 52, 55, 70, 67, 49, 51, 55, 68, 55, 69, 66, 57, 53, 51, 52, 48, 136, 15, 67,
              252, 44, 4, 238, 0, 0, 136, 13, 224, 182, 179, 167, 100, 0, 0, 152, 123, 34, 116,
              120, 95, 116, 121, 112, 101, 34, 32, 58, 32, 34, 99, 111, 105, 110, 98, 97, 115,
              101, 34, 125, 128, 184, 64, 56, 55, 49, 65, 52, 52, 69, 57, 69, 49, 66, 49, 66, 52,
              50, 57, 54, 65, 69, 66, 66, 57, 57, 54, 51, 70, 57, 54, 70, 53, 68, 51, 67, 49, 55,
              54, 70, 65, 50, 52, 49, 50, 70, 50, 68, 54, 51, 66, 66, 68, 50, 57, 49, 56, 52, 68,
              50, 66, 70, 70, 67, 70, 56, 48, 184, 64, 51, 50, 53, 50, 70, 49, 48, 67, 50, 70, 55,
              52, 57, 68, 55, 50, 49, 68, 57, 66, 48, 55, 67, 69, 56, 53, 54, 52, 52, 48, 54, 55,
              50, 49, 67, 70, 65, 55, 56, 69, 50, 53, 57, 53, 50, 69, 66, 67, 52, 65, 67, 50, 69,
              70, 66, 66, 70, 53, 51, 48, 51, 49, 49, 68>>,
          hash: "B05C01CFCE8B7C14856FB666B2E8D5BF46BAE551B634DDB5327AD87D5FC05FA8",
          number: 1,
          prev_hash: "51D9D50254B866AEE7060B51B611B2C19FB280641FB5CDB11D4669AA14BB1A07",
          receipt_root: "",
          state_root: "",
          tx_root: "64B468C8FCD390719F5395691300BF4E2CF049329F0C0B32B944D927A19D2129"
        }
        |> Pool.write_pending_block()

      pending_block
    end

    test "is marked as valid" do
      pending_block = valid_pending_block_fixture()

      assert {:ok, _} = BlockValidator.validate_block(pending_block, true)
    end
  end

  describe "invalidly constructed block" do
    @describetag table_name: :pending_blocks

    test "validate_previous_hash/1 returns false" do
      {:ok, invalid_pending_block} =
        %CredoCoreNode.Pool.PendingBlock{prev_hash: nil}
        |> Pool.write_pending_block()

      refute BlockValidator.validate_previous_hash(invalid_pending_block)
    end

    test "validate_transaction_count/1 returns false" do
      {:ok, invalid_pending_block} =
        %CredoCoreNode.Pool.PendingBlock{}
        |> Pool.write_pending_block()

      refute BlockValidator.validate_transaction_count(invalid_pending_block)
    end

    test "validate_coinbase_transaction/1 returns false" do
      {:ok, invalid_pending_block} =
        %CredoCoreNode.Pool.PendingBlock{}
        |> Pool.write_pending_block()

      refute BlockValidator.validate_coinbase_transaction(invalid_pending_block)
    end

    test "validate_format/1 returns false" do
      {:ok, invalid_pending_block} =
        %CredoCoreNode.Pool.PendingBlock{hash: nil}
        |> Pool.write_pending_block()

      refute BlockValidator.validate_format(invalid_pending_block)
    end

    test "validate_transaction_amounts/1 returns false" do
      private_key = :crypto.strong_rand_bytes(32)
      attrs = [nonce: 0, to: "ABC", value: D.new(1), fee: D.new(1), data: ""]

      {:ok, pending_transaction} =
        private_key
        |> Pool.generate_pending_transaction(attrs)
        |> elem(1)
        |> Pool.write_pending_transaction()

      {:ok, block} =
        [pending_transaction]
        |> Pool.generate_pending_block()
        |> elem(1)
        |> Pool.write_pending_block()

      refute BlockValidator.validate_transaction_amounts(block)
    end

    test "validate_transaction_are_unmined/1 returns false" do
      pending_block =
        [
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
        ]
        |> CredoCoreNode.Pool.generate_pending_block()
        |> elem(1)
        |> Pool.write_pending_block()
        |> elem(1)

      refute BlockValidator.validate_transaction_are_unmined(pending_block)
    end
  end

  describe "data length" do
    @describetag table_name: :pending_blocks

    def block_fixture(data_length) do
      chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ" |> String.split("")
      long_data =
        Enum.reduce((0..data_length), [], fn (_i, acc) ->
          [Enum.random(chars) | acc]
        end) |> Enum.join("")
      private_key = :crypto.strong_rand_bytes(32)
      attrs = [nonce: 0, to: "ABC", value: D.new(1), fee: D.new(1), data: long_data]

      {:ok, pending_transaction} =
        private_key
        |> Pool.generate_pending_transaction(attrs)
        |> elem(1)
        |> Pool.write_pending_transaction()

      {:ok, block} =
        [pending_transaction]
        |> Pool.generate_pending_block()
        |> elem(1)
        |> Pool.write_pending_block()

      block
    end

    test "validate_transaction_data_length/1 returns true" do
      block = block_fixture(10_000)

      assert BlockValidator.validate_transaction_data_length(block)
    end

    test "validate_transaction_data_length/1 returns false" do
      block = block_fixture(60_000)

      refute BlockValidator.validate_transaction_data_length(block)
    end
  end

  describe "invalid value transfer limits" do
    @describetag table_name: :pending_blocks
    @private_key :crypto.strong_rand_bytes(32)
    @value D.new(1_000_001)
    @attrs [nonce: 0, to: "ABC", fee: D.new(1), data: ""]

    def block_fixture(private_key \\ @private_key, attrs \\ @attrs, value \\ @value) do
      {:ok, pending_transaction} =
        private_key
        |> Pool.generate_pending_transaction(attrs ++ [value: value])
        |> elem(1)
        |> Pool.write_pending_transaction()

      {:ok, block} =
        [pending_transaction]
        |> Pool.generate_pending_block()
        |> elem(1)
        |> Pool.write_pending_block()

      block
    end

    test "validate_value_transfer_limits/1 returns false" do
      invalid_pending_block = block_fixture()

      refute BlockValidator.validate_value_transfer_limits(invalid_pending_block)
    end

    test "validate_per_tx_value_transfer_limits/1 returns false" do
      block = block_fixture()
      txs = block |> Pool.list_pending_transactions()

      refute BlockValidator.validate_per_tx_value_transfer_limits(txs)
    end

    test "validate_per_block_value_transfer_limits/1 returns false" do
      block = block_fixture(@private_key, @attrs, D.new(10_000_001))
      txs = block |> Pool.list_pending_transactions()

      refute BlockValidator.validate_per_block_value_transfer_limits(txs)
    end

    test "validate_per_block_chain_segment_value_transfer_limits/1 returns false" do
      block = block_fixture(@private_key, @attrs, D.new(50_000_001))

      refute BlockValidator.validate_per_block_chain_segment_value_transfer_limits(block)
    end
  end
end
