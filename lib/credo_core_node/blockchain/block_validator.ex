defmodule CredoCoreNode.Blockchain.BlockValidator do
  alias CredoCoreNode.SecurityDeposits
  alias CredoCoreNode.Validation

  @doc """
  Validates a block.
  """
  def validate_block(block) do
    validate_previous_hash(block)
    validate_format(block)
    validate_security_deposits(block)
    validate_validator_updates(block)
    validate_network_consensus(block)
  end

  @doc """
  Validates the previous block hash.
  """
  def validate_previous_hash(block) do
  end

  @doc """
  Validates block format.
  """
  def validate_format(block) do
  end

  @doc """
  Validates security deposits.
  """
  def validate_security_deposits(block) do
    SecurityDeposits.maybe_process_security_deposits(block.body)
  end

  @doc """
  Validate validator updates.
  """
  def validate_validator_updates(block) do
    Validation.maybe_validate_validator_ip_update_transactions(block.body)
  end

  @doc """
  Validate network consensus.
  """
  def validate_network_consensus(block) do
    Validation.vote(block)
  end
end