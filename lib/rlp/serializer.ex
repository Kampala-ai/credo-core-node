defmodule RLP.Serializer do
  defmacro serialize(fields) do
    do_serialize(:default, fields)
  end

  defmacro serialize(type, fields) do
    do_serialize(type, fields)
  end

  defp do_serialize(type, fields) do
    type = :"rlp_#{type}"

    quote do
      def to_list(%__MODULE__{} = record, [type: unquote(type)] = _options) do
        unquote(fields)
        |> Enum.map(&Map.get(record, elem(&1, 0)))
      end

      def from_list(list, [type: unquote(type)] = options) do
        attributes =
          unquote(fields)
          |> Enum.with_index()
          |> Enum.map(fn {{field_name, field_type}, field_idx} = _field ->
            raw_field_value = Enum.at(list, field_idx)

            field_value =
              case field_type do
                :unsigned -> :binary.decode_unsigned(raw_field_value)
                _ -> raw_field_value
              end

            {field_name, field_value}
          end)

        record = struct(__MODULE__, attributes)
        %{record | hash: RLP.Hash.hex(record, options)}
      end
    end
  end

  defmacro __using__(_opts) do
    quote do
      import RLP.Serializer, only: [serialize: 1, serialize: 2]

      defimpl ExRLP.Encode, for: __MODULE__ do
        alias ExRLP.Encode

        def encode(record, options \\ []) do
          module_name =
            __MODULE__
            |> Module.split()
            |> Enum.drop(3)
            |> Enum.join(".")

          type =
            case Atom.to_string(options[:type]) do
              "nil" -> :rlp_default
              "rlp_" <> type -> :"rlp_#{type}"
              type -> :"rlp_#{type}"
            end

          record
          |> :"Elixir.CredoCoreNode.#{module_name}".to_list(type: type)
          |> Encode.encode(options)
        end
      end

      defimpl RLP.Hash, for: __MODULE__ do
        def binary(record, options \\ []) do
          record
          |> ExRLP.encode(type: options[:type], encoding: :hex)
          |> :libsecp256k1.sha256()
        end

        def hex(record, options \\ []) do
          record
          |> binary(options)
          |> Base.encode16()
        end
      end
    end
  end
end
