defmodule StreamHelper do
  def stream_binary(bin, chunk_size) do
    Stream.unfold(bin, fn rest ->
      case byte_size(rest) do
        0 -> nil
        size when size < chunk_size -> {rest, ""}
        size ->
          {binary_part(rest, 0, chunk_size), binary_part(rest, chunk_size, size - chunk_size)}
      end
    end)
  end
end
