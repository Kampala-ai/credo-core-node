defmodule CredoCoreNode.Blockchain.BlockProducer do
  alias CredoCoreNode.{Blockchain, Mining, Pool}
  alias CredoCoreNode.Blockchain.BlockValidator
  alias CredoCoreNode.Mining.Coinbase

  alias Decimal, as: D

  require Logger

  @block_production_timeout 10000

  def is_your_turn?(block, _retry_count) when is_nil(block), do: false

  def is_your_turn?(block, retry_count) do
    get_next_block_producer(block, retry_count) == Mining.my_miner()
  end

  def get_produced_block(block) do
    Pool.list_pending_blocks(block.number + 1)
    |> Enum.filter(&is_produced_by_my_miner?(&1))
    |> List.first()
  end

  def is_produced_by_my_miner?(pending_block) do
    case Mining.my_miner() do
      nil ->
        false

      miner ->
        coinbase_tx =
          pending_block
          |> Coinbase.get_coinbase_txs()
          |> List.first()

        case coinbase_tx do
          nil ->
            false

          tx ->
            tx.to == miner.address
        end
    end
  end

  def produce_block(txs \\ nil) do
    batch = txs || Pool.get_batch_of_valid_pending_transactions()

    if length(batch) > 0 do
      batch
      |> Coinbase.add_coinbase_tx()
      |> Pool.generate_pending_block()
      |> elem(1)
      |> Pool.write_pending_block()
      |> elem(1)
      |> Pool.propagate_pending_block()
    else
      {:error, :no_pending_txs}
    end
  end

  def get_next_block_producer(block, retry_count) do
    :rand.seed(:exsplus, {101, retry_count, block.number + 1})

    # TODO: implement a more memory-efficient weighting mechanism.
    miner_addresses =
      for miner <- Mining.list_miners() do
        for _ <- 0..round(D.to_float(miner.stake_amount) * miner.participation_rate) do
          miner.address
        end
      end
      |> Enum.concat()

    miner_addresses
    |> Enum.at(Enum.random(1..length(miner_addresses)))
    |> Mining.get_miner()
  end

  def wait_for_block(block, retry_count) do
    :timer.sleep(@block_production_timeout)

    if next_block = next_block?(block) do
      BlockValidator.validate_block(next_block)
    else
      Mining.start_mining(block, retry_count + 1)
    end
  end

  def next_block?(block) do
    Pool.get_block_by_number(block.number + 1)
  end
end
