defmodule TzDatetime do
  @external_resource "README.md"
  @moduledoc "README.md"
             |> File.read!()
             |> String.split("<!-- MDOC !-->")
             |> Enum.fetch!(1)

  import Ecto.Changeset
  require Logger

  if Calendar.get_time_zone_database() == Calendar.UTCOnlyTimeZoneDatabase do
    Logger.warning("""
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

    case safe_from_naive(input_datetime, time_zone) do
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

      nil ->
        changeset
    end
  end

  # Safely allow nil values when casting to DateTime
  defp safe_from_naive(nil, _time_zone), do: nil
  defp safe_from_naive(_input_datetime, nil), do: nil

  defp safe_from_naive(input_datetime, time_zone),
    do: DateTime.from_naive(input_datetime, time_zone)

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
