defmodule CredoCoreNode.State.MissingBlockBodyError do
  defexception message: "Can't calculate state as one of the necessary block bodies is missing",
               hash: ""
end
