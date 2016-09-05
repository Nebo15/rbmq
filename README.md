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

  You can define connection configuration in your `config.exs`:

  ```elixir
  config :my_app, MyAMQPConnection,
    host: {:system, "AMQP_HOST", "localhost"},
    port: {:system, "AMQP_PORT", 5672},
    username: {:system, "AMQP_USER", "guest"},
    password: {:system, "AMQP_PASSWORD", "guest"},
    virtual_host: {:system, "AMQP_VHOST", "/"},
    connection_timeout: {:system, "AMQP_TIMEOUT", 15_000},
  ```

  RBMQ support linking to runtime environment conflagration via `{:system, "ENV_VAR_NAME", "default_value"}`
  and `{:system, "ENV_VAR_NAME"}` tuples. But are free to set raw values whenever you need.

By default RBMQ read environment configuration to establish AMQP connection:

  * `AMQP_HOST` - host, default: `localhost`
  * `AMQP_PORT` - port, default: `5672`
  * `AMQP_USER` - username, default: `guest`
  * `AMQP_PASSWORD` - password, default: `guest`
  * `AMQP_VHOST` - default vhost, default: `/`
  * `AMQP_TIMEOUT` - timeout, default: 15 sec.

Other connections settings can be found in [AMQP client docs](https://hexdocs.pm/amqp/AMQP.Connection.html#open/1).

## Usage

  1. Define your connection

    ```elixir
    defmodule MyAMQPConnection do
      use RBMQ.Connection,
        otp_app: :my_app
        # Optionally you can define queue params right here,
        # but it's better to do so in producer and consumer separately
    end
    ```

  2. Define your Producer and/or Consumer

    ```elixir
    defmodule MyProducer do
      use RBMQ.Producer,
        connection: MyAMQPConnection,

        # Queue params
        queue: [
          name: "prodcer_queue",
          error_name: "prodcer_queue_errors",
          routing_key: "prodcer_queue",
          durable: false
        ],
        exchange: [
          name: "prodcer_queue_exchange",
          type: :direct,
          durable: false
        ]
    end
    ```

    ```elixir
    defmodule MyConsumer do
      use RBMQ.Consumer,
        connection: MyAMQPConnection,

        # Queue params
        queue: [
          name: "consomer_queue",
          durable: false
        ],
        qos: [
          prefetch_count: 10
        ]

      def consume(_payload, [tag: tag, redelivered?: _redelivered]) do
        ack(tag)
      end
    end
    ```

    Pay attention to `consume/2` method. Write your consuming logic there. We recommend to send async messages to GenServer that will consume them, so queue read wouldn't be blocked by a single thread.

    If your queue required acknowledgements, use `ack\1` and `nack\1` methods.

  3. Add everything to your application supervisor:

    ```elixir
    defmodule MyApp do
      use Application

      # See http://elixir-lang.org/docs/stable/elixir/Application.html
      # for more information on OTP Applications
      def start(_type, _args) do
        import Supervisor.Spec, warn: false

        # Define workers and child supervisors to be supervised
        children = [
          # Start the AMQP connection
          supervisor(MyAMQPConnection, []),
          # Start producer and consumer
          worker(MyProducer, []),
          worker(MyConsumer, []),
        ]

        opts = [strategy: :one_for_one, name: AssetProcessor.API.Supervisor]
        Supervisor.start_link(children, opts)
      end
    end
    ```
