defmodule CredoCoreNode.NetworkTest do
  use CredoCoreNodeWeb.DataCase

  alias CredoCoreNode.Network

  describe "known_nodes" do
    @attrs [url: "http://0.0.0.0:80", last_active_at: DateTime.utc_now()]

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
      assert Network.get_known_node(known_node.url) == known_node
    end

    test "create_known_node/1 with valid data creates a known_node" do
      assert {:ok, known_node} = Network.write_known_node(@attrs)
      assert known_node.url == @attrs[:url]
      assert known_node.last_active_at == @attrs[:last_active_at]
    end

    test "delete_known_node/1 deletes the known_node" do
      known_node = known_node_fixture()
      assert {:ok, known_node} = Network.delete_known_node(known_node)
      assert Network.get_known_node(known_node.url) == nil
    end
  end
end
