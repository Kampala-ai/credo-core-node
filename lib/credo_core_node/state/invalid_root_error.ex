defmodule CredoCoreNode.State.InvalidRootError do
  defexception message: "Invalid state_root attribute format in confirmed block",
               hash: "",
               state_root: ""
end
