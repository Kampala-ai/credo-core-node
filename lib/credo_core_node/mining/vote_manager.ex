defmodule CredoCoreNode.Mining.VoteManager do
  alias CredoCoreNode.{Accounts, Mining, Network, Pool, Blockchain}
  alias CredoCoreNode.Mining.Vote

  alias Decimal, as: D

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
    |> construct_vote(voting_round)
    |> sign_vote()
    |> save_vote()
    |> propagate_vote()
  end

  def select_candidate(block, voting_round) when voting_round == 0, do: block
  def select_candidate(block, voting_round) do
    Pool.list_pending_blocks(block.number)
    |> Enum.random() # TODO: weight selection based on votes from prior round.
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
    account =
      Accounts.get_account(vote.miner_address)

    Pool.sign_message(account.private_key, vote)
  end

  def save_vote(vote) do
    {:ok, vote} = Mining.write_vote(vote)

    vote
  end

  def propagate_vote(vote, options \\ []) do
    Network.propagate_record(vote, options)

    {:ok, vote}
  end

  def wait_for_votes do
    :timer.sleep(@vote_collection_timeout)
  end

  def consensus_reached?(block, voting_round) do
    winner_block =
      count_votes(block, voting_round)
      |> get_winner()
      |> Pool.load_pending_block_body()

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

  def count_votes(block, voting_round) do
    votes =
      Mining.list_votes_for_round(block, voting_round)
      |> get_valid_votes()

    Enum.map votes, fn vote ->
      count =
        votes
        |> Enum.filter(& &1.block_hash == vote.block_hash)
        |> Enum.map(& Mining.get_miner(&1.miner_address).stake_amount)
        |> Enum.reduce(fn x, acc -> D.add(x, acc) end)

      %{hash: vote.block_hash, count: count}
    end
  end

  def get_valid_votes(votes) do
    Enum.filter(votes, & is_valid_vote(&1))
  end

  def is_valid_vote(vote) do
    {:ok, public_key} =
      Accounts.calculate_public_key(vote)

    address =
      Accounts.payment_address(public_key)

    address == vote.miner_address && !is_nil(Mining.get_miner(vote.miner_address))
  end

  def total_voting_power do
    stake_amounts = for %{stake_amount: stake_amount} <- Mining.list_miners(), do: stake_amount
    Enum.reduce(stake_amounts, fn x, acc -> D.add(x, acc) end)
  end

  def has_supermajority?(num_votes) do
    D.cmp(num_votes, D.mult(D.new(2/3), total_voting_power())) != :lt
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
