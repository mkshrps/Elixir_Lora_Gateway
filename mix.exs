defmodule Lora.MixProject do
  use Mix.Project

  def project do
    [
      app: :lora_gateway,
      version: "1.0.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      name: "Lora_Gateway",
      source_url: "https://github.com/mkshrps/Elixir_Lora_Gateway",
      docs: [
        main: "Lora",
        logo: "assets/logo.png",
        extras: ["README.md"]
      ]
    ]
  end

  defp package do
    [
      files: ["lib", "mix.exs", "README*"],
      maintainers: ["Mike Sharps"],
      licenses: ["MIT"],
      links: %{"GitHub" => "Elixir_LoRa_Gateway"}
    ]
  end

  defp description do
    """
    This is a module for receiving using semtec SX127x LoRa Radios.
    Esasy configuration using UKHAS modes are supported
    Radios:
        Semtech SX1276/77/78/79 based boards.
    """
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      #{:elixir_ale, "~> 1.2"},
      {:ex_doc, "~> 0.21", only: :dev, runtime: false},
      {:circuits_spi, "~> 1.3"},
      {:circuits_gpio, "~> 1.0"},
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"},
      #{:sondehub, path: "../sondehub" },
      #{:mqtt_gateway, path: "../mqtt_gateway"}
     ]
  end
end
