defmodule CredoCoreNode.Mining.Slash do
  use Mnesia.Schema,
    table_name: :slashes,
    fields: [:tx_hash, :target_miner_address, :infraction_block_number]

  alias CredoCoreNode.{Accounts, Blockchain, Mining, Pool}

  alias Decimal, as: D

  @slash_penalty_multiplier D.new(0.8)

  # A byzantine behavior proof should be two or more votes signed by the allegedly-byzantine miner for a given block number and voting round.
  def slash_miner(private_key, byzantine_behavior_proof, miner_address) do
    construct_miner_slash_tx(private_key, byzantine_behavior_proof, miner_address)
    |> Pool.propagate_pending_transaction()
  end

  def construct_miner_slash_tx(private_key, byzantine_behavior_proof, to) do
    {:ok, tx} =
      Pool.generate_pending_transaction(private_key, %{
        nonce: Mining.default_nonce(),
        to: to,
        value: 0,
        fee: Mining.default_tx_fee(),
        data:
          "{\"tx_type\" : \"#{Blockchain.slash_tx_type()}\", \"byzantine_behavior_proof\" : #{
            Poison.encode!(byzantine_behavior_proof)
          }}"
      })

    tx
  end

  def maybe_slash_miners(block) do
    block
    |> Blockchain.list_transactions()
    |> get_slashes()
    |> validate_and_slash_miners()
  end

  def get_slashes(txs) do
    Enum.filter(txs, &is_slash(&1))
  end

  def is_slash(tx) do
    String.length(tx.data) > 1 && Poison.decode!(tx.data)["tx_type"] == Blockchain.slash_tx_type()
  end

  def parse_proof(slash) do
    Poison.decode!(slash.data)["byzantine_behavior_proof"]
  end

  def validate_and_slash_miners(slashes) do
    Enum.each(slashes, fn slash ->
      proof = parse_proof(slash)

      if slash_proof_is_valid?(proof) && target_miner_is_unslashed_for_block_number?(slash) do
        execute_slash(slash)
      end
    end)
  end

  def slash_proof_is_valid?(proof) do
    if is_list(proof) && length(proof) > 1 do
      [voteAMap, voteBMap | _] = proof

      if is_map(voteAMap) && is_map(voteBMap) do
        voteAm = for {key, val} <- voteAMap, into: %{}, do: {String.to_atom(key), val}
        voteA = struct(CredoCoreNode.Mining.Vote, voteAm)

        voteBm = for {key, val} <- voteBMap, into: %{}, do: {String.to_atom(key), val}
        voteB = struct(CredoCoreNode.Mining.Vote, voteBm)

        # TODO check vote hashes
        Accounts.payment_address(voteA) == Accounts.payment_address(voteB) &&
          voteA.block_number == voteB.block_number && voteA.voting_round == voteB.voting_round &&
          voteA.block_hash != voteB.block_hash
      else
        false
      end
    else
      false
    end
  end

  def first_vote(slash) do
    proof = parse_proof(slash)
    voteAttributes = for {key, val} <- hd(proof), into: %{}, do: {String.to_atom(key), val}
    struct(CredoCoreNode.Mining.Vote, voteAttributes)
  end

  def target_miner_is_unslashed_for_block_number?(slash) do
    vote = first_vote(slash)

    Mining.list_slashes()
    |> Enum.filter(
      &(&1.target_miner_address == Accounts.payment_address(vote) &&
          &1.infraction_block_number == vote.block_number)
    )
    |> Enum.empty?()
  end

  def execute_slash(slash) do
    slashed_miner = Mining.get_miner(slash.to)

    Mining.write_miner(%{
      slashed_miner
      | stake_amount: D.mult(slashed_miner.stake_amount, @slash_penalty_multiplier)
    })

    vote = first_vote(slash)

    Mining.write_slash(%{
      tx_hash: slash.hash,
      target_miner_address: slash.to,
      infraction_block_number: vote.block_number
    })
  end
end
