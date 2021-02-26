defmodule TzDatetime.MixProject do
  use Mix.Project

  def project do
    [
      app: :tz_datetime,
      version: "0.1.3",
      elixir: "~> 1.8",
      name: "tz_datetime",
      source_url: "https://github.com/madeitGmbH/tz_datetime",
      description: description(),
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      package: package(),
      deps: deps()
    ]
  end

  defp description() do
    "Handling timezones for datetimes in ecto"
  end

  defp package() do
    [
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => "https://github.com/madeitGmbH/tz_datetime"}
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ecto, "~> 3.2"},
      {:ex_doc, "~> 0.23.0", only: :dev, runtime: false},
      {:mox, "~> 0.5.0", only: :test}
    ]
  end
end
