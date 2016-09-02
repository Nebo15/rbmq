# RBMQ

Simple and easy creation of producers and consumers for RabbitMQ.
Written over <a href="https://github.com/pma/amqp" target="_blank">AMQP</a>

## Installation

The package can be installed as:

  1. Add `rbmq` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:rbmq, "~> 0.2.2"}]
    end
    ```

  2. Ensure `rbmq` is started before your application:

    ```elixir
    def application do
      [applications: [:rbmq]]
    end
    ```

## Configuration

In `config/config.exs` or your configuration file, add:

```elixir
config :rbmq, amqp_exchange: "rbmq_exchange"

config :rbmq, prefetch_count: 10

config :rbmq, amqp_params: [
  host: "localhost",
  port: 5672,
  username: "guest",
  password: "guest",
]
```
