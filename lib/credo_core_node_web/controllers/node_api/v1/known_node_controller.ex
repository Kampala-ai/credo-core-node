defmodule CredoCoreNodeWeb.NodeApi.V1.KnownNodeController do
  use CredoCoreNodeWeb, :controller

  alias CredoCoreNode.Network

  def index(conn, _params) do
    known_nodes = Network.list_known_nodes()
    render(conn, "index.json", known_nodes: known_nodes)
  end
end
