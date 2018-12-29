defmodule CredoCoreNode.Adapters.NetworkAdapter do
  alias CredoCoreNode.Network.{Connection, KnownNode}

  @callback active_connections_limit(atom()) :: integer()
  @callback node_request_headers(atom() | nil) :: list()
  @callback api_url(String.t()) :: String.t()
  @callback socket_url(String.t()) :: String.t()
  @callback socket_client_module(integer()) :: any()
  @callback channel_client_module(integer()) :: any()
  @callback connection_type(String.t()) :: :outgoing | :incoming
  @callback is_localhost?(String.t()) :: boolean()

  @callback format_ip(String.t() | nil) :: String.t()
  @callback get_current_ip() :: String.t()

  @callback list_known_nodes() :: list(%KnownNode{})
  @callback get_known_node(String.t()) :: %KnownNode{}
  @callback write_known_node(map()) :: %KnownNode{}
  @callback delete_known_node(%KnownNode{} | String.t() | nil) :: %KnownNode{}
  @callback merge_known_nodes(list(%KnownNode{})) :: nil
  @callback retrieve_known_nodes(String.t(), atom() | nil) :: any()

  @callback list_connections() :: list(%Connection{})
  @callback get_connection(String.t()) :: %Connection{}
  @callback write_connection(%Connection{} | map()) :: %Connection{}
  @callback delete_connection(%Connection{} | String.t() | nil) :: %Connection{} | nil
  @callback active_connections_limit_reached?(:outgoing | :incoming) :: boolean()

  @callback setup_seed_nodes() :: nil
  @callback available_socket_client_id() :: integer()
  @callback connected_to?(String.t(), :incoming | :outgoing) :: boolean()
  @callback connect_to(String.t(), integer()) :: %Connection{}
  @callback updated_at(String.t()) :: DateTime.t()
  @callback compare(%KnownNode{} | %DateTime{} | any(), %KnownNode{} | %DateTime{} | any()) :: boolean()
  @callback propagate_record(any(), list()) :: any()
end