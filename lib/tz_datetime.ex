defmodule TzDatetime do
  import Ecto.Changeset

  @type fields :: %{
          input_datetime: :atom,
          time_zone: :atom,
          datetime_field: :atom,
          original_offset_field: :atom
        }

  @callback when_ambiguous(Ecto.Changeset.t(), DateTime.t(), DateTime.t()) ::
              Ecto.Changeset.t() | DateTime.t()
  @callback when_gap(Ecto.Changeset.t(), DateTime.t(), DateTime.t()) ::
              Ecto.Changeset.t() | DateTime.t()

  @spec handle_datetime(Ecto.Changeset.t(), keyword()) :: Ecto.Changeset.t()
  def handle_datetime(changeset, opts \\ []) do
    module = Keyword.get(opts, :module, changeset.data.__struct__)
    fields = fields_from_opts(opts)
    input_datetime = get_change(changeset, fields.input_datetime)
    time_zone = get_change(changeset, fields.time_zone)

    case DateTime.from_naive(input_datetime, time_zone) do
      {:ok, correct_datetime} ->
        apply_datetime(changeset, correct_datetime, fields)

      {:ambiguous, dt1, dt2} ->
        # the naive datetime happens twice for the given timezones for different std_offsets
        handle_callback_result(changeset, module.when_ambiguous(changeset, dt1, dt2), fields)

      {:gap, dt1, dt2} ->
        # the naive datetime doesn't happen for the given timezones as
        # the switch in std_offset skips it
        handle_callback_result(changeset, module.when_gap(changeset, dt1, dt2), fields)

      {:error, :time_zone_not_found} ->
        add_error(changeset, :timezone, "is invalid")
    end
  end

  @spec handle_callback_result(Ecto.Changeset.t(), Ecto.Changeset.t() | DateTime.t(), fields) ::
          Ecto.Changeset.t()
  defp handle_callback_result(_, %Ecto.Changeset{} = changeset, _), do: changeset

  defp handle_callback_result(changeset, %DateTime{} = dt, fields),
    do: apply_datetime(changeset, dt, fields)

  @spec handle_callback_result(Ecto.Changeset.t(), DateTime.t(), fields) :: Ecto.Changeset.t()
  defp apply_datetime(changeset, datetime, fields) do
    {:ok, utc_datetime} = Ecto.Type.cast(:utc_datetime, datetime)

    changeset
    |> put_change(fields.datetime, utc_datetime)
    |> put_change(fields.original_offset, complete_offset(datetime))
  end

  defp complete_offset(datetime), do: datetime.utc_offset + datetime.std_offset

  @spec original_datetime(struct, keyword()) ::
          {:ok, DateTime.t()}
          | {:ambiguous, DateTime.t(), DateTime.t()}
          | {:error, term}
  def original_datetime(struct, opts \\ []) do
    fields = fields_from_opts(opts)
    utc_datetime = Map.fetch!(struct, fields.datetime)
    time_zone = Map.fetch!(struct, fields.time_zone)
    original_offset = Map.fetch!(struct, fields.original_offset)

    case DateTime.shift_zone(utc_datetime, time_zone) do
      {:ok, datetime} ->
        case original_offset - complete_offset(datetime) do
          0 -> {:ok, datetime}
          diff -> {:ambiguous, datetime, DateTime.add(datetime, diff, :second)}
        end

      {:error, _} = err ->
        err
    end
  end

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
