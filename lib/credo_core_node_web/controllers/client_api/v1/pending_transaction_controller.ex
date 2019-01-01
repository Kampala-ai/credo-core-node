defmodule CredoCoreNodeWeb.ClientApi.V1.PendingTransactionController do
  use CredoCoreNodeWeb, :controller

  alias CredoCoreNode.Pool

  def create(conn, params) do
    {:ok, private_key} =
      conn
      |> get_req_header("x-ccn-private-key")
      |> hd()
      |> Base.decode16()

    # TODO: params store keys as strings and building structure expects passing them as atoms;
    #   converting keys from string to atom is a common task, probably should be somehow generalized
    attrs = Enum.map(params, fn {key, value} -> {:"#{key}", value} end)

    {:ok, tx} = Pool.generate_pending_transaction(private_key, attrs)

    if Pool.invalid_tx?(tx) do
      send_resp(conn, :unprocessable_entity, "")
    else
      tx
      |> Pool.write_pending_transaction()
      |> elem(1)
      |> Pool.propagate_pending_transaction()

      conn
      |> put_status(:created)
      |> render("show.json", pending_transaction: tx)
    end
  end
end
