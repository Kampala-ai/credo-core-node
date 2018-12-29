defmodule CredoCoreNode.Adapters.MiningAdapter do
  alias CredoCoreNode.Blockchain.Block
  alias CredoCoreNode.Mining.{Deposit, Miner, Slash, Vote}
  alias CredoCoreNode.Pool.{PendingBlock, PendingTransaction}

  @callback default_nonce :: integer()
  @callback default_tx_fee :: integer()
  @callback min_stake_size :: integer()

  @callback become_miner(Decimal.t(), String.t(), String.t(), integer() | nil) ::
              %PendingTransaction{}
  @callback delete_miner_for_insufficient_stake(%Miner{}) :: %Miner{}
  @callback my_miner() :: %Miner{} | nil
  @callback withdrawable_deposit_value(%Miner{}, %PendingBlock{} | %Block{}) :: Decimal.t()
  @callback is_miner?() :: boolean()
  @callback list_miners() :: list(%Miner{})
  @callback count_miners() :: integer()
  @callback get_miner(String.t()) :: %Miner{}
  @callback miner_exists?(String.t()) :: boolean()
  @callback write_miner(map()) :: %Miner{}
  @callback delete_miner(%Miner{}) :: %Miner{}

  @callback list_votes() :: list(%Vote{})
  @callback list_votes_for_round(%Block{}, integer()) :: list(%Vote{})
  @callback get_vote(String.t()) :: %Vote{} | nil
  @callback write_vote(map()) :: %Vote{}
  @callback delete_vote(%Vote{}) :: %Vote{}

  @callback list_slashes() :: list(%Slash{})
  @callback get_slash(String.t()) :: %Slash{}
  @callback write_slash(map()) :: %Slash{}
  @callback delete_slash(%Slash{}) :: %Slash{}

  @callback list_deposits() :: list(%Deposit{})
  @callback get_deposit(String.t()) :: %Deposit{}
  @callback write_deposit(map()) :: %Deposit{}
  @callback delete_deposit(%Deposit{}) :: %Deposit{}

  @callback timelock_is_block_height?(integer()) :: boolean()
  @callback timelock_has_expired?(integer(), %PendingBlock{} | %Block{}) :: boolean()

  @callback start_mining(%Block{}, integer()) :: any()
  @callback start_voting(%PendingBlock{}, integer()) :: boolean()
end
