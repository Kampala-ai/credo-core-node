defmodule CredoCoreNodeWeb.NodeApi.V1.BlockController do
  use CredoCoreNodeWeb, :controller

  alias CredoCoreNode.Blockchain

  def index(conn, params) do
    offset = String.to_integer(params["offset"] || "0")
    limit = String.to_integer(params["limit"] || "50")

    blocks =
      Blockchain.list_blocks()
      |> Enum.filter(&(&1.number > offset))
      |> Enum.sort(&(&1.number < &2.number))
      |> Enum.take(limit)

    render(conn, "index.json", blocks: blocks)
  end
end
