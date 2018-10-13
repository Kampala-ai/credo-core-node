defmodule CredoCoreNodeWeb.NodeApi.V1.Temp.PendingTransactionController do
  use CredoCoreNodeWeb, :controller

  require Logger

  alias CredoCoreNode.Pool
  alias CredoCoreNode.Pool.PendingTransaction

  def create(conn, params) do
    Logger.info("Incoming pending transaction #{params["hash"]}")

    if Pool.get_pending_transaction(params["hash"]) do
      send_resp(conn, :found, "")
    else
      params["body"]
      |> ExRLP.decode(encoding: :hex)
      |> PendingTransaction.from_list(type: :signed_rlp)
      |> Pool.write_pending_transaction()

      send_resp(conn, :created, "")
    end
  end
end
