defmodule CredoCoreNodeWeb.NodeSocket.V1.Socket do
  use Phoenix.Socket

  channel("events:*", CredoCoreNodeWeb.NodeSocket.V1.EventChannel)

  transport(:websocket, Phoenix.Transports.WebSocket)

  def connect(%{"session_id" => session_id}, socket) do
    {:ok, assign(socket, :session_id, session_id)}
  end

  def id(socket), do: "node_socket:#{socket.assigns.session_id}"
end
