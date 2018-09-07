defmodule CredoCoreNodeWeb.Router do
  use CredoCoreNodeWeb, :router

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/api", CredoCoreNodeWeb do
    pipe_through(:api)
  end
end
