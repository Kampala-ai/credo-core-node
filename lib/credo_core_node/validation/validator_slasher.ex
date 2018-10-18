defmodule CredoCoreNode.Validation.ValidatorSlasher do
  @moduledoc """
  The validator slasher module.
  """

  alias CredoCoreNode.Blockchain
  alias CredoCoreNode.Pool
  alias CredoCoreNode.Validation

  @slash_penalty_percentage 20

  @doc """
  Broadcasts a validator slash transaction.

  A byzantine behavior proof should be two or more votes signed by the allegedly-byzantine validator for a given block number and voting round.
  """
  def slash_validator(byzantine_behavior_proof, validator_address) do
    private_key = "" # TODO: set actual private key

    construct_validator_slash_transaction(private_key, byzantine_behavior_proof, validator_address)
    |> broadcast_validator_slash_transaction()
  end

  @doc """
  Broadcasts a validator slash transaction.
  """
  def construct_validator_slash_transaction(private_key, byzantine_behavior_proof, to) do
    attrs = %{nonce: Validation.default_nonce(), to: to, value: 0 , fee: Validation.default_tx_fee(), data: "{\"tx_type\" : \"#{Blockchain.slash_tx_type()}\", \"byzantine_behavior_proof\" : \"#{byzantine_behavior_proof}\"}"}

    {:ok, tx} = Pool.generate_pending_transaction(private_key, attrs)

    tx
  end

  @doc """
  Broadcasts a validator slash transaction.
  """
  def broadcast_validator_slash_transaction(tx) do
    Pool.propagate_pending_transaction(tx)
  end

  @doc """
  Checks whether a transaction is a slash transaction
  """
  def is_slash_transactions(tx) do
    Poison.decode!(tx.data)["tx_type"] == Blockchain.slash_tx_type()
  end

  @doc """
  Returns slash transactions from a list of transactions
  """
  def get_slash_transactions(txs) do
    txs
    |> Enum.filter(& is_slash_transactions(&1))
  end

  @doc """
  Checks that the proof contains two or more votes from a single validator for a given block number and voting round
  """
  def slash_proof_is_valid?(proof) do
    #TODO: implement proof check.
  end

  @doc """
  Returns slash transactions with a valid slash proof.

  TODO: check that the validator wasn't already slashed for that block number.
  """
  def validate_slash_transactions(txs) do
    for tx <- txs do
      proof = Poison.decode!(tx.data)["byzantine_behavior_proof"]

      if slash_proof_is_valid?(proof) do
        tx
      end
    end
  end

  @doc """
  Slashes validators
  """
  def process_slash_transactions(txs) do
    for tx <- txs do
      slashed_validator = Validation.get_validator(tx.validator_address)

      Validation.write_validator(%{slashed_validator | stake_amount: slashed_validator.stake_amount * (1 - @slash_penalty_percentage)})
    end
  end

  @doc """
  Retrieves slash transactions, validates them, and then slashes validators.
  """
  def maybe_process_slash_transactions(txs) do
    txs
    |> get_slash_transactions()
    |> validate_slash_transactions()
    |> process_slash_transactions()
  end
end
