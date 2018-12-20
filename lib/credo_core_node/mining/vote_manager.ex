defmodule CredoCoreNode.Mining.VoteManager do
  alias CredoCoreNode.{Accounts, Mining, Network, Pool, Blockchain}
  alias CredoCoreNode.Mining.Vote

  alias Decimal, as: D

  @vote_collection_timeout 500
  @quorum_size 1
  @early_vote_counting_threshold 50
  @num_seconds_for_voter_probation_period 48 * 60 * 60

  def already_voted?(block, voting_round) do
    Mining.list_votes()
    |> Enum.filter(
      &(&1.block_number == block.number && &1.voting_round == voting_round &&
          &1.miner_address == Mining.my_miner().address)
    )
    |> Enum.any?()
  end

  def cast_vote(block, voting_round) do
    block
    |> select_candidate(voting_round)
    |> construct_vote(voting_round)
    |> sign_vote()
    |> hash_vote()
    |> save_vote()
    |> propagate_vote()
  end

  def select_candidate(block, voting_round) when voting_round == 0, do: block

  def select_candidate(block, voting_round) do
    # TODO: weight selection based on votes from prior round.
    Pool.list_pending_blocks(block.number)
    |> Enum.random()
  end

  def construct_vote(candidate, voting_round) do
    %Vote{
      miner_address: Mining.my_miner().address,
      block_number: candidate.number,
      block_hash: RLP.Hash.hex(candidate),
      voting_round: voting_round
    }
  end

  def sign_vote(vote) do
    account = Accounts.get_account(vote.miner_address)

    Pool.sign_message(account.private_key, vote)
  end

  def hash_vote(vote), do: %Vote{vote | hash: RLP.Hash.hex(vote)}

  def save_vote(vote) do
    {:ok, vote} = Mining.write_vote(vote)

    vote
  end

  def propagate_vote(vote, options \\ []) do
    Network.propagate_record(vote, options)

    {:ok, vote}
  end

  def wait_for_votes(_, _, intervals) when intervals == 0, do: :ok

  def wait_for_votes(block, voting_round, intervals) do
    unless can_count_votes_early?(block, voting_round) do
      :timer.sleep(@vote_collection_timeout)

      wait_for_votes(block, voting_round, intervals - 1)
    end
  end

  def can_count_votes_early?(block, voting_round) do
    length(get_valid_votes_for_block_and_round(block, voting_round)) >=
      @early_vote_counting_threshold
  end

  def consensus_reached?(block, voting_round) do
    valid_votes = get_valid_votes_for_block_and_round(block, voting_round)

    winner_block =
      if length(valid_votes) >= @quorum_size do
        valid_votes
        |> count_votes()
        |> get_winner(valid_votes)
        |> Pool.load_pending_block_body()
      end

    update_participation_rates(block, voting_round)

    if winner_block do
      {:ok, confirmed_block} =
        CredoCoreNode.Blockchain.Block
        |> struct(Map.to_list(winner_block))
        |> Blockchain.write_block()

      Blockchain.propagate_block(confirmed_block)

      {:ok, confirmed_block}
    else
      Mining.start_voting(block, voting_round + 1)
    end
  end

  def count_votes(votes) do
    Enum.map(votes, fn vote ->
      count =
        votes
        |> Enum.filter(&(&1.block_hash == vote.block_hash))
        |> Enum.map(&Mining.get_miner(&1.miner_address).stake_amount)
        |> Enum.reduce(fn x, acc -> D.add(x, acc) end)

      %{hash: vote.block_hash, count: count}
    end)
  end

  def get_valid_votes_for_block_and_round(block, voting_round) do
    block
    |> Mining.list_votes_for_round(voting_round)
    |> get_valid_votes()
  end

  def get_valid_votes(votes) do
    Enum.filter(votes, &is_valid_vote(&1))
  end

  def is_valid_vote(vote) do
    {:ok, public_key} = Accounts.calculate_public_key(vote)

    address = Accounts.payment_address(public_key)

    voter = Mining.get_miner(vote.miner_address)

    address == vote.miner_address && !is_nil(voter) &&
      voter_has_completed_probationary_period?(voter)
  end

  def voter_has_completed_probationary_period?(voter) do
    is_nil(voter.inserted_at) ||
      DateTime.diff(DateTime.utc_now(), voter.inserted_at) >
        @num_seconds_for_voter_probation_period
  end

  def total_voting_power(votes) do
    voting_miner_addresses = Enum.map(votes, & &1.miner_address)

    Mining.list_miners()
    |> Enum.filter(&Enum.member?(voting_miner_addresses, &1.address))
    |> Enum.reduce(D.new(0), fn miner, acc -> D.add(miner.stake_amount, acc) end)
  end

  def has_supermajority?(num_votes, votes) do
    D.cmp(num_votes, D.mult(D.new(2 / 3), total_voting_power(votes))) != :lt
  end

  def get_winner(results, votes) do
    winning_result =
      results
      |> Enum.filter(fn result -> has_supermajority?(result.count, votes) end)
      |> List.first()

    if is_nil(winning_result) do
      nil
    else
      Pool.get_pending_block(winning_result.hash)
    end
  end

  def update_participation_rates(block, voting_round) do
    votes = Mining.list_votes_for_round(block, voting_round)

    Enum.each(Mining.list_miners(), fn miner ->
      rate =
        if miner_voted?(votes, miner),
          do: min(miner.participation_rate + 0.01, 1),
          else: max(miner.participation_rate - 0.01, 0)

      miner
      |> Map.merge(%{participation_rate: rate})
      |> Mining.write_miner()
    end)
  end

  def miner_voted?(votes, miner) do
    votes
    |> Enum.filter(&(&1.miner_address == miner.address))
    |> Enum.any?()
  end

  def get_current_voting_round(block) do
    highest_vote =
      Mining.list_votes()
      |> Enum.filter(&(&1.block_number == block.number))
      |> Enum.sort(&(&1.voting_round >= &2.voting_round))
      |> List.first()

    case highest_vote do
      nil ->
        0

      vote ->
        vote.voting_round + 1
    end
  end
end
