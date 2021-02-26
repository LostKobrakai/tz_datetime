use Mix.Config

if Mix.env() == :test do
  config :elixir, :time_zone_database, TzDatetime.TimeZoneDatabaseMock
end
