defmodule CredoCoreNode.Workers.ConnectionManager do
  use GenServer

  require Logger

  import Process, only: [send_after: 3]

  alias CredoCoreNode.Network
  alias CredoCoreNodeWeb.Endpoint

  @default_interval 60_000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  def init(opts) do
    Logger.info("Initializing the connection manager...")

    state = %{interval: Keyword.get(opts, :interval, @default_interval)}

    CredoCoreNode.Network.setup_seed_nodes()

    Network.list_connections()
    |> Enum.filter(& &1.is_active)
    |> Enum.each(&Network.write_connection(%{&1 | is_active: false}))

    handle_info(:manage_connections, state)

    {:ok, state}
  end

  def handle_info(:manage_connections, state) do
    schedule_manage_connections(state.interval)

    connect()

    {:noreply, state}
  end

  defp connect(), do: connect(0)
  defp connect(10), do: nil
  defp connect(num_attempts) do
    unless Network.active_connections_limit_reached?(:outgoing) do
      known_node =
        Network.list_known_nodes()
        |> Enum.filter(&(!Network.connected_to?(&1.ip, :outgoing)))
        |> Enum.sort(&Network.compare(&1, &2))
        |> List.first()

      port = Application.get_env(:credo_core_node, CredoCoreNode.Network)[:node_connection_port]
      url = "#{Network.api_url(known_node.ip)}/connections"

      headers =
        Network.node_request_headers() ++ [{"x-ccn-session-id", Endpoint.config(:session_id)}]

      Logger.info(
        "Connection attempt ##{num_attempts + 1}. Trying to connect to #{known_node.ip}:#{port}"
      )

      case :hackney.request(:post, url, headers, "", [:with_body, pool: false]) do
        {:ok, 201, _headers, body} when body != "" ->
          Logger.info("Responded with `created` (successfully connected)")
          %{"session_id" => session_id} = Poison.decode!(body)
          Network.connect_to(known_node.ip, session_id)
          Network.retrieve_known_nodes(known_node.ip, :outgoing)

        {:ok, 302, _headers, _body} ->
          Logger.info(
            "Responded with `found` (already connected as outgoing on remote node side)"
          )

          Network.write_connection(
            ip: known_node.ip,
            is_active: true,
            is_outgoing: false,
            failed_attempts_count: 0,
            socket_client_id: nil
          )

          Network.retrieve_known_nodes(known_node.ip, :incoming)

        {:ok, 403, _headers, _body} ->
          Logger.info("Responded with `forbidden` (trying to connect to self)")
          Network.delete_known_node(known_node.ip)
          Network.delete_connection(known_node.ip)

        {:ok, 409, _headers, _body} ->
          Logger.info("Responded with `conflict` (remote node doesn't accept new connections)")
          Network.retrieve_known_nodes(known_node.ip, :outgoing)

        _ ->
          Logger.info("No response or incorrect response")

          case Network.get_connection(known_node.ip) do
            nil ->
              Network.write_connection(
                ip: known_node.ip,
                is_active: false,
                failed_attempts_count: 1
              )

            connection ->
              failed_attempts_count = (connection.failed_attempts_count || 0) + 1

              Network.write_connection(
                ip: known_node.ip,
                is_active: false,
                failed_attempts_count: failed_attempts_count
              )

              if is_persistently_unreachable_node?(known_node, failed_attempts_count) ||
                   is_deprecated_seed_node?(known_node, failed_attempts_count) do
                Network.delete_known_node(known_node.ip)
                Network.delete_connection(known_node.ip)
              end
          end
      end

      connect(num_attempts + 1)
    end
  end

  defp is_persistently_unreachable_node?(known_node, failed_attempts_count) do
    !known_node.is_seed && failed_attempts_count >= 5
  end

  defp is_deprecated_seed_node?(known_node, failed_attempts_count) do
    known_node.is_seed && failed_attempts_count >= 1000
  end

  defp schedule_manage_connections(interval) do
    send_after(self(), :manage_connections, interval)
  end
end
