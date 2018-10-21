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
  Returns the request headers for cross-node requests.
  """
  def node_request_headers() do
    [
      {"content-type", "application/json"},
      {"user-agent", "CredoCoreNode/1.0"}
    ]
  end

  @doc """
  """
  def request_url(ip) do
    "http://#{ip}:#{node_connection_port()}"
  end

  @doc """
  Returns the current node's ip
  """
  def get_current_ip do
    {:ok, ifs} = :inet.getif()
    [ip | _] = Enum.map(ifs, fn {ip, _broadaddr, _mask} -> ip end)

    ip
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
  def delete_known_node(%KnownNode{} = known_node) do
    Repo.delete(known_node)
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
    url = "#{request_url(ip)}/node_api/v1/known_nodes"

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
  def delete_connection(%Connection{} = connection) do
    Repo.delete(connection)
  end

  @doc """
  Returns if the necessary number of active connections is reached.
  """
  def fully_connected?() do
    length(Enum.filter(list_connections(), & &1.is_active)) >= min(length(list_known_nodes()), 6)
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

  def updated_at(ip) do
    case get_connection(ip) do
      nil -> false
      connection -> connection.updated_at
    end
  end
end
