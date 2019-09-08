Mox.defmock(TzDatetime.TimeZoneDatabaseMock, for: Calendar.TimeZoneDatabase)
Mox.defmock(TzDatetimeMock, for: TzDatetime)
Application.put_env(:elixir, :time_zone_database, TzDatetime.TimeZoneDatabaseMock)
ExUnit.start()
