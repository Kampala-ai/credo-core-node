defmodule CredoCoreNodeWeb.NodeApi.V1.KnownNodeControllerTest do
  use CredoCoreNodeWeb.ConnCase

  describe "index" do
    test "lists all known_nodes", %{conn: conn} do
      conn = get(conn, node_api_v1_known_node_path(conn, :index))
      assert json_response(conn, 200) == %{"data" => []}
    end
  end
end
