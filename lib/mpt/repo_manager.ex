defmodule MPT.RepoManager do
  @moduledoc """
  Merkle Patricia Tree Repo manager.
  """

  require Logger

  alias CredoCoreNode.Blockchain.Block
  alias CredoCoreNode.Pool.PendingBlock
  alias MerklePatriciaTree.Trie

  @max_attempts 5

  def trie_exists?(dir, name), do: File.exists?("#{File.cwd!()}/leveldb/#{dir}/#{name}")

  def trie(dir, name, root), do: trie(dir, name, root, 0)

  defp trie(dir, name, root, @max_attempts), do: nil

  defp trie(dir, name, root, num_attempts) do
    path = "#{File.cwd!()}/leveldb/#{dir}/#{name}"
    {:ok, root_raw} = Base.decode16(root)

    if File.exists?(path) do
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
      end
    end
  end
end
