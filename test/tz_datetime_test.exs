defmodule TzDatetimeTest do
  use ExUnit.Case
  import TzDatetime.Sigil

  describe "handle_datetime/2" do
    test "success" do
      Mox.stub(
        TzDatetime.TimeZoneDatabaseMock,
        :time_zone_periods_from_wall_datetime,
        fn _, "TzDatetime/Test" ->
          period = %{
            :utc_offset => 3600,
            :std_offset => 0,
            :zone_abbr => "TZT"
          }

          {:ok, period}
        end
      )

      params = %{
        input_datetime: "2019-01-01 10:00:00",
        time_zone: "TzDatetime/Test"
      }

      changeset = TzDatetime.Schema.changeset(%TzDatetime.Schema{}, params)

      changeset = TzDatetime.handle_datetime(changeset)
      assert {:ok, data} = Ecto.Changeset.apply_action(changeset, :insert)

      assert data.input_datetime == ~N[2019-01-01 10:00:00]
      assert data.datetime == ~U[2019-01-01 09:00:00Z]
      assert data.time_zone == "TzDatetime/Test"
      assert data.original_offset == 3600
    end

    test "ambiguous" do
      Mox.stub(
        TzDatetime.TimeZoneDatabaseMock,
        :time_zone_periods_from_wall_datetime,
        fn _, "TzDatetime/Test" ->
          period1 = %{
            :utc_offset => 3600,
            :std_offset => 0,
            :zone_abbr => "TZT"
          }

          period2 = %{
            :utc_offset => 3600,
            :std_offset => 3600,
            :zone_abbr => "TZST"
          }

          {:ambiguous, period1, period2}
        end
      )

      Mox.expect(TzDatetimeMock, :when_ambiguous, fn _, dt1, _, _ ->
        dt1
      end)

      params = %{
        input_datetime: "2019-01-01 10:00:00",
        time_zone: "TzDatetime/Test"
      }

      changeset = TzDatetime.Schema.changeset(%TzDatetime.Schema{}, params)

      changeset = TzDatetime.handle_datetime(changeset, module: TzDatetimeMock)
      assert {:ok, data} = Ecto.Changeset.apply_action(changeset, :insert)

      assert data.input_datetime == ~N[2019-01-01 10:00:00]
      assert data.datetime == ~U[2019-01-01 09:00:00Z]
      assert data.time_zone == "TzDatetime/Test"
      assert data.original_offset == 3600

      Mox.verify!()
    end

    test "gap" do
      Mox.stub(
        TzDatetime.TimeZoneDatabaseMock,
        :time_zone_periods_from_wall_datetime,
        fn _, "TzDatetime/Test" ->
          period1 = %{
            :utc_offset => 3600,
            :std_offset => 0,
            :zone_abbr => "TZT"
          }

          period2 = %{
            :utc_offset => 3600,
            :std_offset => 3600,
            :zone_abbr => "TZST"
          }

          {:gap, {period1, ~N[2019-02-01 00:00:00]}, {period2, ~N[2019-02-02 00:00:00]}}
        end
      )

      Mox.expect(TzDatetimeMock, :when_gap, fn _, _, dt2, _ ->
        dt2
      end)

      params = %{
        input_datetime: "2019-02-01 10:00:00",
        time_zone: "TzDatetime/Test"
      }

      changeset = TzDatetime.Schema.changeset(%TzDatetime.Schema{}, params)

      changeset = TzDatetime.handle_datetime(changeset, module: TzDatetimeMock)
      assert {:ok, data} = Ecto.Changeset.apply_action(changeset, :insert)

      assert data.input_datetime == ~N[2019-02-01 10:00:00]
      assert data.datetime == ~U[2019-02-01 22:00:00Z]
      assert data.time_zone == "TzDatetime/Test"
      assert data.original_offset == 7200

      Mox.verify!()
    end

    test "nil input_datetime" do
      Mox.stub(
        TzDatetime.TimeZoneDatabaseMock,
        :time_zone_periods_from_wall_datetime,
        fn _, "TzDatetime/Test" ->
          period = %{
            :utc_offset => 3600,
            :std_offset => 0,
            :zone_abbr => "TZT"
          }

          {:ok, period}
        end
      )

      params = %{
        input_datetime: nil,
        time_zone: "TzDatetime/Test"
      }

      changeset =
        TzDatetime.OptionalInputSchema.changeset(%TzDatetime.OptionalInputSchema{}, params)

      changeset = TzDatetime.handle_datetime(changeset)
      assert {:ok, data} = Ecto.Changeset.apply_action(changeset, :insert)

      assert data.input_datetime == nil
      assert data.datetime == nil
      assert data.time_zone == "TzDatetime/Test"
      assert data.original_offset == nil
    end
  end

  describe "original_datetime/2" do
    test "success" do
      Mox.stub(
        TzDatetime.TimeZoneDatabaseMock,
        :time_zone_period_from_utc_iso_days,
        fn _, "TzDatetime/Test" ->
          period = %{
            :utc_offset => 3600,
            :std_offset => 0,
            :zone_abbr => "TZT"
          }

          {:ok, period}
        end
      )

      struct = %TzDatetime.Schema{
        datetime: ~U[2019-01-01 00:00:00Z],
        time_zone: "TzDatetime/Test",
        original_offset: 3600
      }

      assert {:ok, datetime} = TzDatetime.original_datetime(struct)

      assert DateTime.to_unix(datetime) == DateTime.to_unix(~U[2019-01-01 00:00:00Z])
      assert datetime.utc_offset == 3600
      assert datetime.std_offset == 0
      assert datetime.time_zone == "TzDatetime/Test"
      assert datetime.zone_abbr == "TZT"
      assert DateTime.to_iso8601(datetime) == "2019-01-01T01:00:00+01:00"
    end

    test "ambiguous" do
      Mox.stub(
        TzDatetime.TimeZoneDatabaseMock,
        :time_zone_period_from_utc_iso_days,
        fn _, "TzDatetime/Test" ->
          period = %{
            :utc_offset => 3600,
            :std_offset => 0,
            :zone_abbr => "TZT"
          }

          {:ok, period}
        end
      )

      # Input wall time: ~N[2019-01-01 02:00:00]
      struct = %TzDatetime.Schema{
        datetime: ~U[2019-01-01 00:00:00Z],
        time_zone: "TzDatetime/Test",
        original_offset: 7200
      }

      assert {:ambiguous, dt1, dt2} = TzDatetime.original_datetime(struct)

      assert DateTime.to_unix(dt1) == DateTime.to_unix(~U[2019-01-01 00:00:00Z])
      assert dt1.utc_offset == 3600
      assert dt1.std_offset == 0
      assert dt1.time_zone == "TzDatetime/Test"
      assert dt1.zone_abbr == "TZT"
      assert DateTime.to_iso8601(dt1) == "2019-01-01T01:00:00+01:00"

      assert DateTime.to_unix(dt2) == DateTime.to_unix(~U[2019-01-01 01:00:00Z])
      assert dt2.utc_offset == 3600
      assert dt2.std_offset == 0
      assert dt2.time_zone == "TzDatetime/Test"
      assert dt2.zone_abbr == "TZT"
      assert DateTime.to_iso8601(dt2) == "2019-01-01T02:00:00+01:00"
    end
  end
end
