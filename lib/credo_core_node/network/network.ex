defmodule CredoCoreNode.Network do
  @moduledoc """
  The Network context.
  """

  require Logger

  alias CredoCoreNode.Network.{Connection, KnownNode}
  alias CredoCoreNodeWeb.Endpoint
  alias Mnesia.Repo

  @localhost_ips [{127, 0, 0, 1}, {0, 0, 0, 0}]

  defp seed_node_ips(),
    do: Application.get_env(:credo_core_node, CredoCoreNode.Network)[:seed_node_ips]

  defp node_connection_port(),
    do: Application.get_env(:credo_core_node, CredoCoreNode.Network)[:node_connection_port]

  @doc """
  Returns the maximum allowed number of active outgoing connections.
  """
  def active_connections_limit(:outgoing), do: 3

  @doc """
  Returns the maximum allowed number of active incoming connections.
  """
  def active_connections_limit(:incoming), do: 3

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
  Returns `:incoming` if an active incoming connection from the given IP exists, otherwise returns
  `:outgoing`
  """
  def connection_type(ip) do
    case get_connection(ip) do
      %{is_active: true, is_outgoing: false} -> :incoming
      _ -> :outgoing
    end
  end

  def is_localhost?(ip) do
    Enum.member?(@localhost_ips, ip)
  end

  def format_ip(nil), do: nil

  def format_ip(ip) when is_tuple(ip) do
    ip
    |> Tuple.to_list()
    |> Enum.join(".")
  end

  @doc """
  Returns the current node's ip
  """
  def get_current_ip do
    :inet.getif()
    |> elem(1)
    |> Enum.map(fn {ip, _broadaddr, _mask} -> ip end)
    |> Enum.reject(&is_localhost?(&1))
    |> List.first()
    |> format_ip()
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
  def retrieve_known_nodes(ip), do: retrieve_known_nodes(ip, connection_type(ip))

  @doc """
  Retrieves the list of known_nodes from the given IP and merges into the local list
  """
  def retrieve_known_nodes(ip, :outgoing) do
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
  Retrieves the list of known_nodes from the given IP and merges into the local list
  """
  def retrieve_known_nodes(ip, :incoming) do
    # TODO: handler for this request is not implemented yet
    Endpoint.broadcast!(
      "node_socket:#{get_connection(ip).session_id}",
      "known_nodes:list_request",
      %{session_id: Endpoint.config(:session_id)}
    )
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
  def write_connection(%Connection{} = connection), do: write_connection(Map.to_list(connection))

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
  Returns if the maximum allowed number of active outgoing connections is reached.
  """
  def active_connections_limit_reached?(:outgoing) do
    length(Enum.filter(list_connections(), & &1.is_active && &1.is_outgoing)) >=
      min(length(list_known_nodes()), active_connections_limit(:outgoing))
  end

  @doc """
  Returns if the maximum allowed number of active incoming connections is reached.
  """
  def active_connections_limit_reached?(:incoming) do
    length(Enum.filter(list_connections(), & &1.is_active && !&1.is_outgoing)) >=
      min(length(list_known_nodes()), active_connections_limit(:incoming))
  end

  @doc """
  Returns the first available socket client id.
  """
  def available_socket_client_id() do
    used_ids =
      list_connections()
      |> Enum.filter(& &1.is_active && &1.is_outgoing)
      |> Enum.map(& &1.socket_client_id)

    diff = Enum.to_list(0..(active_connections_limit(:outgoing) - 1)) -- used_ids
    List.first(diff)
  end

  @doc """
  Returns if the current node has active outgoing connection to the given IP.
  """
  def connected_to?(ip, :outgoing) do
    case get_connection(ip) do
      nil -> false
      connection -> connection.is_active && connection.is_outgoing
    end
  end

  @doc """
  Returns if the current node has active incoming connection from the given IP.
  """
  def connected_to?(ip, :incoming) do
    case get_connection(ip) do
      nil -> false
      connection -> connection.is_active && !connection.is_outgoing
    end
  end

  @doc """
  Establishes outgoing socket connection to the given IP and writes the `Connection` record
  """
  def connect_to(ip, session_id) do
    socket_client_id = available_socket_client_id()

    # TODO: using Poison encoding/decoding upper-level `Phoenix.Socket.Message` struct;
    #   to be replaced with RLP serializer later to reduce the payload size
    socket_client_module(socket_client_id).start_link(
      url: socket_url(ip),
      serializer: Poison,
      params: %{session_id: Endpoint.config(:session_id)}
    )

    channel_client_module(socket_client_id).start_link(
      socket: CredoCoreNode.Network.socket_client_module(0),
      topic: "events:all",
      caller: self()
    )

    channel_client_module(socket_client_id).join(%{})

    write_connection(
      ip: ip,
      is_active: true,
      is_outgoing: true,
      failed_attempts_count: 0,
      socket_client_id: socket_client_id,
      session_id: session_id
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
    session_ids = options[:session_ids] || []
    _recipients = options[:recipients] || :all

    Logger.info("Propagating: #{inspect(record)}")

    # TODO: pushing notifications synchronously may cause delays,
    #   consider executing this code asynchronously
    list_connections()
    |> Enum.filter(&(&1.is_active && !is_nil(&1.socket_client_id)))
    |> Enum.each(fn connection ->
      if connection.is_outgoing do
        module = channel_client_module(connection.socket_client_id)

        if GenServer.whereis(module) do
          Logger.info("sending to #{connection.ip}")

          module.push("#{Mnesia.Table.name(record)}:#{event}", %{
            rlp: ExRLP.encode(record, encoding: :hex),
            session_ids: session_ids ++ [Endpoint.config(:session_id)]
          })
        else
          Logger.info("closing connection to #{connection.ip}")
          write_connection(%{connection | is_active: false})
        end
      else
        Endpoint.broadcast!("events:all", "#{Mnesia.Table.name(record)}:#{event}", %{
          rlp: ExRLP.encode(record, encoding: :hex),
          session_ids: session_ids ++ [Endpoint.config(:session_id)]
        })
      end
    end)
  end
end
