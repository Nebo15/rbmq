defmodule Rbmq.Mixfile do
  use Mix.Project

  def project do
    [app: :rbmq,
     version: "0.2.1",
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
    [applications: [:logger, :amqp, :gproc, :postgrex]]
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
    [{:amqp_client, git: "https://github.com/dsrosario/amqp_client.git", branch: "erlang_otp_19", override: true},
    {:postgrex, ">= 0.0.0"},
    {:poison, "~> 2.0"},
    {:gproc, "~> 0.5.0"},
    {:amqp, "0.1.4"},
    {:ex_doc, ">= 0.0.0", only: :dev},
    {:dogma, "~> 0.1", only: :dev},
    {:credo, "~> 0.4", only: [:dev, :test]}]
  end

  defp description do
    """
    Simple API for spawn RabbitMQ Producers and Consumers.
    """
  end

  defp package do
    [
     name: :rbmq,
     files: ["lib", "mix.exs", "README.md", "LICENSE.md"],
     maintainers: ["Pavel Vesnin"],
     licenses: ["MIT"],
     links: %{"GitHub" => "https://github.com/Nebo15/rbmq"}]
  end
end
