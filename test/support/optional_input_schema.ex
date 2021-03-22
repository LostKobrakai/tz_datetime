defmodule TzDatetime.OptionalInputSchema do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    # Casted datetime
    field :input_datetime, :naive_datetime, virtual: true

    # Actually stored datetime
    field :datetime, :utc_datetime

    field :time_zone, :string
    field :original_offset, :integer
  end

  def changeset(schema, params) do
    schema
    |> cast(params, [:input_datetime, :time_zone])
  end
end
