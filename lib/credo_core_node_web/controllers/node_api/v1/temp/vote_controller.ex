defmodule CredoCoreNodeWeb.NodeApi.V1.Temp.VoteController do
  use CredoCoreNodeWeb, :controller

  require Logger

  alias CredoCoreNode.Mining

  def create(conn, params) do
    Logger.info("Incoming vote #{params["block_height"]}")

    for {key, val} <- params, into: %{}, do: {String.to_atom(key), val}
    |> Validation.write_vote()

    send_resp(conn, :created, "")
  end
end
