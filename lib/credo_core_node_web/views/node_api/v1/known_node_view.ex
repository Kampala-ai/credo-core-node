defmodule CredoCoreNodeWeb.NodeApi.V1.KnownNodeView do
  use CredoCoreNodeWeb, :view

  def render("index.json", %{known_nodes: known_nodes}) do
    %{data: render_many(known_nodes, __MODULE__, "show.json")}
  end

  def render("show.json", %{known_node: known_node}) do
    %{
      ip: known_node.ip
    }
  end
end
