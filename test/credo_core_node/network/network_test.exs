defmodule CredoCoreNode.NetworkTest do
  use CredoCoreNodeWeb.DataCase

  alias CredoCoreNode.Network

  describe "known_nodes" do
    @attrs [ip: "0.0.0.0"]

    def known_node_fixture(attrs \\ @attrs) do
      {:ok, known_node} =
        attrs
        |> Network.write_known_node()

      known_node
    end

    test "list_known_nodes/0 returns all known_nodes" do
      known_node = known_node_fixture()
      assert Network.list_known_nodes() == [known_node]
    end

    test "get_known_node!/1 returns the known_node with given id" do
      known_node = known_node_fixture()
      assert Network.get_known_node(known_node.ip) == known_node
    end

    test "create_known_node/1 with valid data creates a known_node" do
      assert {:ok, known_node} = Network.write_known_node(@attrs)
      assert known_node.ip == @attrs[:ip]
    end

    test "delete_known_node/1 deletes the known_node" do
      known_node = known_node_fixture()
      assert {:ok, known_node} = Network.delete_known_node(known_node)
      assert Network.get_known_node(known_node.ip) == nil
    end
  end
end
