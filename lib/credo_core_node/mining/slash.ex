defmodule CredoCoreNode.Mining.Slash do
  use Mnesia.Schema,
    table_name: :slashes,
    fields: [:tx_hash, :target_miner_address, :infraction_block_number]

  alias CredoCoreNode.{Accounts, Blockchain, Mining, Pool}

  alias Decimal, as: D

  @behaviour CredoCoreNode.Adapters.SlashAdapter

  @slash_penalty_multiplier D.new(0.8)

  # A byzantine behavior proof should be two or more votes signed by the allegedly-byzantine miner for a given block number and voting round.
  def generate_slash(private_key, byzantine_behavior_proof, miner_address) do
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
          Poison.encode!(%{
            tx_type: Blockchain.slash_tx_type(),
            byzantine_behavior_proof: byzantine_behavior_proof
          })
      })

    tx
  end

  def maybe_apply_slashes(block) do
    block
    |> Blockchain.list_transactions()
    |> get_slashes()
    |> apply_valid_slashes()
  end

  defp get_slashes(txs) do
    Enum.filter(txs, &is_slash(&1))
  end

  def is_slash(%{data: nil} = _tx), do: false
  def is_slash(%{data: data} = _tx) when not is_binary(data), do: false

  def is_slash(%{data: data} = tx) when is_binary(data) do
    try do
      tx.data =~ "tx_type" && Poison.decode!(tx.data)["tx_type"] == Blockchain.slash_tx_type()
    rescue
      Poison.SyntaxError -> false
    end
  end

  def parse_slash_proof(%{data: nil} = _slash), do: []
  def parse_slash_proof(%{data: data} = _slash) when not is_binary(data), do: []

  def parse_slash_proof(%{data: data} = slash) when is_binary(data) do
    try do
      slash.data =~ "byzantine_behavior_proof" &&
        Poison.decode!(slash.data)["byzantine_behavior_proof"]
    rescue
      Poison.SyntaxError -> []
    end
  end

  def apply_valid_slashes(slashes) do
    Enum.each(slashes, fn slash ->
      proof = parse_slash_proof(slash)

      if valid_slash_proof?(proof) && target_miner_is_unslashed_for_block_number?(slash) do
        apply_slash(slash)
      end
    end)
  end

  def valid_slash_proof?(proof) do
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

  defp first_vote(slash) do
    proof = parse_slash_proof(slash)
    voteAttributes = for {key, val} <- hd(proof), into: %{}, do: {String.to_atom(key), val}
    struct(CredoCoreNode.Mining.Vote, voteAttributes)
  end

  defp target_miner_is_unslashed_for_block_number?(slash) do
    vote = first_vote(slash)

    Mining.list_slashes()
    |> Enum.filter(
      &(&1.target_miner_address == Accounts.payment_address(vote) &&
          &1.infraction_block_number == vote.block_number)
    )
    |> Enum.empty?()
  end

  defp apply_slash(slash) do
    slashed_miner = Mining.get_miner(slash.to)

    Mining.write_miner(%{
      slashed_miner
      | stake_amount: D.mult(slashed_miner.stake_amount, @slash_penalty_multiplier)
    })

    Mining.delete_miner_for_insufficient_stake(slashed_miner)

    vote = first_vote(slash)

    Mining.write_slash(%{
      tx_hash: slash.hash,
      target_miner_address: slash.to,
      infraction_block_number: vote.block_number
    })
  end
end
