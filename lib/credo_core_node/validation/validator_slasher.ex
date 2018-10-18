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
end
