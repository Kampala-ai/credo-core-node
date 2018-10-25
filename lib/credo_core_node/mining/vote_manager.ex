defmodule CredoCoreNode.Mining.VoteManager do
  alias CredoCoreNode.{Mining, Network, Pool}

  @vote_collection_timeout 10000

  def already_voted?(block, voting_round) do
    Mining.list_votes()
    |> Enum.filter(&
      &1.block_number == block.number &&
      &1.voting_round == voting_round &&
      &1.miner_address == Mining.my_miner().address)
    |> Enum.any?
  end

  def cast_vote(block, voting_round) do
    block
    |> select_candidate(voting_round)
    |> save_vote(voting_round)
    |> construct_vote(voting_round)
    |> sign_vote()
    |> propagate_vote()
  end

  defp select_candidate(block, voting_round) when voting_round == 0, do: block
  defp select_candidate(block, voting_round) do
    Pool.list_pending_blocks(block.number)
    |> Enum.random() # TODO: weight selection based on votes from prior round.
  end

  def save_vote(candidate, voting_round) do
    Mining.write_vote(%{
      miner_address: Mining.my_miner().address,
      block_number: candidate.number,
      block_hash: candidate.hash,
      voting_round: voting_round
      })

    candidate
  end

  def construct_vote(candidate, voting_round) do
    "{\"block_hash\" : #{candidate.hash},
      \"block_number\" : #{candidate.number},
      \"voting_round\" : \"#{voting_round}\",
      \"miner_address\" : #{Mining.my_miner().address}}"
  end

  def sign_vote(vote) do
    vote
  end

  def propagate_vote(vote) do
    headers = Network.node_request_headers()

    Mining.list_miners()
    |> Enum.map(&("#{Network.request_url(&1.ip)}/node_api/v1/temp/votes"))
    |> Enum.each(&(:hackney.request(:post, &1, headers, vote, [:with_body, pool: false])))

    {:ok, vote}
  end

  def wait_for_votes do
    :timer.sleep(@vote_collection_timeout)
  end

  def consensus_reached?(block, voting_round) do
    confirmed_block =
      count_votes(block, voting_round)
      |> get_winner()

    update_participation_rates(block, voting_round)

    if confirmed_block do
      Pool.propagate_block(confirmed_block, :all)

      {:ok, confirmed_block}
    else
      Mining.start_voting(block, voting_round + 1)
    end
  end

  def count_votes(block, voting_round) do
    votes =
      Mining.list_votes_for_round(block, voting_round)

    Enum.map votes, fn vote ->
      count =
        votes
        |> Enum.filter(& &1.block_hash == vote.block_hash)
        |> Enum.map(& Mining.get_miner(&1.miner_address).stake_amount)
        |> Enum.sum()

      %{hash: vote.block_hash, count: count}
    end
  end

  def total_voting_power do
    stake_amounts = for %{stake_amount: stake_amount} <- Mining.list_miners(), do: stake_amount
    Enum.reduce(stake_amounts, fn x, acc -> D.add(x, acc) end)
  end

  def has_supermajority?(num_votes) do
    num_votes >= 2/3 * total_voting_power()
  end

  def get_winner(results) do
    winning_result =
      results
      |> Enum.filter(fn result -> has_supermajority?(result.count) end)
      |> List.first()

    if is_nil(winning_result) do
      nil
    else
      Pool.get_pending_block(winning_result.hash)
    end
  end

  def update_participation_rates(block, voting_round) do
    votes =
      Mining.list_votes_for_round(block, voting_round)

    Enum.each Mining.list_miners(), fn miner ->
      rate = if miner_voted?(votes, miner), do: max(miner.participation_rate + 0.01, 1), else: min(miner.participation_rate - 0.01, 0)

      miner
      |> Map.merge( %{participation_rate: rate})
      |> Mining.write_miner()
    end
  end

  def miner_voted?(votes, miner) do
    votes
    |> Enum.filter(& &1.miner_address == miner.address)
    |> Enum.any?
  end
end