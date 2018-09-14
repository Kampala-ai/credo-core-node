defmodule Mnesia.Schema do
  defmacro __using__(opts) do
    fields = Keyword.get(opts, :fields, [])
    table_name = Keyword.get(opts, :table_name, [])

    quote do
      module_name =
        __MODULE__
        |> Module.split
        |> tl
        |> Enum.join(".")

      defmodule :"Elixir.Mnesia.Schemas.#{module_name}", do: nil
      defstruct unquote(fields)

      def table_name, do: unquote(table_name)
      def fields, do: unquote(fields)

      def from_list(list) do
        attributes =
          fields
          |> Enum.with_index()
          |> Enum.map(fn field -> {elem(field, 0), Enum.at(list, elem(field, 1))} end)

        struct(__MODULE__, attributes)
      end

      defimpl Mnesia.Table, for: __MODULE__ do
        def name(schema), do: unquote(table_name)
        def fields(schema), do: unquote(fields)
      end
    end
  end
end
