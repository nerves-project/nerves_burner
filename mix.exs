defmodule NervesBurner.MixProject do
  use Mix.Project

  def project do
    [
      app: :nerves_burner,
      version: "0.2.2",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: [
        flags: [:missing_return, :extra_return, :unmatched_returns, :error_handling, :underspecs]
      ],
      escript: escript()
    ]
  end

  def application do
    [
      extra_applications: []
    ]
  end

  defp deps do
    [
      {:req, "~> 0.5"},
      {:progress_bar, "~> 3.0"},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end

  defp escript do
    [main_module: NervesBurner.CLI]
  end
end
