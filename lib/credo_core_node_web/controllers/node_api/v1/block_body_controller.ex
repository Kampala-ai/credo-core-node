defmodule CredoCoreNodeWeb.NodeApi.V1.BlockBodyController do
  use CredoCoreNodeWeb, :controller

  alias CredoCoreNode.Blockchain

  def show(conn, %{"id" => id}) do
    block =
      id
      |> Blockchain.get_block()
      |> Blockchain.load_block_body()

    case block do
      nil ->
        send_resp(conn, :not_found, "")

      %{body: nil} ->
        send_resp(conn, :no_content, "")

      %{body: body} ->
        conn
        |> put_resp_content_type("application/x-rlp")
        |> send_chunked(:ok)
        |> send_chunks(body, 4096)
    end
  end
end
