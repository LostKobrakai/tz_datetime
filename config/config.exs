import Config

if config_env() == :test do
  config :elixir, :time_zone_database, TzDatetime.TimeZoneDatabaseMock
end
