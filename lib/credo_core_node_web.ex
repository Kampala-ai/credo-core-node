defmodule CredoCoreNodeWeb do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, views, channels and so on.

  This can be used in your application as:

      use CredoCoreNodeWeb, :controller
      use CredoCoreNodeWeb, :view

  The definitions below will be executed for every view,
  controller, etc, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below. Instead, define any helper function in modules
  and import those modules here.
  """

  def controller do
    quote do
      use Phoenix.Controller, namespace: CredoCoreNodeWeb
      import Plug.Conn
      import CredoCoreNodeWeb.Router.Helpers
      import CredoCoreNodeWeb.Gettext

      defp stream_binary(bin, chunk_size) do
        Stream.unfold(bin, fn rest ->
          case byte_size(rest) do
            0 ->
              nil

            size when size < chunk_size ->
              {rest, ""}

            size ->
              {binary_part(rest, 0, chunk_size), binary_part(rest, chunk_size, size - chunk_size)}
          end
        end)
      end

      defp send_chunks(conn, bin, chunk_size) do
        stream = stream_binary(bin, chunk_size)
        send_chunks(conn, stream)
      end

      defp send_chunks(conn, enumerable) do
        Enum.reduce_while(enumerable, conn, fn ch, conn ->
          case chunk(conn, ch) do
            {:ok, conn} ->
              {:cont, conn}

            {:error, :closed} ->
              {:halt, conn}
          end
        end)
      end
    end
  end

  def view do
    quote do
      use Phoenix.View,
        root: "lib/credo_core_node_web/templates",
        namespace: CredoCoreNodeWeb

      # Import convenience functions from controllers
      import Phoenix.Controller, only: [get_flash: 2, view_module: 1]

      import CredoCoreNodeWeb.Router.Helpers
      import CredoCoreNodeWeb.ErrorHelpers
      import CredoCoreNodeWeb.Gettext
    end
  end

  def router do
    quote do
      use Phoenix.Router
      import Plug.Conn
      import Phoenix.Controller
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
      import CredoCoreNodeWeb.Gettext
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
