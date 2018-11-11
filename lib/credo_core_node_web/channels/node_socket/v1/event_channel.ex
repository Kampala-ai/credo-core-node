defmodule CredoCoreNodeWeb.NodeSocket.V1.EventChannel do
  use Phoenix.Channel

  require Logger

  alias CredoCoreNode.Blockchain
  alias CredoCoreNode.Blockchain.Block
  alias CredoCoreNode.Pool
  alias CredoCoreNode.Pool.PendingTransaction
  alias CredoCoreNode.Pool.PendingBlock
  alias CredoCoreNodeWeb.Endpoint

  def join("events:all", _message, socket) do
    {:ok, socket}
  end

  def handle_in(
        "pending_transactions:create",
        %{"rlp" => rlp, "session_ids" => session_ids},
        socket
      ) do
    {hash, tx} = decode_rlp(PendingTransaction, rlp)

    Logger.info("Received pending transaction: #{inspect(tx)}")

    if !Pool.get_pending_transaction(hash) && !Pool.is_tx_invalid?(tx) &&
         !already_processed?(session_ids) do
      Logger.info("Writing pending transaction and propagating further...")
      Pool.write_pending_transaction(tx)
      Pool.propagate_pending_transaction(tx)
    end

    {:noreply, socket}
  end

  def handle_in("pending_blocks:create", %{"rlp" => rlp, "session_ids" => session_ids}, socket) do
    {hash, blk} = decode_rlp(PendingBlock, rlp)

    Logger.info("Received pending block: #{inspect(blk)}")

    if !Pool.get_pending_block(hash) && !already_processed?(session_ids) do
      Logger.info("Writing pending block and propagating further...")
      Pool.write_pending_block(blk)

      case Pool.fetch_pending_block_body(blk) do
        {:ok, _} -> Pool.propagate_pending_block(blk)
        _ -> nil
      end
    end

    {:noreply, socket}
  end

  def handle_in("blocks:create", %{"rlp" => rlp, "session_ids" => session_ids}, socket) do
    {hash, blk} = decode_rlp(Block, rlp)

    Logger.info("Received block: #{inspect(blk)}")

    if !Blockchain.get_block(hash) && !already_processed?(session_ids) do
      Logger.info("Writing block and propagating further...")
      Blockchain.write_block(blk)

      case Blockchain.fetch_block_body(blk) do
        {:pk, _} -> Blockchain.propagate_block(blk)
        _ -> nil
      end
    end

    {:noreply, socket}
  end

  defp already_processed?(session_ids) do
    Endpoint.config(:session_id) in session_ids
  end

  defp decode_rlp(schema, rlp) do
    {:libsecp256k1.sha256(rlp), schema.from_rlp(rlp, encoding: :hex)}
  end
end
