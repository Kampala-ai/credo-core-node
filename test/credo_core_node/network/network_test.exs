defmodule CredoCoreNode.NetworkTest do
  use CredoCoreNodeWeb.DataCase

  alias CredoCoreNode.Network

  describe "known_nodes" do
    @describetag table_name: :known_nodes
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

  describe "connections" do
    @describetag table_name: :connections
    @attrs [ip: "0.0.0.0", is_active: false, failed_attempts_count: 0]

    def connection_fixture(attrs \\ @attrs) do
      {:ok, connection} =
        attrs
        |> Network.write_connection()

      connection
    end

    test "list_connections/0 returns all connections" do
      connection = connection_fixture()
      assert Network.list_connections() == [connection]
    end

    test "get_connection!/1 returns the connection with given id" do
      connection = connection_fixture()
      assert Network.get_connection(connection.ip) == connection
    end

    test "create_connection/1 with valid data creates a connection" do
      assert {:ok, connection} = Network.write_connection(@attrs)
      assert connection.ip == @attrs[:ip]
      assert connection.is_active == @attrs[:is_active]
      assert connection.failed_attempts_count == @attrs[:failed_attempts_count]
    end

    test "delete_connection/1 deletes the connection" do
      connection = connection_fixture()
      assert {:ok, connection} = Network.delete_connection(connection)
      assert Network.get_connection(connection.ip) == nil
    end
  end
end
