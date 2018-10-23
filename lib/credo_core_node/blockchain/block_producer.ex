defmodule CredoCoreNode.Blockchain.BlockProducer do
  alias CredoCoreNode.{Blockchain, Mining, Pool}
  alias CredoCoreNode.Blockchain.BlockValidator

  require Logger

  @block_production_timeout 10000

  def is_your_turn?(block, retry_count) do
    get_next_block_producer(block, retry_count) == Mining.my_miner()
  end

  def produce_block() do
    Pool.get_batch_of_pending_transactions()
    |> add_coinbase_tx()
    |> Pool.generate_pending_block()
    |> Pool.propagate_block()
  end

  def add_coinbase_tx(txs) do
    {:ok, tx} =
      Pool.generate_pending_transaction("", %{ # TODO: set private key
        nonce: 0,
        to: Mining.my_miner().address,
        value: Pool.sum_pending_transaction_fees(txs),
        fee: 0,
        data: "{\"tx_type\" : \"#{Blockchain.coinbase_tx_type()}\"}"
      })

    txs ++ [tx]
  end

  def get_next_block_producer(block, retry_count) do
    :rand.seed(:exsplus, {101, retry_count, block.number + 1})

    miner_addresses =
      for miner <- Mining.list_miners() do
        for _ <- 0..round(miner.stake_amount * miner.participation_rate) do
          miner.address
        end
      end
      |> Enum.concat # TODO: implement a more memory-efficient weighting mechanism.

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