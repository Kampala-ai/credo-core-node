defmodule CredoCoreNode.State.InvalidBlockNumberError do
  defexception message: "Block with the given number doesn't exist", block_number: -1
end
