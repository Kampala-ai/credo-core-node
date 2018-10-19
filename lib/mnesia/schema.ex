defmodule Mnesia.Schema do
  defmacro __using__(opts) do
    fields = Keyword.get(opts, :fields, [])
    virtual_fields = Keyword.get(opts, :virtual_fields, [])
    table_name = Keyword.get(opts, :table_name, [])

    quote do
      module_name =
        __MODULE__
        |> Module.split()
        |> tl()
        |> Enum.join(".")

      defmodule(:"Elixir.Mnesia.Schemas.#{module_name}", do: nil)
      defstruct(unquote(fields) ++ unquote(virtual_fields))

      def table_name, do: unquote(table_name)
      def fields, do: unquote(fields)
      def virtual_fields, do: unquote(virtual_fields)

      def from_list(list) do
        attributes =
          fields()
          |> Enum.with_index()
          |> Enum.map(fn {fld_name, fld_idx} = _fld -> {fld_name, Enum.at(list, fld_idx)} end)

        struct(__MODULE__, attributes)
      end

      defimpl Mnesia.Table, for: __MODULE__ do
        def name(schema), do: unquote(table_name)
        def fields(schema), do: unquote(fields)
        def virtual_fields(schema), do: unquote(virtual_fields)
      end
    end
  end
end
