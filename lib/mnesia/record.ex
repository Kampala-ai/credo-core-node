defprotocol Mnesia.Record do
  @doc "Returns key value for a given record"
  def key(record)
end
