defmodule CredoCoreNode.KnownNodeTest do
  use CredoCoreNodeWeb.DataCase

  describe "table" do
    @describetag table_name: :known_nodes

    test "has expected fields" do
      assert CredoCoreNode.Network.KnownNode.fields == [:ip, :is_seed]
    end

  end

end