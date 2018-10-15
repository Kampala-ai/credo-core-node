defmodule CredoCoreNode.Validation do
  @moduledoc """
  The Validation context.
  """

  alias CredoCoreNode.Blockchain
  alias CredoCoreNode.Network
  alias CredoCoreNode.Pool
  alias CredoCoreNode.SecurityDeposits
  alias CredoCoreNode.Validation.Validator
  alias CredoCoreNode.Validation.Vote

  alias Mnesia.Repo

  @min_stake_size 10000
  @default_nonce 0
  @default_tx_fee 0.1

  def default_nonce do
    @default_nonce
  end

  def default_tx_fee do
    @default_tx_fee
  end

  def min_stake_size do
    @min_stake_size
  end

  @doc """
  Makes a node become a validator.

  amount is the security deposit size
  to is the address in which the security deposit will be held
  timelock is the duration that the security deposit will be deposited for
  """
  def become_validator(amount, private_key, to, timelock \\ nil) do
    unless is_validator?() do
      SecurityDeposits.construct_security_deposit(amount, private_key, to, timelock)
      |> SecurityDeposits.broadcast_security_deposit()
    end
  end

  @doc """
  Deletes a validator when it has an insufficient stake.

  This should be called after a validator has been slashed and after a security deposit withdrawal has occurred.
  """
  def delete_validator_for_insufficient_stake(validator) do
    if validator.stake_amount < @min_stake_size do
      delete_validator(validator)
    end
  end

  @doc """
  Check whether the node's ip has changed compared with the validator state
  """
  def validator_ip_changed? do
    Network.get_current_ip != get_own_validator().node_ip
  end

  @doc """
  Update the validator's ip if it has changed.
  """
  def maybe_update_validator_ip do
    if is_validator?() && validator_ip_changed?() do
      private_key = "" #TODO get actual private key

      construct_validator_ip_update_transaction(private_key, get_own_validator().address)
      |> broadcast_validator_ip_update_transaction()
    end
  end

  @doc """
  Constructs a security deposit transaction.
  """
  def construct_validator_ip_update_transaction(private_key, to) do
    ip = Network.get_current_ip()

    attrs = %{nonce: @default_nonce, to: to, value: 0 , fee: @default_tx_fee, data: "{\"tx_type\" : \"update_validator_ip\", \"node_ip\" : \"#{ip}\"}"}

    {:ok, tx} = Pool.generate_pending_transaction(private_key, attrs)

    tx
  end

  @doc """
  Broadcasts a validator ip update transaction.
  """
  def broadcast_validator_ip_update_transaction(tx) do
    Pool.propagate_pending_transaction(tx)
  end

  @doc """
  Returns whether the current node is already a validator.
  """
  def get_own_validator() do
    list_validators()
    |> Enum.filter(& &1.is_self)
    |> List.first()
  end

  @doc """
  Returns whether the current node is already a validator.
  """
  def is_validator?() do
    list_validators()
    |> Enum.filter(& &1.is_self)
    |> Enum.any?
  end

  @doc """
  Returns the list of validators.
  """
  def list_validators() do
    Repo.list(Validator)
  end

  @doc """
  Returns the number of validators.
  """
  def count_validators() do
    length(Repo.list(Validator))
  end

  @doc """
  Gets a single validator.
  """
  def get_validator(address) do
    Repo.get(Validator, address)
  end

  @doc """
  Creates/updates a validator.
  """
  def write_validator(attrs) do
    Repo.write(Validator, attrs)
  end

  @doc """
  Deletes a validator.
  """
  def delete_validator(%Validator{} = validator) do
    Repo.delete(validator)
  end

  @doc """
  Checks whether a transaction is a validator ip update transaction
  """
  def is_validator_ip_update_transactions(tx) do
    Poison.decode!(tx.data)["tx_type"] == "update_validator_ip"
  end

  @doc """
  Returns validator ip update transactions from a list of transactions
  """
  def get_validator_ip_update_transactions(txs) do
    txs
    |> Enum.filter(& is_validator_ip_update_transactions(&1))
  end

  @doc """
  Validates ip update transactions by checking that they are signed by the security deposit owner.
  """
  def validate_validator_ip_update_transactions(txs) do
    txs #TODO implement signature check.
  end

  @doc """
  Updates state of validator ip based on the transaction data.
  """
  def process_validator_ip_update_transactions(txs) do
    for tx <- txs do
      node_ip = Poison.decode!(tx.data)["node_ip"]

      tx.to
      |> get_validator()
      |> Map.merge(%{node_ip: node_ip})
      |> write_validator()
    end
  end

  @doc """
  Retrieves, validates, and processes validator ip update transactions.

  To be called after a block is confirmed.
  """
  def maybe_validate_validator_ip_update_transactions(txs) do
    txs
    |> get_validator_ip_update_transactions()
    |> validate_validator_ip_update_transactions()
    |> process_validator_ip_update_transactions()
  end

  @doc """
  Returns the list of votes.
  """
  def list_votes() do
    Repo.list(Vote)
  end

  @doc """
  Returns the list of votes for a given round.
  """
  def list_votes_for_round(voting_round) do
    list_votes()
    |> Enum.filter(& &1.voting_round == voting_round)
  end

  @doc """
  Gets a single vote.
  """
  def get_vote(block_hash) do
    Repo.get(Vote, block_hash)
  end

  @doc """
  Creates/updates a vote.
  """
  def write_vote(attrs) do
    Repo.write(Vote, attrs)
  end

  @doc """
  Deletes a vote.
  """
  def delete_vote(%Vote{} = vote) do
    Repo.delete(vote)
  end

  @doc """
  Checks whether a validator voted
  """
  def validator_voted?(votes, validator) do
    votes
    |> Enum.filter(& &1.validator_address == validator.address)
    |> Enum.any?
  end

  @doc """
  Updates validator participation rates based on a set of votes.

  To be called after voting has concluded for a block.
  """
  def update_validator_participation_rates(votes) do
    for validator <- list_validators() do
      participation_rate =
        if validator_voted?(votes, validator) do
          validator.participation_rate + 1
        else
          validator.participation_rate - 1
        end

      validator
      |> Map.merge(%{participation_rate: participation_rate})
      |> write_validator()
    end
  end

  @doc """
  Selects a candidate block to vote for in this round.

  #TODO take into account other votes if a prior round was held for this block number.
  """
  def select_candidate_block_to_vote_for(number) do
    Blockchain.list_block_candidates(number)
    |> Enum.random()
  end

  @doc """
  Broadcasts the vote to other validators
  """
  def broadcast_vote_to_validators(vote) do
  end

  @doc """
  Signs the vote.
  """
  def sign_vote(vote) do
    vote
  end

  @doc """
  Construct and broadcast vote to other validators.
  """
  def cast_vote(block, validator) do
    vote = "{\"number\" : #{block.number}, \"voting_round\" : 0, \", \"validator_address\" : #{validator.address}"

    sign_vote(vote)

    broadcast_vote_to_validators(vote)
  end

  @doc """
  Count votes using a stake-weighted sum.
  """
  def count_votes do
    votes = list_votes_for_round(0)
    results = %{}

    for vote <- votes do
      validator =
        get_validator(vote.validator_address)

      previous_vote_count = results[vote.block_hash] || 0

      Map.merge(results, %{"#{vote.block_hash}": previous_vote_count + validator.stake_amount})
    end
  end

  @doc """
  Calculate the total voting power among validators.
  """
  def total_voting_power do
  end

  @doc """
  Initiate another round of voting.
  """
  def vote_again do
  end

  @doc """
  Determine whether a winner has emerged from the voting using a 2/3rd threshold.
  Start another voting round if there is insufficient consensus.
  """
  def determine_winner_or_vote_again(results) do
    confirmed_block_hash = nil
    for block_hash <- Map.keys(results) do
      if results[block_hash] >= (2.0 / 3) * total_voting_power() do
        broadcast_confirmed_block(block_hash)

        confirmed_block_hash = block_hash
      end
    end

    if is_nil(confirmed_block_hash) do
      vote_again()
    end
  end

  @doc """
  Broadcast the confimed block to all peers, including non-validators.
  """
  def broadcast_confirmed_block(hash) do
  end
end