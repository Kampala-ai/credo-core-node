defmodule CredoCoreNode.BlockTest do
  use CredoCoreNodeWeb.DataCase

  describe "table" do
    @describetag table_name: :blocks

    test "has expected fields" do
      assert CredoCoreNode.Blockchain.Block.fields == [:hash, :prev_hash, :number, :state_root, :receipt_root, :tx_root]
    end

  end

end