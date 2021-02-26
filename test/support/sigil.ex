defmodule TzDatetime.Sigil do
  if Version.match?(System.version(), "< 1.9.0") do
    # Incomplete implementation of sigil_U for making
    # tests pass on elixir 1.8.x
    def sigil_U(<<date::binary-size(19), "Z">>, _) do
      naive = NaiveDateTime.from_iso8601!(date)
      DateTime.from_naive!(naive, "Etc/UTC")
    end
  end
end
