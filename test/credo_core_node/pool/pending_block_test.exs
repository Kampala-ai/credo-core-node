defmodule CredoCoreNode.PendingBlockTest do
  use CredoCoreNodeWeb.DataCase

  describe "table" do
    @describetag table_name: :pending_blocks

    test "has expected fields" do
      assert CredoCoreNode.Pool.PendingBlock.fields() == [
               :hash,
               :prev_hash,
               :number,
               :state_root,
               :receipt_root,
               :tx_root
             ]
    end
  end
end
