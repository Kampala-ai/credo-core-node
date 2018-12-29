defmodule CredoCoreNode.Adapters.VoteManagerAdapter do
  alias CredoCoreNode.Blockchain.Block
  alias CredoCoreNode.Pool.PendingBlock
  alias CredoCoreNode.Mining.{Miner, Vote}

  @callback cast_vote(%PendingBlock{}, integer()) :: %Vote{}
  @callback sign_vote(%Vote{}) :: %Vote{}
  @callback propagate_vote(%Vote{}, list()) :: %Vote{}

  @callback wait_for_votes(%PendingBlock{} | %Block{}, integer(), integer()) :: :ok
  @callback get_current_voting_round(%PendingBlock{} | %Block{}) :: integer()

  @callback consensus_reached?(%PendingBlock{}, integer()) :: boolean()
  @callback already_voted?(%PendingBlock{}, integer()) :: boolean()
  @callback miner_voted?(list(%Vote{}), %Miner{}) :: boolean()
  @callback is_valid_vote?(%Vote{}) :: boolean()

  @callback get_winner(map(), list(%Vote{})) :: %PendingBlock{} | nil
  @callback count_votes(list(%Vote{})) :: list()

  @callback update_participation_rates(%PendingBlock{}, integer()) :: list()
end