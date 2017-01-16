defmodule Rbmq.Mixfile do
  use Mix.Project

  @version "0.3.1"

  def project do
    [app: :rbmq,
     version: @version,
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     description: description(),
     package: package(),
     deps: deps()]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger, :amqp_client, :amqp]]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [{:amqp_client, github: "jbrisbin/amqp_client", branch: "master", override: true},
    {:poison, "~> 2.0"},
    {:confex, "~> 1.0"},
    {:amqp, "0.1.5"},
    {:benchfella, "~> 0.3", only: [:dev, :test]},
    {:ex_doc, ">= 0.0.0", only: :dev},
    {:dogma, "~> 0.1", only: :dev},
    {:credo, "~> 0.4", only: [:dev, :test]}]
  end

  defp description do
    """
    Simple API for spawning RabbitMQ Producers and Consumers.
    """
  end

  defp package do
    [
     name: :rbmq,
     files: ["lib", "mix.exs", "README.md", "LICENSE.md"],
     maintainers: ["Pavel Vesnin", "Andrew Dryga"],
     licenses: ["MIT"],
     links: %{"GitHub" => "https://github.com/Nebo15/rbmq"}]
  end
end
