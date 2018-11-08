defmodule CredoCoreNodeWeb.Router do
  use CredoCoreNodeWeb, :router

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/node_api/v1", as: :node_api_v1, alias: CredoCoreNodeWeb.NodeApi.V1 do
    pipe_through(:api)

    resources("/known_nodes", KnownNodeController, only: [:index])
    resources("/connections", ConnectionController, only: [:create])
    resources("/blocks", BlockController, only: [:index])
    resources("/block_bodies", BlockBodyController, only: [:show])
    resources("/pending_block_bodies", PendingBlockBodyController, only: [:show])

    # Endpoints for temporary usage, to be replaced later with channels-based protocol
    scope "/temp", as: :temp, alias: Temp do
      resources("/pending_transactions", PendingTransactionController, only: [:create])
      resources("/votes", VoteController, only: [:create])
    end
  end

  scope "/client_api/v1", as: :client_api_v1, alias: CredoCoreNodeWeb.ClientApi.V1 do
    pipe_through(:api)

    resources("/accounts", AccountController, only: [:create, :show])
    resources("/pending_transactions", PendingTransactionController, only: [:create])
  end
end
