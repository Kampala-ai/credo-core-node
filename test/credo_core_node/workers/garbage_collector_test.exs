defmodule CredoCoreNode.GarbageCollectorTest do
  use CredoCoreNodeWeb.DataCase

  alias CredoCoreNode.{Blockchain, Pool}
  alias CredoCoreNode.Blockchain.Block
  alias CredoCoreNode.Pool.{PendingBlock, PendingTransaction}
  alias CredoCoreNode.Workers.GarbageCollector

  alias Decimal, as: D

  describe "collect pending transaction garbage" do
    @describetag table_name: :pending_transactions

    test "deletes garbage pending transactions" do
      pending_transaction =
        %PendingTransaction{
          data: "",
          fee: D.new(1.1),
          hash: "680E3A773979575FC3E8B8FE2A42D864F881FD29C018A8F129629EC7084EB7DB",
          nonce: 0,
          r: "B7A3424EB20CB5A75BFEC0B2BC7A9EF0CC649B7EFD784442A11B612492349686",
          s: "4355A76B08672ADDFD0BED4F42DB5A6EFBE7AC582FCAE2E6D26AF3921A009C79",
          to: "F7DA6E2803E37C10D591C08EBFE2F8A018352955",
          v: 1,
          value: D.new(1_374_719_257.2286)
        }
        |> Pool.write_pending_transaction()
        |> elem(1)

      %Block{number: 50} |> Blockchain.write_block()

      GarbageCollector.collect_pending_transaction_garbage

      assert is_nil(Pool.get_pending_transaction(pending_transaction.hash))
    end
  end

  describe "collect pending block garbage" do
    @describetag table_name: :pending_blocks

    test "deletes garbage pending blocks" do
      Blockchain.load_genesis_block()

      {:ok, pending_block} =
        %PendingBlock{
          body: nil,
          hash: "72E037C0AB493574004DF70CB26778D64291EF8BA00256A4122B0355A4D036D7",
          number: 5,
          prev_hash: "188489887B10CBC148330A33E8433626A52C23260612E8E1CACAB594933CADBC",
          receipt_root: "",
          state_root: "",
          tx_root: "FCCBA2113C4163D7A4A3A742A0576651A5300D84C318E756937294D709B11F7C"
        }
        |> Pool.write_pending_block()

      %Block{number: 50} |> Blockchain.write_block()

      GarbageCollector.collect_pending_block_garbage

      assert is_nil(Pool.get_pending_block(pending_block.hash))
    end
  end
end