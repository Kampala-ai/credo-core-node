defmodule CredoCoreNode.Network do
  @moduledoc """
  The Network context.
  """

  alias CredoCoreNode.Network.{Connection, KnownNode}
  alias Mnesia.Repo

  defp seed_node_ips(),
    do: Application.get_env(:credo_core_node, CredoCoreNode.Network)[:seed_node_ips]

  defp node_connection_port(),
    do: Application.get_env(:credo_core_node, CredoCoreNode.Network)[:node_connection_port]

  @doc """
  Returns the maximum allowed number of active connections.
  """
  def max_active_connections, do: 6

  @doc """
  Returns the request headers for cross-node requests.
  """
  def node_request_headers(), do: node_request_headers(:json)
  def node_request_headers(:json), do: do_node_request_headers("application/json")
  def node_request_headers(:rlp), do: do_node_request_headers("application/x-rlp")

  defp do_node_request_headers(content_type) do
    [
      {"content-type", content_type},
      {"user-agent", "CredoCoreNode/1.0"}
    ]
  end

  @doc """
  """
  def api_url(ip) do
    "http://#{ip}:#{node_connection_port()}/node_api/v1"
  end

  @doc """
  """
  def socket_url(ip) do
    "ws://#{ip}:#{node_connection_port()}/node_socket/v1/websocket"
  end

  @doc """
  Returns socket client module with the given id.
  """
  def socket_client_module(id) when is_integer(id) do
    :"Elixir.CredoCoreNodeWeb.NodeSocket.V1.SocketClient#{id}"
  end

  @doc """
  Returns channel client module with the given id.
  """
  def channel_client_module(id) when is_integer(id) do
    :"Elixir.CredoCoreNodeWeb.NodeSocket.V1.EventChannelClient#{id}"
  end

  @doc """
  Returns the current node's ip
  """
  def get_current_ip do
    {:ok, ifs} = :inet.getif()
    [ip | _] = Enum.map(ifs, fn {ip, _broadaddr, _mask} -> ip end)

    ip
    |> Tuple.to_list()
    |> Enum.join(".")
  end

  @doc """
  Returns the list of known_nodes.
  """
  def list_known_nodes() do
    Repo.list(KnownNode)
  end

  @doc """
  Gets a single known_node.
  """
  def get_known_node(ip) do
    Repo.get(KnownNode, ip)
  end

  @doc """
  Creates/updates a known_node.
  """
  def write_known_node(attrs) do
    Repo.write(KnownNode, attrs)
  end

  @doc """
  Deletes a known_node.
  """
  def delete_known_node(nil), do: nil
  def delete_known_node(%KnownNode{} = known_node) do
    Repo.delete(known_node)
  end

  def delete_known_node(ip) do
    ip
    |> get_known_node()
    |> delete_known_node()
  end

  @doc """
  Writes seed nodes from application config.
  """
  def setup_seed_nodes() do
    Enum.each(seed_node_ips(), &write_known_node(ip: &1, is_seed: true))
  end

  @doc """
  Retrieves the list of known_nodes from the given IP and merges into the local list
  """
  def retrieve_known_nodes(ip) do
    url = "#{api_url(ip)}/known_nodes"

    case :hackney.request(:get, url, node_request_headers(), "", [:with_body, pool: false]) do
      {:ok, 200, _headers, body} ->
        known_nodes = Poison.decode!(body)["data"]

        Enum.each(known_nodes, fn known_node ->
          unless get_known_node(known_node["ip"]) do
            write_known_node(ip: known_node["ip"], is_seed: false)
          end
        end)

      _ ->
        write_connection(ip: ip, is_active: false)
    end
  end

  @doc """
  Returns the list of connections.
  """
  def list_connections() do
    Repo.list(Connection)
  end

  @doc """
  Gets a single connection.
  """
  def get_connection(ip) do
    Repo.get(Connection, ip)
  end

  @doc """
  Creates/updates a connection.
  """
  def write_connection(attrs) do
    Repo.write(Connection, attrs ++ [updated_at: :os.system_time(:millisecond)])
  end

  @doc """
  Deletes a connection.
  """
  def delete_connection(nil), do: nil
  def delete_connection(%Connection{} = connection) do
    Repo.delete(connection)
  end

  def delete_connection(ip) do
    ip
    |> get_connection()
    |> delete_connection()
  end

  @doc """
  Returns if the necessary number of active connections is reached.
  """
  def fully_connected?() do
    length(Enum.filter(list_connections(), & &1.is_active)) >=
      min(length(list_known_nodes()), max_active_connections())
  end

  @doc """
  Returns the first available socket client id.
  """
  def available_socket_client_id() do
    used_ids =
      list_connections()
      |> Enum.filter(& &1.is_active)
      |> Enum.map(& &1.socket_client_id)

    diff = Enum.to_list(0..(max_active_connections() - 1)) -- used_ids
    List.first(diff)
  end

  @doc """
  Returns if the current node is connected to the given IP.
  """
  def connected_to?(ip) do
    case get_connection(ip) do
      nil -> false
      connection -> connection.is_active
    end
  end

  @doc """
  Establishes socket connection to the given IP and writes the `Connection` record
  """
  def connect_to(ip) do
    socket_client_id = available_socket_client_id()

    # TODO: using Poison encoding/decoding upper-level `Phoenix.Socket.Message` struct;
    #   to be replaced with RLP serializer later to reduce the payload size
    socket_client_module(socket_client_id).start_link(
      url: socket_url(ip),
      serializer: Poison
    )

    channel_client_module(socket_client_id).start_link(
      socket: CredoCoreNode.Network.socket_client_module(0),
      topic: "events:all",
      caller: self()
    )

    channel_client_module(socket_client_id).push("phx_join", %{})

    write_connection(
      ip: ip,
      is_active: true,
      failed_attempts_count: 0,
      socket_client_id: socket_client_id
    )
  end

  def updated_at(ip) do
    case get_connection(ip) do
      nil -> false
      connection -> connection.updated_at
    end
  end

  def propagate_record(record, options \\ []) do
    event = options[:event] || :create
    _recipients = options[:recipients] || :all

    # TODO: pushing notifications synchronously may cause delays,
    #   consider executing this code asynchronously
    list_connections()
    |> Enum.filter(& &1.is_active)
    |> Enum.filter(&(!is_nil(&1.socket_client_id)))
    |> Enum.map(& &1.socket_client_id)
    |> Enum.map(&channel_client_module(&1))
    |> Enum.each(
      & &1.push("#{Mnesia.Table.name(record)}:#{event}", %{
        rlp: ExRLP.encode(record, encoding: :hex)
      })
    )
  end
end
