defmodule MPT.Repo do
  @moduledoc """
  Merkle Patricia Tree Repo adapter.
  """

  alias Mnesia.Record
  alias MerklePatriciaTree.Trie
  alias MerklePatriciaTree.Trie.Inspector

  @doc """
  Returns the list of records.
  """
  def list(trie, schema) do
    trie
    |> Inspector.all_values()
    |> Enum.map(&schema.from_rlp(elem(&1, 1)))
  end

  @doc """
  Gets a single record.
  """
  def get(trie, schema, key) do
    case Trie.get(trie, key) do
      nil -> nil
      rlp -> schema.from_rlp(rlp)
    end
  end

  @doc """
  Creates/updates a record.
  """
  def write(trie, schema, %{} = record), do: write(trie, schema, Map.to_list(record))

  @doc """
  Creates/updates a record.
  """
  def write(trie, schema, attrs) do
    record = struct(schema, attrs)
    trie = Trie.update(trie, Record.key(record), ExRLP.encode(record))
    {:ok, trie, record}
  end

  @doc """
  Creates/updates list of records.
  """
  def write_list(trie, schema, records) do
    {:ok, trie, _record} = Enum.reduce(records, {:ok, trie, nil}, &write(elem(&2, 1), schema, &1))
    {:ok, trie, records}
  end

  @doc """
  Deletes a record.
  """
  def delete(trie, record) do
    trie = Trie.delete(trie, Record.key(record))
    {:ok, trie, record}
  end

  @doc """
  Deletes list of records.
  """
  def delete_list(trie, records) do
    {:ok, trie, _record} = Enum.reduce(records, {:ok, trie, nil}, &delete(elem(&2, 1), &1))
    {:ok, trie, records}
  end
end
