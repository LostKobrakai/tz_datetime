defmodule TzDatetime do
  @moduledoc """
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

      field :input_datetime, :naive_datetime, virtual: true
      field :time_zone, :string

      field :datetime, :utc_datetime
      field :original_offset, :integer

  The first two fields are for the input of data, while the second two are set
  by `handle_datetime/2`.

      def changeset(schema, params) do
        schema
        |> cast(params, [:input_datetime, :time_zone])
        |> validate_required([:input_datetime, :time_zone])
        |> TzDatetime.handle_datetime()
      end

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

      # When offset does still match
      > original_datetime(schema)
      {:ok, datetime}

      # When offset does no longer match
      > original_datetime(schema)
      {:ambiguous, datetime_using_current_offset, datetime_using_stored_offset}

      # When tz no longer exists (not the only possible error though)
      > original_datetime(schema)
      {:error, :time_zone_not_found}

  `original_datetime/2` like `handle_datetime/2` can receive a keyword list of
  mappings for the field names for `:datetime`, `:time_zone` and `:original_offset`.

  ## Timezone Database

  By default elixir does only support `Etc/UTC` as a timezone. To use this library
  you likely need to install an alternative `Calendar.TimeZoneDatabase` implementation.
  """
  import Ecto.Changeset
  require Logger

  if Calendar.get_time_zone_database() == Calendar.UTCOnlyTimeZoneDatabase do
    Logger.warn("""
    It seems like you didn't configure elixir to use an alternate timezone database.
    The default Calendar.UTCOnlyTimeZoneDatabase does only support Etc/UTC timezone.
    """)
  end

  @typedoc "Holds a mapping of field purposes to actual field names"
  @type fields :: %{
          input_datetime: :atom,
          time_zone: :atom,
          datetime: :atom,
          original_offset: :atom
        }

  @doc """
  Called when `DateTime.from_naive/3` does return `{:ambiguous, DateTime.t(), DateTime.t()}` for the input_datetime and the timezone.

  Handle the case according to your business' requirements by either modifying
  the changeset or returning a single valid `DateTime` struct.
  """
  @callback when_ambiguous(Ecto.Changeset.t(), DateTime.t(), DateTime.t(), fields) ::
              Ecto.Changeset.t() | DateTime.t()

  @doc """
  Called when `DateTime.from_naive/3` does return `{:gap, DateTime.t(), DateTime.t()}` for the input_datetime and the timezone.

  Handle the case according to your business' requirements by either modifying
  the changeset or returning a single valid `DateTime` struct.
  """
  @callback when_gap(Ecto.Changeset.t(), DateTime.t(), DateTime.t(), fields) ::
              Ecto.Changeset.t() | DateTime.t()

  @doc """
  Called when `DateTime.from_naive/3` does return `{:error, :incompatible_calendars}` for the input_datetime and the timezone.

  This should only be of a concern if you're handling input dates, which use a calendar different
  to `Calendar.ISO`, therefore this callback is optional. By default the result will be handled
  by adding an error for the time_zone field.

  Handle the case according to your business' requirements by either modifying
  the changeset or returning a single valid `DateTime` struct.
  """
  @callback when_incompatible_calendar(Ecto.Changeset.t(), fields) ::
              Ecto.Changeset.t() | DateTime.t()

  @optional_callbacks when_incompatible_calendar: 2

  @doc """
  Call this for a changeset with an input_datetime and timezone set, to calculate a datetime and original_offset.

  ## Options:
  * `:input_datetime` Used to change set the name of the field. Defaults to `:input_datetime`.
  * `:time_zone` Used to change set the name of the field. Defaults to `:time_zone`.
  * `:datetime` Used to change set the name of the field. Defaults to `:datetime`.
  * `:original_offset` Used to change set the name of the field. Defaults to `:original_offset`.
  * `:module` Module, which implements `TzDate`. Defaults to `changeset.data.__struct__`.
  """
  @spec handle_datetime(Ecto.Changeset.t(), keyword()) :: Ecto.Changeset.t()
  def handle_datetime(changeset, opts \\ []) do
    fields = fields_from_opts(opts)

    with false <- Keyword.has_key?(changeset.errors, fields.input_datetime),
         false <- Keyword.has_key?(changeset.errors, fields.time_zone),
         changed_fields = Map.keys(changeset.changes),
         true <- fields.input_datetime in changed_fields || fields.time_zone in changed_fields do
      do_handle_datetime(changeset, fields, opts)
    else
      _ -> changeset
    end
  end

  # Actually handle the cases for `DateTime.from_naive(input_datetime, time_zone)`
  # Call into the behaviour implementing module for :ambiguous|:gap results
  defp do_handle_datetime(changeset, fields, opts) do
    module = Keyword.get(opts, :module, changeset.data.__struct__)
    input_datetime = get_field(changeset, fields.input_datetime)
    time_zone = get_field(changeset, fields.time_zone)

    case DateTime.from_naive(input_datetime, time_zone) do
      {:ok, correct_datetime} ->
        apply_datetime(changeset, correct_datetime, fields)

      {:ambiguous, dt1, dt2} ->
        # the naive datetime happens twice for the given timezones for different std_offsets
        handle_callback_result(
          changeset,
          module.when_ambiguous(changeset, dt1, dt2, fields),
          fields
        )

      {:gap, dt1, dt2} ->
        # the naive datetime doesn't happen for the given timezones as
        # the switch in std_offset skips it
        handle_callback_result(changeset, module.when_gap(changeset, dt1, dt2, fields), fields)

      {:error, :incompatible_calendars} ->
        # the naive datetime does use a calendar not matching the
        # selected timezone
        if function_exported?(module, :when_incompatible_calendar, 2) do
          handle_callback_result(
            changeset,
            module.when_incompatible_calendar(changeset, fields),
            fields
          )
        else
          Ecto.Changeset.add_error(
            changeset,
            fields.time_zone,
            "is incompatible with the input datetime calendar",
            calendar: input_datetime.calendar
          )
        end

      {:error, :time_zone_not_found} ->
        add_error(changeset, fields.time_zone, "is invalid")
    end
  end

  # Handle both return options of an edited changeset or a datetime to use
  @spec handle_callback_result(Ecto.Changeset.t(), Ecto.Changeset.t(), fields) ::
          Ecto.Changeset.t()
  defp handle_callback_result(_, %Ecto.Changeset{} = changeset, _), do: changeset

  @spec handle_callback_result(Ecto.Changeset.t(), DateTime.t(), fields) ::
          Ecto.Changeset.t()
  defp handle_callback_result(changeset, %DateTime{} = dt, fields),
    do: apply_datetime(changeset, dt, fields)

  # When a datetime is computed set it to the changeset and store the offset used
  # for later detection of changes.
  @spec apply_datetime(Ecto.Changeset.t(), DateTime.t(), fields) :: Ecto.Changeset.t()
  defp apply_datetime(changeset, datetime, fields) do
    {:ok, utc_datetime} = Ecto.Type.cast(:utc_datetime, datetime)

    changeset
    |> put_change(fields.datetime, utc_datetime)
    |> put_change(fields.original_offset, complete_offset(datetime))
  end

  # Add utc and std offset together
  defp complete_offset(datetime), do: datetime.utc_offset + datetime.std_offset

  @doc """
  Call this on a schema to get back the datetime for the stored timezone

  ## Options:
  * `:time_zone` Used to change set the name of the field. Defaults to `:time_zone`.
  * `:datetime` Used to change set the name of the field. Defaults to `:datetime`.
  * `:original_offset` Used to change set the name of the field. Defaults to `:original_offset`.
  """
  @spec original_datetime(struct, keyword()) ::
          {:ok, DateTime.t()}
          | {:ambiguous, DateTime.t(), DateTime.t()}
          | {:error, term}
  def original_datetime(struct, opts \\ []) do
    fields = fields_from_opts(opts)
    utc_datetime = Map.fetch!(struct, fields.datetime)
    time_zone = Map.fetch!(struct, fields.time_zone)
    original_offset = Map.fetch!(struct, fields.original_offset)

    with {:ok, datetime} <- DateTime.shift_zone(utc_datetime, time_zone) do
      case original_offset - complete_offset(datetime) do
        0 -> {:ok, datetime}
        diff -> {:ambiguous, datetime, DateTime.add(datetime, diff, :second)}
      end
    end
  end

  # Build a map for the fields from the options
  @spec fields_from_opts(keyword()) :: fields
  defp fields_from_opts(opts) do
    fields = %{
      input_datetime: Keyword.get(opts, :input_datetime, :input_datetime),
      time_zone: Keyword.get(opts, :time_zone, :time_zone),
      datetime: Keyword.get(opts, :datetime, :datetime),
      original_offset: Keyword.get(opts, :original_offset, :original_offset)
    }

    unless Enum.all?(fields, fn {_l, v} -> is_atom(v) end) do
      raise "field names must all be atoms"
    end

    fields
  end
end
