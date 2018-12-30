defmodule MPT.RepoManager do
  @moduledoc """
  Merkle Patricia Tree Repo manager.
  """

  require Logger

  alias MerklePatriciaTree.Trie

  @max_attempts 5

  def trie_exists?(dir, name), do: File.exists?("#{File.cwd!()}/leveldb/#{dir}/#{name}")

  def trie(dir, name), do: trie(dir, name, nil)

  def trie(dir, name, nil) do
    path = "#{File.cwd!()}/leveldb/#{dir}/#{name}"

    try do
      path
      |> MerklePatriciaTree.DB.LevelDB.init()
      |> Trie.new()
    rescue
      # Raised by `merkle_patricia_tree` lib if the DB is inaccessible
      MatchError ->
        Logger.warn("MPT init error (new trie): can't access LevelDB at '#{path}'")
        {:error, :db_inaccessible}
    end
  end

  def trie(dir, name, root), do: trie(dir, name, root, 0)

  defp trie(_dir, _name, _root, @max_attempts), do: {:error, :db_inaccessible}

  defp trie(dir, name, root, num_attempts) do
    path = "#{File.cwd!()}/leveldb/#{dir}/#{name}"

    root_raw =
      case Base.decode16(root) do
        {:ok, root_raw} ->
          root_raw

        _ ->
          :invalid_root
      end

    cond do
      root_raw == :invalid_root ->
        {:error, :invalid_root}

      File.exists?(path) ->
        try do
          path
          |> MerklePatriciaTree.DB.LevelDB.init()
          |> Trie.new(root_raw)
        rescue
          # Raised by `merkle_patricia_tree` lib if the DB is inaccessible
          MatchError ->
            Logger.warn(
              "MPT init error (attempt ##{num_attempts + 1}): can't access LevelDB at '#{path}'"
            )

            :timer.sleep(num_attempts * 100)
            trie(dir, name, root, num_attempts + 1)

          # Raised by `merkle_patricia_tree` if root is not a properly encoded hash
          ArgumentError ->
            {:error, :invalid_root}
        end
    end
  end
end
