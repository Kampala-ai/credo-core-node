defmodule CredoCoreNode.Network do
  @moduledoc """
  The Network context.
  """

  alias CredoCoreNode.Network.KnownNode
  alias Mnesia.Repo

  @doc """
  Returns the list of known_nodes.
  """
  def list_known_nodes() do
    Repo.list(KnownNode)
  end

  @doc """
  Gets a single known_node.
  """
  def get_known_node(url) do
    Repo.get(KnownNode, url)
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
end
