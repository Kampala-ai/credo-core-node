defmodule CredoCoreNode.BlockFragmentTest do
  use CredoCoreNodeWeb.DataCase

  describe "table" do
    @describetag table_name: :block_fragments

    test "has expected fields" do
      assert CredoCoreNode.Blockchain.BlockFragment.fields == [:hash, :body]
    end

  end

end