defmodule CredoCoreNodeWeb.NodeSocket.V1.EventChannel do
  require Logger

  use Phoenix.Channel

  import CredoCoreNodeWeb.NodeSocket.V1.EventHandler

  alias CredoCoreNode.Network
  alias CredoCoreNode.Blockchain
  alias CredoCoreNode.Blockchain.{Block, BlockFragment, Transaction}
  alias CredoCoreNode.Pool
  alias CredoCoreNode.Pool.{PendingBlock, PendingBlockFragment, PendingTransaction}
  alias MerklePatriciaTree.Trie

  def join("events:all", _message, socket) do
    {:ok, socket}
  end

  def handle_in(
        "blocks:body_fragment_transfer",
        %{"hash" => hash, "body_fragment" => nil},
        socket
      ) do
    Logger.info("Received empty (final) body fragment for block #{hash}")

    frg = Blockchain.get_block_fragment(hash) || %BlockFragment{hash: hash, body: ""}

    case Base.decode64(frg.body) do
      {:ok, ""} ->
        Logger.warn("Empty body for block #{hash} received, ignoring")

      {:ok, body} ->
        Logger.info("Body for block #{hash} decoded")

        blk = Blockchain.get_block(hash)

        if valid_block_hash?(blk, hash) && valid_block_body?(blk, body) do
          Logger.info("Writing block #{hash}")

          blk
          |> Map.put(:body, body)
          |> Blockchain.write_block()
        else
          Logger.info("Invalid block #{hash}, ignoring")
        end

      _ ->
        Logger.warn("Uprocessable body for block #{hash} received, ignoring")
    end

    Blockchain.delete_block_fragment(frg)

    {:noreply, socket}
  end

  def handle_in(
        "blocks:body_fragment_transfer",
        %{"hash" => hash, "body_fragment" => body_fragment},
        socket
      ) do
    Logger.info("Received body fragment for block #{hash}")

    frg = Blockchain.get_block_fragment(hash) || %BlockFragment{hash: hash, body: ""}
    Blockchain.write_block_fragment(%{frg | body: frg.body <> body_fragment})

    {:noreply, socket}
  end

  def handle_in(
        "pending_blocks:body_fragment_transfer",
        %{"hash" => hash, "body_fragment" => nil},
        socket
      ) do
    Logger.info("Received empty (final) body fragment for pending block #{hash}")

    frg = Pool.get_pending_block_fragment(hash) || %PendingBlockFragment{hash: hash, body: ""}

    case Base.decode64(frg.body) do
      {:ok, ""} ->
        Logger.warn("Empty body for pending block #{hash} received, ignoring")

      {:ok, body} ->
        Logger.info("Body for pending_block #{hash} decoded")

        blk = Pool.get_pending_block(hash)

        if valid_block_hash?(blk, hash) && valid_block_body?(blk, body) do
          Logger.info("Writing pending_block #{hash}")

          blk
          |> Map.put(:body, body)
          |> Pool.write_pending_block()
        else
          Logger.info("Invalid pending_block #{hash}, ignoring")
        end

      _ ->
        Logger.warn("Uprocessable body for pending block #{hash} received, ignoring")
    end

    Pool.delete_pending_block_fragment(frg)

    {:noreply, socket}
  end

  def handle_in(
        "pending_blocks:body_fragment_transfer",
        %{"hash" => hash, "body_fragment" => body_fragment},
        socket
      ) do
    Logger.info("Received body fragment for pending block #{hash}")

    frg = Pool.get_pending_block_fragment(hash) || %PendingBlockFragment{hash: hash, body: ""}
    Pool.write_pending_block_fragment(%{frg | body: frg.body <> body_fragment})

    {:noreply, socket}
  end

  def handle_in(
        "known_nodes:list_fragment_transfer",
        %{"list_fragment" => list_fragment},
        socket
      ) do
    Logger.info("Received known nodes list fragment")

    Network.merge_known_nodes(list_fragment)

    {:noreply, socket}
  end

  # TODO: refactor block hash/body validation functions for better performance and move to a
  #   separate module (e.g. BlockValidator)
  defp valid_block_hash?(nil, _hash), do: false
  defp valid_block_hash?(%{hash: blk_hash}, hash) when blk_hash != hash, do: false
  defp valid_block_hash?(blk, hash), do: RLP.Hash.hex(blk) == hash

  defp valid_block_body?(nil, _body), do: false

  defp valid_block_body?(%Block{} = blk, body),
    do: valid_block_body?(blk, body, Transaction)

  defp valid_block_body?(%PendingBlock{} = blk, body),
    do: valid_block_body?(blk, body, PendingTransaction)

  defp valid_block_body?(blk, body, tx_module) do
    try do
      txs =
        body
        |> ExRLP.decode()
        |> Enum.map(&tx_module.from_list(&1, type: :rlp_default))

      valid_block_transactions?(blk, txs, tx_module)
    rescue
      # Body is not properly RLP-encoded
      ArgumentError -> false
    end
  end

  defp valid_block_transactions?(_blk, [], _tx_module), do: false

  defp valid_block_transactions?(blk, txs, tx_module) when is_list(txs) do
    {:ok, tx_trie, _txs} =
      MerklePatriciaTree.DB.ETS.random_ets_db()
      |> Trie.new()
      |> MPT.Repo.write_list(tx_module, txs)

    tx_root = Base.encode16(tx_trie.root_hash)

    blk.tx_root == tx_root
  end

  defp valid_block_transactions?(_blk, _invalid_arg, _tx_module), do: false
end
