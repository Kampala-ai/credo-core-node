defmodule CredoCoreNodeWeb.NodeApi.V1.ConnectionController do
  use CredoCoreNodeWeb, :controller

  require Logger

  alias CredoCoreNode.Network
  alias CredoCoreNodeWeb.Endpoint

  def create(conn, _params) do
    remote_ip =
      conn.remote_ip
      |> :inet_parse.ntoa()
      |> to_string()

    remote_session_id =
      conn
      |> get_req_header("x-ccn-session-id")
      |> List.first()

    current_session_id = Endpoint.config(:session_id)

    Logger.info("Incoming connection from #{remote_ip}")

    unless Network.get_known_node(remote_ip),
      do: Network.write_known_node(ip: remote_ip, is_seed: false)

    cond do
      Network.connected_to?(remote_ip, :outgoing) ->
        send_resp(conn, :found, "")

      Network.active_connections_limit_reached?(:incoming) ->
        send_resp(conn, :conflict, "")

      remote_session_id == current_session_id ->
        send_resp(conn, :forbidden, "")

      true ->
        {:ok, connection} =
          Network.write_connection(
            ip: remote_ip,
            is_active: true,
            is_outgoing: false,
            failed_attempts_count: 0,
            session_id: current_session_id
          )

        Network.retrieve_known_nodes(remote_ip, :incoming)

        conn
        |> put_status(:created)
        |> render("show.json", connection: connection)
    end
  end
end
