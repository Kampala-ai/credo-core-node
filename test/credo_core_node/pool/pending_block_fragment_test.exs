defmodule CredoCoreNode.PendingBlockFragmentTest do
  use CredoCoreNodeWeb.DataCase

  describe "table" do
    @describetag table_name: :pending_block_fragments

    test "has expected fields" do
      assert CredoCoreNode.Pool.PendingBlockFragment.fields == [:hash, :body]
    end

  end

end