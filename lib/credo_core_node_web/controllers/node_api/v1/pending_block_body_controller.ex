defmodule CredoCoreNodeWeb.NodeApi.V1.PendingBlockBodyController do
  use CredoCoreNodeWeb, :controller

  alias CredoCoreNode.Pool

  def show(conn, %{"id" => id}) do
    block =
      id
      |> Pool.get_pending_block()
      |> Pool.load_pending_block_body()

    conn
    |> put_resp_content_type("application/x-rlp")
    |> send_chunked(:ok)
    |> send_chunks(block.body, 4096)
  end
end
