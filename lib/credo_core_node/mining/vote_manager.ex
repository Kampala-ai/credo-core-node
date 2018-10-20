defmodule CredoCoreNode.Mining.VoteManager do
  @moduledoc """
  The vote managers module.
  """

  alias CredoCoreNode.Network
  alias CredoCoreNode.Pool
  alias CredoCoreNode.Mining

  @vote_collection_timeout 10000

  @doc """
  Votes to validate the block via network consensus.
  """
  def vote(block_number, voting_round \\ 0) do
    block = select_candidate_block_to_vote_for(block_number)
    miner = Mining.get_own_miner()

    unless already_voted?(block, voting_round, miner) do
      cast_vote(block, voting_round, miner)

      :timer.sleep(@vote_collection_timeout)

      count_votes(block, voting_round)
      |> determine_winner_or_vote_again(block, voting_round)
    end
  end

  @doc """
  Selects a candidate block to vote for in this round.

  # TODO: take into account other votes if a prior round was held for this block number.
  """
  def select_candidate_block_to_vote_for(number) do
    Pool.list_pending_blocks(number)
    |> Enum.random()
  end

  @doc """
  Checks whether a miner already voted for a block in the current round.
  """
  def already_voted?(block, voting_round, miner) do
    Mining.list_votes()
    |> Enum.filter(& &1.block_height == block.number)
    |> Enum.filter(& &1.voting_round == voting_round)
    |> Enum.filter(& &1.miner_address == miner.address)
    |> Enum.any?
  end

  @doc """
  Construct and broadcast vote to other miners.
  """
  def cast_vote(block, voting_round, miner) do
    vote = "{\"block_hash\" : #{block.hash}, \"block_height\" : #{block.number}, \"voting_round\" : \"#{voting_round}\", \"miner_address\" : #{miner.address}}"

    sign_vote(vote)

    broadcast_vote_to_miners(vote)
  end

  @doc """
  Signs the vote.
  """
  def sign_vote(vote) do
    vote
  end

  @doc """
  Broadcasts the vote to other miners
  """
  def broadcast_vote_to_miners(vote) do
    # TODO: temporary REST implementation, to be replaced with channels-based one later
    headers = Network.node_request_headers()
    body = vote

    Mining.list_miners()
    |> Enum.map(&("#{Network.request_url(&1.ip)}/node_api/v1/temp/votes"))
    |> Enum.each(&(:hackney.request(:post, &1, headers, body, [:with_body, pool: false])))

    {:ok, vote}
  end

  @doc """
  Count votes using a stake-weighted sum.
  """
  def count_votes(block, voting_round) do
    votes = Mining.list_votes_for_round(block, voting_round)
    results = %{}

    for vote <- votes do
      miner =
        Mining.get_miner(vote.miner_address)

      previous_vote_count = results[vote.block_hash] || 0

      Map.merge(results, %{"#{vote.block_hash}": previous_vote_count + miner.stake_amount})
    end
  end

  @doc """
  Determine whether a winner has emerged from the voting using a 2/3rd threshold.
  Start another voting round if there is insufficient consensus.
  """
  def determine_winner_or_vote_again(results, block, voting_round) do
    confirmed_block_hash = nil
    for block_hash <- Map.keys(results) do
      if results[block_hash] >= (2.0 / 3) * total_voting_power() do
        broadcast_confirmed_block(block_hash)

        confirmed_block_hash = block_hash

        update_miner_participation_rates(block, voting_round)
      end
    end

    if is_nil(confirmed_block_hash) do
      vote(block, voting_round + 1)
    end
  end

  @doc """
  Calculate the total voting power among miners.
  """
  def total_voting_power do
    for %{stake_amount: stake_amount, id: _} <- Mining.list_miners(), do: stake_amount
  end

  @doc """
  Broadcast the confimed block to all peers, including non-miners.
  """
  def broadcast_confirmed_block(hash) do
  end

  @doc """
  Updates miner participation rates based on a set of votes.

  To be called after voting has concluded for a block.
  """
  def update_miner_participation_rates(block, voting_round) do
    votes =
      Mining.list_votes_for_round(block, voting_round)

    for miner <- Mining.list_miners() do
      participation_rate =
        if miner_voted?(votes, miner) do
          miner.participation_rate + 1
        else
          miner.participation_rate - 1
        end

      miner
      |> Map.merge(%{participation_rate: participation_rate})
      |> Mining.write_miner()
    end
  end

  @doc """
  Checks whether a miner voted
  """
  def miner_voted?(votes, miner) do
    votes
    |> Enum.filter(& &1.miner_address == miner.address)
    |> Enum.any?
  end
end