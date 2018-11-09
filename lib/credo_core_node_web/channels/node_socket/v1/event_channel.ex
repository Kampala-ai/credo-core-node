defmodule CredoCoreNodeWeb.NodeSocket.V1.EventChannel do
  use Phoenix.Channel

  require Logger

  alias CredoCoreNode.Blockchain
  alias CredoCoreNode.Blockchain.Block
  alias CredoCoreNode.Pool
  alias CredoCoreNode.Pool.PendingTransaction
  alias CredoCoreNode.Pool.PendingBlock

  def join("events:all", _message, socket) do
    {:ok, socket}
  end

  def handle_in("pending_transactions:create", %{"rlp" => rlp}, socket) do
    {hash, tx} = decode_rlp(PendingTransaction, rlp)

    Logger.info("Received pending transaction: #{inspect(tx)}")

    unless Pool.get_pending_transaction(hash) || Pool.is_tx_invalid?(tx) do
      Pool.write_pending_transaction(tx)
      Pool.propagate_pending_transaction(tx)
    end

    {:noreply, socket}
  end

  def handle_in("pending_blocks:create", %{"rlp" => rlp}, socket) do
    {hash, blk} = decode_rlp(PendingBlock, rlp)

    Logger.info("Received pending block: #{inspect(blk)}")

    unless Pool.get_pending_block(hash) do
      Pool.write_pending_block(blk)
      case Pool.fetch_pending_block_body(blk) do
        {:ok, _} -> Pool.propagate_pending_block(blk)
        _ -> nil
      end
    end

    {:noreply, socket}
  end

  def handle_in("blocks:create", %{"rlp" => rlp}, socket) do
    {hash, blk} = decode_rlp(Block, rlp)

    Logger.info("Received block: #{inspect(blk)}")

    unless Blockchain.get_block(hash) do
      Blockchain.write_block(blk)
      Blockchain.propagate_block(blk)
    end

    {:noreply, socket}
  end

  defp decode_rlp(schema, rlp) do
    {:libsecp256k1.sha256(rlp), schema.from_rlp(rlp, encoding: :hex)}
  end
end
