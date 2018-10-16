defmodule CredoCoreNodeWeb.NodeApi.V1.Temp.VoteController do
  use CredoCoreNodeWeb, :controller

  require Logger

  alias CredoCoreNode.Validation

  def create(conn, params) do
    Logger.info("Incoming vote #{params["block_height"]}")

    Validation.write_vote(params)

    send_resp(conn, :created, "")
  end
end
