defmodule Mnesia.Schema do
  defmacro __using__(opts) do
    fields = Keyword.get(opts, :fields, [])
    virtual_fields = Keyword.get(opts, :virtual_fields, [])
    table_name = Keyword.get(opts, :table_name, [])
    rlp_support = Keyword.get(opts, :rlp_support, false)

    quote do
      module_name =
        __MODULE__
        |> Module.split()
        |> tl
        |> Enum.join(".")

      defmodule(:"Elixir.Mnesia.Schemas.#{module_name}", do: nil)
      defstruct(unquote(fields) ++ unquote(virtual_fields))

      def table_name, do: unquote(table_name)
      def fields, do: unquote(fields)
      def virtual_fields, do: unquote(virtual_fields)

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
        def virtual_fields(schema), do: unquote(virtual_fields)
      end

      if unquote(rlp_support) do
        defimpl ExRLP.Encode, for: __MODULE__ do
          alias ExRLP.Encode

          def encode(record, options \\ []) do
            module_name =
              __MODULE__
              |> Module.split()
              |> Enum.drop(3)
              |> Enum.join(".")

            record
            |> :"Elixir.CredoCoreNode.#{module_name}".to_list(options)
            |> Encode.encode(options)
          end
        end

        def hash(%__MODULE__{} = record, options \\ []) do
          hash =
            record
            |> ExRLP.encode(type: options[:type], encoding: :hex)
            |> :libsecp256k1.sha256()

          if options[:encoding] == :hex, do: Base.encode16(hash), else: hash
        end
      end
    end
  end
end
