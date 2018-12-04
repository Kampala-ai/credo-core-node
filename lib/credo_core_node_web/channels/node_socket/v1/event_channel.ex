defmodule CredoCoreNodeWeb.NodeSocket.V1.EventChannel do
  use Phoenix.Channel

  import CredoCoreNodeWeb.NodeSocket.V1.EventHandler

  def join("events:all", _message, socket) do
    {:ok, socket}
  end
end
