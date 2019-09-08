# TzDatetime

Datetime in a certain timezone with Ecto

Ecto natively only supports `naive_datetime`s and `utc_datetime`s, which either
ignore timezones or enforce only UTC. Both are useful for certain usecases, but
not sufficient when needing to store a datetime for different timezones.

This library is supposed to help for the given use case, but not in the way e.g.
`Calecto` does it by implementing a custom `Ecto.Type`. It rather gives you tools
to set the correct values for multiple columns on a changeset and converting the
values back to a `DateTime` at a later time.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `tz_datetime` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:tz_datetime, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/tz_datetime](https://hexdocs.pm/tz_datetime).

