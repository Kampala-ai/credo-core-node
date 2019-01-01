defmodule CredoCoreNode.State.InvalidStateError do
  defexception message: "Calculated state root doesn't match block state_root attribute",
               hash: "",
               state_root: ""
end
