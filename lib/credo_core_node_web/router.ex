defmodule CredoCoreNodeWeb.Router do
  use CredoCoreNodeWeb, :router

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/node_api/v1", as: :node_api_v1, alias: CredoCoreNodeWeb.NodeApi.V1 do
    pipe_through(:api)

    resources("/known_nodes", KnownNodeController, only: [:index])
    resources("/connections", ConnectionController, only: [:create])
  end
end
