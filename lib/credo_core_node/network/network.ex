defmodule CredoCoreNode.Network do
  @moduledoc """
  The Network context.
  """

  alias CredoCoreNode.Network.KnownNode

  @doc """
  Returns the list of known_nodes.
  """
  def list_known_nodes() do
    :known_nodes
    |> :mnesia.dirty_all_keys()
    |> Enum.map(fn url -> get_known_node(url) end)
  end

  @doc """
  Gets a single known_node.
  """
  def get_known_node(url) do
    found = :mnesia.dirty_read(:known_nodes, url)

    if length(found) > 0 do
      found
      |> hd()
      |> Tuple.to_list()
      |> tl()
      |> KnownNode.from_list()
    end
  end

  @doc """
  Creates a known_node.
  """
  def write_known_node(attrs) do
    :ok =
      [:known_nodes, attrs[:url], attrs[:last_active_at]]
      |> List.to_tuple()
      |> :mnesia.dirty_write()

    {:ok, %KnownNode{url: attrs[:url], last_active_at: attrs[:last_active_at]}}
  end

  @doc """
  Deletes a known_node.
  """
  def delete_known_node(%KnownNode{} = known_node) do
    :mnesia.dirty_delete(:known_nodes, known_node.url)
  end
end
