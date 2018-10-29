defmodule CredoCoreNodeWeb.NodeSocket.V1.Socket do
  use Phoenix.Socket

  channel("events:*", CredoCoreNodeWeb.NodeSocket.V1.EventChannel)

  transport(:websocket, Phoenix.Transports.WebSocket)

  def connect(_params, socket) do
    {:ok, socket}
  end

  def id(_socket), do: nil
end
