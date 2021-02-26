# TzDatetime

<!-- MDOC !-->
Datetime in a certain timezone with Ecto

Ecto natively only supports `naive_datetime`s and `utc_datetime`s, which either
ignore timezones or enforce only UTC. Both are useful for certain usecases, but
not sufficient when needing to store a datetime for different timezones.

This library is supposed to help for the given use case, but not in the way e.g.
`Calecto` does it by implementing a custom `Ecto.Type`. It rather gives you tools
to set the correct values for multiple columns on a changeset and converting the
values back to a `DateTime` at a later time.

## Why not use an `Ecto.Type` implementation?

Timezone definitions change and do so even between storage and retrieval from a
database, which is especially problematic for points of time in the future. When a
calendar app stores an event at `10 o'clock` in CET a year ahead of time and the
timezone definition is changed e.g. to no longer do a daylight savings time the
`utc_datetime` field in the database does no longer match the intended wall
time of `10 o'clock`, but results in `9 o'clock` when converted to CET. `Ecto.Type`s
are not really well suited for dealing with that ambiguity, as values once
stored are meant to stay valid values. `TzDatetime` uses multiple columns, which
by themselves stay valid. The calculated `DateTime` based on those stored fields
might change though.

## Why store the datetime in a `utc_datetime` field in the first place?

It's a simple answer: The ability to compare datetimes. Without a common timezone
for datetimes comparisons get unnecessarily tricky. And at least
comparing to "now" is common enough to say most applications will actually need
to compare datetimes in the db to other datetimes.

## Usage

`TzDatetime` consists of two parts:

* `handle_datetime/2` for handling changes to a "datetime".
* `original_datetime/2` for retrieving the original "datetime" in the stored timezone

### Storing a "datetime"

The biggest problem for handling input is that most input methods don't supply
a datetime with sufficient timezone information. Even ISO 8601 formatted string
will only include the offset, but not the timezone name. Therefore `TzDatetime`
works with multiple fields in a schema.

```elixir
field :input_datetime, :naive_datetime, virtual: true
field :time_zone, :string

field :datetime, :utc_datetime
field :original_offset, :integer
```

The first two fields are for the input of data, while the second two are set
by `handle_datetime/2`.

```elixir
def changeset(schema, params) do
  schema
  |> cast(params, [:input_datetime, :time_zone])
  |> validate_required([:input_datetime, :time_zone])
  |> TzDatetime.handle_datetime()
end
```

You can also customize the names for those fields by passing a keyword list
of `[{name :: atom, custom_name :: atom}]` as second parameter.

#### Ambiguous dates or gaps

Using a `naive_datetime` and a separate timezone as inputs results in some
complexity though. The input datetime might exist twice or might not exist in
the timezone. This is possible for the periods in time when a switch between
daylight savings time and standard time occurs.

When the clock is turned backwards a certain naive datetime and timezone might
result in two possible datetimes with different `std_offset`s.

When the clock is turned forward a certain naive datetime and timezone might
result in no possible datetime, where elixir will supply the last possible
datetime before the switch and the first possible datetime afterwards.

See `DateTime.from_naive/3` for detailed examples on those cases.

The callbacks of the `TzDatetime` behaviour allow you to handle those cases
based on your business domains' requirements:

```elixir
@impl TzDatetime
@spec when_ambiguous(Ecto.Changeset.t(), DateTime.t(), DateTime.t(), TzDatetime.fields) ::
        Ecto.Changeset.t() | DateTime.t()
def when_ambiguous(_changeset, dt1, _dt2, _) do
  # Implement your business logic
  dt1
end

@impl TzDatetime
@spec when_gap(Ecto.Changeset.t(), DateTime.t(), DateTime.t(), TzDatetime.fields) ::
        Ecto.Changeset.t() | DateTime.t()
def when_gap(changeset, _dt1, _dt2, fields) do
  # Implement your business logic
  add_error(changeset, fields.datetime, "does not exist for the selected timezone")
end
```

`handle_datetime/2` will use the module of the changeset's data by default,
but you can also supply a different module using the `:module` key on the options.

### Reading datetimes

As mentioned earlier the timezone definitions can change. Therefore
the datetime stored can diverge over time from the value originally intended.
By storing the offset used to convert to the utc value in the db
`original_datetime/2` can detect if this did indeed happen or not. If a change
is detected this can be used to inform users, who can decide if the wall time
should be kept and the utc value in the db is wrong or if the point in time in
utc is to be preserved and the stored offset to be updated.

```elixir
# When offset does still match
> original_datetime(schema)
{:ok, datetime}

# When offset does no longer match
> original_datetime(schema)
{:ambiguous, datetime_using_current_offset, datetime_using_stored_offset}

# When tz no longer exists (not the only possible error though)
> original_datetime(schema)
{:error, :time_zone_not_found}
```

`original_datetime/2` like `handle_datetime/2` can receive a keyword list of
mappings for the field names for `:datetime`, `:time_zone` and `:original_offset`.

## Timezone Database

By default elixir does only support `Etc/UTC` as a timezone. To use this library
you likely need to install an alternative `Calendar.TimeZoneDatabase` implementation.

<!-- MDOC !-->

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `tz_datetime` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:tz_datetime, "~> 0.1.2"}
  ]
end
```

You'll also need to configure elixir to use a timezone database, which supports
all the timezones you need to use. Elixir itself does only support `Etc/UTC`. For
other timezones look at [`tz_data`](https://hex.pm/packages/tzdata) or other
implementations of `Calendar.TimeZoneDatabase`.

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/tz_datetime](https://hexdocs.pm/tz_datetime).

