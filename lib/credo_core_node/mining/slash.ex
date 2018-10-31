defmodule CredoCoreNode.Mining.Slash do
  alias CredoCoreNode.{Accounts, Blockchain, Mining, Pool}

  @slash_penalty_percentage 20

  def slash_miner(private_key, byzantine_behavior_proof, miner_address) do #A byzantine behavior proof should be two or more votes signed by the allegedly-byzantine miner for a given block number and voting round.
    construct_miner_slash_tx(private_key, byzantine_behavior_proof, miner_address)
    |> Pool.propagate_pending_transaction()
  end

  def construct_miner_slash_tx(private_key, byzantine_behavior_proof, to) do
    {:ok, tx} =
      Pool.generate_pending_transaction(private_key,  %{
        nonce: Mining.default_nonce(),
        to: to,
        value: 0,
        fee: Mining.default_tx_fee(),
        data: "{\"tx_type\" : \"#{Blockchain.slash_tx_type()}\", \"byzantine_behavior_proof\" : \"#{byzantine_behavior_proof}\"}"
      })

    tx
  end

  def maybe_slash_miners(block) do
    block.transactions
    |> get_slashes()
    |> validate_slashes()
    |> slash_miners()
  end

  def get_slashes(txs) do
    Enum.filter(txs, & is_slash(&1))
  end

  def is_slash(tx) do
    Poison.decode!(tx.data)["tx_type"] == Blockchain.slash_tx_type()
  end

  def validate_slashes(slashes) do
    Enum.each slashes, fn slash ->
      proof = Poison.decode!(slash.data)["byzantine_behavior_proof"]

      if slash_proof_is_valid?(proof) do # TODO: check that the miner wasn't already slashed for that block number.
        slash
      end
    end
  end

  def slash_proof_is_valid?(proof) do
    if is_list(proof) && length(proof) > 1 do
      [voteA, voteB | _] = proof

      Accounts.payment_address(voteA) == Accounts.payment_address(voteB) &&
        voteA.block_number == voteB.block_number &&
        voteA.voting_round == voteB.voting_round &&
        voteA.block_hash != voteB.block_hash # TODO check vote hashes
    else
      false
    end
  end

  def slash_miners(slashes) do
    Enum.each slashes, fn slash ->
      slashed_miner = Mining.get_miner(slash.miner_address)

      Mining.write_miner(%{slashed_miner | stake_amount: slashed_miner.stake_amount * (1 - @slash_penalty_percentage)})
    end
  end
end
